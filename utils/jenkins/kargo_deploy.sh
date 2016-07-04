#!/bin/bash
set -xe

# for now we assume that master ip is 10.0.0.2 and slaves ips are 10.0.0.{3,4,5,...}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-vagrant}
ADMIN_USER=${ADMIN_USER:-vagrant}

WORKSPACE=${WORKSPACE:-.}
ENV_NAME=${ENV_NAME:-kargo-example}
SLAVES_COUNT=${SLAVES_COUNT:-0}
if [ "$VLAN_BRIDGE" ]; then
    CONF_PATH=${CONF_PATH:-utils/jenkins/default30-kargo-bridge.yaml}
else
    CONF_PATH=${CONF_PATH:-utils/jenkins/default30-kargo.yaml}
fi

IMAGE_PATH=${IMAGE_PATH:-bootstrap/output-qemu/ubuntu1404}
DEPLOY_TIMEOUT=${DEPLOY_TIMEOUT:-60}

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
VM_LABEL=${BUILD_TAG:-unknown}

KARGO_REPO=${KARGO_REPO:-https://github.com/kubespray/kargo.git}
KARGO_COMMIT=${KARGO_COMMIT:-master}


mkdir -p tmp logs


# Allow non-Jenkins script to predefine info
if [[ -z "$SLAVE_IPS" && -z "$ADMIN_IP" ]]; then
    ENV_TYPE="fuel-devops"
    dos.py erase ${ENV_NAME} || true
    rm -rf logs/*
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} python utils/jenkins/env.py create_env

    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} python utils/jenkins/env.py get_slaves_ips | tr -d "[],'"))
    ADMIN_IP=${SLAVE_IPS[0]}
else
    ENV_TYPE={ENV_TYPE:-other}
fi

# Wait for all servers(grep only IP addresses):
for IP in ${SLAVE_IPS[@]}; do
    elapsed_time=0
    master_wait_time=30
    while true; do
        report=$(sshpass -p ${ADMIN_PASSWORD} ssh ${SSH_OPTIONS} -o PreferredAuthentications=password ${ADMIN_USER}@${IP} echo ok || echo not ready)

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

set +e
current_slave=1
deploy_args=""

echo "Preparing SSH key..."
if ! [ -f $WORKSPACE/id_rsa ]; then
    ssh-keygen -t rsa -f $WORKSPACE/id_rsa -N "" -q
fi
eval $(ssh-agent)
ssh-add $WORKSPACE/id_rsa

echo "Adding ssh key authentication and labels to nodes..."
for slaveip in ${SLAVE_IPS[@]}; do
    sshpass -p $ADMIN_PASSWORD ssh-copy-id $SSH_OPTIONS -o PreferredAuthentications=password $ADMIN_USER@${slaveip} -p 22

    # FIXME(mattymo): underlay should set hostnames
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "sudo hostnamectl set-hostname node${current_slave}"
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "sudo sed -i 's/127.0.1.1.*/127.0.1.1 node${current_slave}/g' /etc/hosts"

    # Workaround to disable ipv6 dns which can cause docker pull to fail
    echo "precedence ::ffff:0:0/96  100" | ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "sudo sh -c 'cat - >> /etc/gai.conf'"

    # Workaround to fix DNS search domain: https://github.com/kubespray/kargo/issues/322
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "sudo apt-get remove -y resolvconf"
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "sudo rm -rf /etc/resolvconf"

    # Add VM label:
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "echo $VM_LABEL > /home/vagrant/vm_label"

    deploy_args+=" node${current_slave}[ansible_ssh_host=${slaveip},ip=${slaveip}]"
    ((current_slave++))
done

echo "Setting up required dependencies..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP sudo apt-get update
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP sudo apt-get install -y git python-setuptools python-dev python-pip gcc libssl-dev libffi-dev vim software-properties-common
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP "sudo pip install 'cryptography>=1.3.2'"
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP "sudo pip install 'cffi>=1.6.0'"

echo "Setting up ansible..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP 'sudo sh -c "apt-add-repository -y ppa:ansible/ansible;apt-get update;apt-get install -y ansible"'

echo "Setting up kargo-cli..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP git clone https://github.com/kubespray/kargo-cli.git
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP "sudo sh -c 'cd kargo-cli && python setup.py install'"

echo "Checking out kargo playbook..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP git clone $KARGO_REPO
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP sh -c "cd kargo && git checkout $KARGO_COMMIT"

echo "Preparing kargo node..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP kargo prepare -y --noclone --nodes $deploy_args
cat $WORKSPACE/id_rsa | ssh $SSH_OPTIONS $ADMIN_USER@${SLAVE_IPS[0]} "cat - > .ssh/id_rsa"
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP chmod 600 .ssh/id_rsa

if [ -n "$CUSTOM_YAML" ]; then
    echo "Uploading custom YAML for deployment..."
    echo -e "$CUSTOM_YAML" | ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP "cat > kargo/custom.yaml"
    custom_opts="-e @kargo/custom.yaml"
fi


echo "Deploying k8s via ansible..."
ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP /usr/bin/ansible-playbook \
    --ssh-extra-args "-o\ StrictHostKeyChecking=no" -u vagrant -b \
    --become-user=root -i /home/vagrant/kargo/inventory/inventory.cfg \
    /home/vagrant/kargo/cluster.yml $custom_opts

deploy_res=$?

if [ "$deploy_res" -eq "0" ]; then
    echo "Setting up kubedns..."
    ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP sudo pip install kpm
    ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP sudo /usr/local/bin/kpm deploy kube-system/kubedns --namespace=kube-system
    for waiting in `seq 1 10`; do
        ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP kubectl get po --namespace=kube-system | grep kubedns | grep -q Running && break
        if [ $waiting -lt 10 ]; then
            echo "Waiting for kubedns to be up..."
            sleep 5
        else
            echo "Kubedns did not come up in time"
            deploy_res=1
        fi
    done

fi

# Test cluster network connectivity
. utils/kargo/test_networking.sh
test_networking

# setup VLAN if everything is ok and env will not be deleted
if [ "$VLAN_BRIDGE" ] && [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" = "1" ];then
    rm -f VLAN_IPS
    for IP in ${SLAVE_IPS[@]}; do
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
    echo "* USERNAME: $ADMIN_USER"
    echo "* PASSWORD: $ADMIN_PASSWORD"
    echo "* K8s dashboard: http://`head -n1 VLAN_IPS`/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
set -x
fi

if [[ "$ENV_TYPE" == "fuel-devops" ]]; then
    if [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" != "1" ];then
        dos.py erase ${ENV_NAME}
    else
        if [ "${deploy_res}" -ne "0" ];then
            dos.py suspend ${ENV_NAME}
            dos.py snapshot ${ENV_NAME} ${ENV_NAME}.snapshot
            dos.py destroy ${ENV_NAME}
            echo "To revert snapshot please run: dos.py revert ${ENV_NAME} ${ENV_NAME}.snapshot"
        fi
    fi
fi

exit ${deploy_res}
