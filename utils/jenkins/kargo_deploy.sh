#!/bin/bash
set -xe

# for now we assume that master ip is 10.0.0.2 and slaves ips are 10.0.0.{3,4,5,...}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-vagrant}
ADMIN_USER=${ADMIN_USER:-vagrant}

WORKSPACE=${WORKSPACE:-.}
ENV_NAME=${ENV_NAME:-kargo-example}
SLAVES_COUNT=${SLAVES_COUNT:-0}
if [ "$VLAN_BRIDGE" ]; then
    CONF_PATH=${CONF_PATH:-${BASH_SOURCE%/*}/default30-kargo-bridge.yaml}
else
    CONF_PATH=${CONF_PATH:-${BASH_SOURCE%/*}/default30-kargo.yaml}
fi

IMAGE_PATH=${IMAGE_PATH:-bootstrap/output-qemu/ubuntu1404}
# detect OS type from the image name, assume debian by default
NODE_BASE_OS=$(basename ${IMAGE_PATH} | grep -io -e ubuntu -e debian)
NODE_BASE_OS="${NODE_BASE_OS:-debian}"
ADMIN_NODE_BASE_OS="${ADMIN_NODE_BASE_OS:-$NODE_BASE_OS}"
DEPLOY_TIMEOUT=${DEPLOY_TIMEOUT:-60}

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTIONS_COPYID=$SSH_OPTIONS
VM_LABEL=${BUILD_TAG:-unknown}

KARGO_REPO=${KARGO_REPO:-https://github.com/kubespray/kargo.git}
KARGO_COMMIT=${KARGO_COMMIT:-master}

# Default deployment settings
COMMON_DEFAULTS_YAML="kargo_default_common.yaml"
COMMON_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_YAML="kargo_default_${NODE_BASE_OS}.yaml"
OS_SPECIFIC_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${OS_SPECIFIC_DEFAULTS_YAML}"

required_ansible_version="2.1.0"

function exit_gracefully {
    exit_code=$?
    set +e
    # set exit code if it is a param
    [[ -n "$1" ]] && exit_code=$1
    if [[ "$ENV_TYPE" == "fuel-devops" && "$KEEP_ENV" != "0" ]]; then
        if [[ "${exit_code}" -eq "0" && "${DONT_DESTROY_ON_SUCCESS}" != "1" ]]; then
            dos.py erase ${ENV_NAME}
        else
            if [ "${exit_code}" -ne "0" ];then
                dos.py suspend ${ENV_NAME}
                dos.py snapshot ${ENV_NAME} ${ENV_NAME}.snapshot
                dos.py destroy ${ENV_NAME}
                echo "To revert snapshot please run: dos.py revert ${ENV_NAME} ${ENV_NAME}.snapshot"
            fi
        fi
    fi
    exit $exit_code
}

function with_retries {
    set +e
    local retries=3
    for try in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0 ] && break
        if [[ "$try" == "$retries" ]]; then
            exit 1
        fi
    done
    set -e
}

function admin_node_command {
    if [[ "$ADMIN_IP" == "local" ]];then
        eval "$@"
    else
        ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP "$@"
    fi
}

function wait_for_nodes {
    for IP in $@; do
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
}

mkdir -p tmp logs

# Allow non-Jenkins script to predefine info
if [[ -z "$SLAVE_IPS" && -z "$ADMIN_IP" ]]; then
    ENV_TYPE="fuel-devops"
    dos.py erase ${ENV_NAME} || true
    rm -rf logs/*
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} python ${BASH_SOURCE%/*}/env.py create_env

    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} python ${BASH_SOURCE%/*}/env.py get_slaves_ips | tr -d "[],'"))
    # Set ADMIN_IP=local to use current host to run ansible
    ADMIN_IP=${SLAVE_IPS[0]}
    wait_for_nodes $ADMIN_IP
else
    ENV_TYPE=${ENV_TYPE:-other}
    SLAVE_IPS=( $SLAVE_IPS )
    ADMIN_IP=${ADMIN_IP:-${SLAVE_IPS[0]}}
fi

# Trap errors during env preparation stage
trap exit_gracefully ERR INT TERM

# FIXME(mattymo): Should be part of underlay
echo "Preparing SSH key..."
if ! [ -f $WORKSPACE/id_rsa ]; then
    ssh-keygen -t rsa -f $WORKSPACE/id_rsa -N "" -q
    chmod 600 ${WORKSPACE}/id_rsa*
    test -f ~/.ssh/config && SSH_OPTIONS="${SSH_OPTIONS} -F /dev/null"
fi
eval $(ssh-agent)
ssh-add $WORKSPACE/id_rsa

# Install missing packages on the host running this script
if ! type sshpass > /dev/null; then
    sudo apt-get update && sudo apt-get install -y sshpass
fi


# Copy utils/kargo dir to WORKSPACE/utils/kargo so it works across both local
# and remote admin node deployment modes.
echo "Preparing admin node..."
if [[ "$ADMIN_IP" != "local" ]]; then
    ADMIN_WORKSPACE="workspace"
    sshpass -p $ADMIN_PASSWORD ssh-copy-id $SSH_OPTIONS_COPYID -o PreferredAuthentications=password $ADMIN_USER@${ADMIN_IP} -p 22
else
    ADMIN_WORKSPACE="$WORKSPACE"
fi
admin_node_command mkdir -p $ADMIN_WORKSPACE/utils/kargo
tar cz ${BASH_SOURCE%/*}/../kargo | admin_node_command tar xzf - -C $ADMIN_WORKSPACE/utils/

echo "Setting up ansible and required dependencies..."
installed_ansible_version=$(admin_node_command dpkg-query -W -f='\${Version}\\n' ansible || echo "0.0")
if ! admin_node_command type ansible > /dev/null || \
        dpkg --compare-versions "$installed_ansible_version" "lt" "$required_ansible_version"; then
    # Wait for apt lock in case it is updating from cron job
    admin_node_command "sh -c \"while pgrep -U -f 'apt-get|apt.system.daily' >/dev/null; do echo 'Waiting for apt lock...'; sleep 3; done\""
    case $ADMIN_NODE_BASE_OS in
        ubuntu)
            with_retries admin_node_command -- sudo apt-get update
            with_retries admin_node_command -- sudo apt-get install -y software-properties-common
            with_retries admin_node_command -- sudo apt-add-repository -y ppa:ansible/ansible
            with_retries admin_node_command -- sudo apt-get update
        ;;
        debian)
            cat ${BASH_SOURCE%/*}/files/debian_backports_repo.list | admin_node_command "sudo sh -c 'cat - > /etc/apt/sources.list.d/backports.list'"
            cat ${BASH_SOURCE%/*}/files/debian_pinning | admin_node_command "sudo sh -c 'cat - > /etc/apt/preferences.d/backports'"
            with_retries admin_node_command sudo apt-get update
            with_retries admin_node_command sudo apt-get -y install --only-upgrade python-setuptools
        ;;
    esac
    admin_node_command sudo apt-get install -y ansible python-netaddr git
fi

echo "Checking out kargo playbook..."
admin_node_command "sh -c 'cd $ADMIN_WORKSPACE && git clone $KARGO_REPO'" || true
admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/kargo && git fetch --all && git checkout $KARGO_COMMIT'"


cat $WORKSPACE/id_rsa | admin_node_command "cat - > .ssh/id_rsa"
admin_node_command chmod 600 .ssh/id_rsa

echo "Uploading default settings..."
cat $COMMON_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/kargo/${COMMON_DEFAULTS_YAML}"
cat $OS_SPECIFIC_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/kargo/${OS_SPECIFIC_DEFAULTS_YAML}"
COMMON_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/kargo/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/kargo/${OS_SPECIFIC_DEFAULTS_YAML}"

if [ -n "$CUSTOM_YAML" ]; then
    echo "Uploading custom YAML for deployment..."
    echo -e "$CUSTOM_YAML" | admin_node_command "cat > $ADMIN_WORKSPACE/kargo/custom.yaml"
    custom_opts="-e @$ADMIN_WORKSPACE/kargo/custom.yaml"
fi

echo "Generating ansible inventory on admin node..."
admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/kargo/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/utils/kargo/inventory.py ${SLAVE_IPS[@]}

echo "Waiting for all nodes to be reachable by SSH..."
wait_for_nodes ${SLAVE_IPS[@]}

echo "Adding ssh key authentication and labels to nodes..."
for slaveip in ${SLAVE_IPS[@]}; do
    # FIXME(mattymo): Underlay provisioner should set up keys
    sshpass -p $ADMIN_PASSWORD ssh-copy-id $SSH_OPTIONS_COPYID -o PreferredAuthentications=password $ADMIN_USER@${slaveip} -p 22

    # FIXME(mattymo): Underlay provisioner should set label file
    # Add VM label:
    ssh $SSH_OPTIONS $ADMIN_USER@$slaveip "echo $VM_LABEL > /home/${ADMIN_USER}/vm_label"
done

# Stop trapping pre-setup tasks
set +e

echo "Running pre-setup steps on nodes via ansible..."
tries=3
until admin_node_command /usr/bin/ansible-playbook \
    --ssh-extra-args "-o\ StrictHostKeyChecking=no" -u ${ADMIN_USER} -b \
    --become-user=root -i $ADMIN_WORKSPACE/kargo/inventory/inventory.cfg \
    $ADMIN_WORKSPACE/utils/kargo/preinstall.yml $COMMON_DEFAULTS_OPT \
    $OS_SPECIFIC_DEFAULTS_OPT $custom_opts; do
        if [[ $tries > 1 ]]; then
            (( tries-- ))
            echo "Deployment failed! Trying $tries more times..."
        else
            exit_gracefully 1
        fi
done


echo "Deploying k8s via ansible..."
tries=3
until admin_node_command /usr/bin/ansible-playbook \
    --ssh-extra-args "-o\ StrictHostKeyChecking=no" -u ${ADMIN_USER} -b \
    --become-user=root -i $ADMIN_WORKSPACE/kargo/inventory/inventory.cfg \
    $ADMIN_WORKSPACE/kargo/cluster.yml $COMMON_DEFAULTS_OPT \
    $OS_SPECIFIC_DEFAULTS_OPT $custom_opts; do
        if [[ $tries > 1 ]]; then
            (( tries-- ))
            echo "Deployment failed! Trying $tries more times..."
        else
            exit_gracefully 1
        fi
done
deploy_res=0

echo "Initial deploy succeeded. Proceeding with post-install tasks..."
tries=3
until admin_node_command /usr/bin/ansible-playbook \
    --ssh-extra-args "-o\ StrictHostKeyChecking=no" -u ${ADMIN_USER} -b \
    --become-user=root -i $ADMIN_WORKSPACE/kargo/inventory/inventory.cfg \
    $ADMIN_WORKSPACE/utils/kargo/postinstall.yml $COMMON_DEFAULTS_OPT \
    $OS_SPECIFIC_DEFAULTS_OPT $custom_opts; do
        if [[ $tries > 1 ]]; then
            (( tries-- ))
            echo "Deployment failed! Trying $tries more times..."
        else
            exit_gracefully 1
        fi
done

# FIXME(mattymo): Move this to underlay
# setup VLAN if everything is ok and env will not be deleted
if [ "$VLAN_BRIDGE" ] && [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" = "1" ];then
    rm -f VLAN_IPS
    for IP in ${SLAVE_IPS[@]}; do
        bridged_iface_mac="`ENV_NAME=${ENV_NAME} python ${BASH_SOURCE%/*}/env.py get_bridged_iface_mac $IP`"

        sshpass -p ${ADMIN_PASSWORD} ssh ${SSH_OPTIONS} ${ADMIN_USER}@${IP} bash -s <<EOF >>VLAN_IPS
bridged_iface=\$(/sbin/ifconfig -a|awk -v mac="$bridged_iface_mac" '\$0 ~ mac {print \$1}' 'RS=\n\n')
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
    echo "* K8s dashboard: https://kube:changeme@`head -n1 VLAN_IPS`/ui/"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
set -x
    rm -f VLAN_IPS
fi


exit_gracefully ${deploy_res}
