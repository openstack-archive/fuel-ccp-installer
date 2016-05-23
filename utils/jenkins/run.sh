#!/bin/bash
set -xe

# for now we assume that master ip is 10.0.0.2 and slaves ips are 10.0.0.{3,4,5,...}
ADMIN_PASSWORD=vagrant
ADMIN_USER=vagrant
INSTALL_DIR=/home/vagrant/solar-k8s

ENV_NAME=${ENV_NAME:-solar-example}
SLAVES_COUNT=${SLAVES_COUNT:-0}
CONF_PATH=${CONF_PATH:-utils/jenkins/default.yaml}

IMAGE_PATH=${IMAGE_PATH:-bootstrap/output-qemu/ubuntu1404}
TEST_SCRIPT=${TEST_SCRIPT:-/vagrant/examples/hosts_file/hosts.py}
DEPLOY_TIMEOUT=${DEPLOY_TIMEOUT:-60}

SOLAR_DB_BACKEND=${SOLAR_DB_BACKEND:-riak}

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

dos.py erase ${ENV_NAME} || true
mkdir -p tmp

mkdir -p logs
rm -rf logs/*

ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} python utils/jenkins/env.py create_env

SLAVE_IPS=`ENV_NAME=${ENV_NAME} python utils/jenkins/env.py get_slaves_ips`
ADMIN_IP=`ENV_NAME=${ENV_NAME} python utils/jenkins/env.py get_admin_ip`

# Wait for all servers(grep only IP addresses):
for IP in `echo ${ADMIN_IP} ${SLAVE_IPS} |grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'`; do
    elapsed_time=0
    master_wait_time=30
    while true; do
        report=$(sshpass -p ${ADMIN_PASSWORD} ssh ${SSH_OPTIONS} ${ADMIN_USER}@${IP} echo ok || echo not ready)

        if [ "${report}" = "ok" ]; then
            break
        fi

        if [ "${elapsed_time}" -gt "${master_wait_time}" ]; then
            exit 2
        fi

        sleep 1
        let elapsed_time+=1
    done
done

sshpass -p ${ADMIN_PASSWORD} rsync -rz . -e "ssh ${SSH_OPTIONS}" ${ADMIN_USER}@${ADMIN_IP}:/home/vagrant/solar-k8s --exclude tmp --exclude x-venv --exclude .vagrant --exclude .eggs --exclude *.box --exclude images --exclude utils/packer

set +e

sshpass -p ${ADMIN_PASSWORD} ssh ${SSH_OPTIONS} ${ADMIN_USER}@${ADMIN_IP} bash -s <<EOF
set -x
set -e

export PYTHONWARNINGS="ignore"

wget https://github.com/openstack/solar-resources/archive/master.zip
unzip master.zip

solar repo import solar-resources-master/resources
solar repo import solar-resources-master/templates
solar repo import -n k8s solar-k8s/resources

solar repo update templates ${INSTALL_DIR}/utils/jenkins/repository

solar resource create nodes templates/nodes ips="${SLAVE_IPS}" count="${SLAVES_COUNT}"

sudo pip install -r ${INSTALL_DIR}/requirements.txt

pushd ${INSTALL_DIR}
bash -c "${TEST_SCRIPT}"
popd

solar changes stage
solar changes process
solar orch run-once

elapsed_time=0
while true; do
    report=\$(solar o report)

    errors=\$(echo "\${report}" | grep -e ERROR | wc -l)
    if [ "\${errors}" != "0" ]; then
        solar orch report
        echo FAILURE
        exit 1
    fi

    running=\$(echo "\${report}" | grep -e PENDING -e INPROGRESS | wc -l)
    if [ "\${running}" == "0" ]; then
        solar orch report
        echo SUCCESS
        exit 0
    fi

    if [ "\${elapsed_time}" -gt "${DEPLOY_TIMEOUT}" ]; then
        solar orch report
        echo TIMEOUT
        exit 2
    fi

    sleep 5
    let elapsed_time+=5
done
EOF

deploy_res=$?

# setup VLAN if everything is ok and env will not be deleted
if [ "$VLAN_BRIDGE" ] && [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" = "1" ];then
    rm -f VLAN_IPS
    for IP in `echo ${ADMIN_IP} ${SLAVE_IPS} |grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'`; do
        bridged_iface_mac="`ENV_NAME=${ENV_NAME} python utils/jenkins/env.py get_bridged_iface_mac $IP`"

        sshpass -p ${ADMIN_PASSWORD} ssh ${SSH_OPTIONS} ${ADMIN_USER}@${IP} bash -s <<EOF >>VLAN_IPS
bridged_iface=\$(ifconfig -a|awk -v mac="$bridged_iface_mac" '\$0 ~ mac {print \$1}' 'RS=\n\n')
sudo ip route del default
sudo dhclient "\${bridged_iface}"
echo \$(ip addr list |grep ${bridged_iface_mac} -A 1 |grep 'inet ' |cut -d' ' -f6| cut -d/ -f1)
EOF

    done
set +x
    sed -i '/^\s*$/d' VLAN_IPS
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
    echo "* VLANs IP addresses"
    echo "* MASTER IP: `head -n1 VLAN_IPS`"
    echo "* SLAVES IPS: `tail -n +2 VLAN_IPS | tr '\n' ' '`"
    echo "* USERNAME: vagrant"
    echo "* PASSWORD: vagrant"
    echo "* K8s dashboard: http://`head -n1 VLAN_IPS`/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
set -x
fi


# collect logs
sshpass -p ${ADMIN_PASSWORD} scp ${SSH_OPTIONS} ${ADMIN_USER}@${ADMIN_IP}:/home/vagrant/solar.log logs/

if [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" != "1" ];then
    dos.py erase ${ENV_NAME}
else
    if [ "${deploy_res}" -ne "0" ];then
        dos.py snapshot ${ENV_NAME} ${ENV_NAME}.snapshot
        dos.py destroy ${ENV_NAME}
        echo "To revert snapshot please run: dos.py revert ${ENV_NAME} ${ENV_NAME}.snapshot"
    fi
fi

exit ${deploy_res}
