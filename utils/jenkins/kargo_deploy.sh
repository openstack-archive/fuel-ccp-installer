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

IMAGE_PATH=${IMAGE_PATH:-$HOME/packer-ubuntu-16.04.1-server-amd64.qcow2}
# detect OS type from the image name, assume ubuntu by default
NODE_BASE_OS=$(basename ${IMAGE_PATH} | grep -io -e ubuntu -e debian || echo -n "ubuntu")
ADMIN_NODE_BASE_OS="${ADMIN_NODE_BASE_OS:-$NODE_BASE_OS}"
DEPLOY_TIMEOUT=${DEPLOY_TIMEOUT:-60}

SSH_OPTIONS="-A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTIONS_COPYID="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
VM_LABEL=${BUILD_TAG:-unknown}

KARGO_REPO=${KARGO_REPO:-https://github.com/kubernetes-incubator/kargo.git}
KARGO_COMMIT=${KARGO_COMMIT:-origin/master}

# Default deployment settings
COMMON_DEFAULTS_YAML="kargo_default_common.yaml"
COMMON_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_YAML="kargo_default_${NODE_BASE_OS}.yaml"
OS_SPECIFIC_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${OS_SPECIFIC_DEFAULTS_YAML}"
SCALE_DEFAULTS_YAML="scale_defaults.yaml"
SCALE_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${SCALE_DEFAULTS_YAML}"
SCALE_MODE=${SCALE_MODE:-no}
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-600}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-50}

# Valid sources: pip, apt
ANSIBLE_INSTALL_SOURCE=pip
required_ansible_version="2.2.1"

function collect_info {
    # Get diagnostic info and store it as the logs.tar.gz at the admin node
    admin_node_command FORKS=$ANSIBLE_FORKS ADMIN_USER=$ADMIN_USER \
        ADMIN_WORKSPACE=$ADMIN_WORKSPACE collect_logs.sh > /dev/null
}

function exit_gracefully {
    local exit_code=$?
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
    # Kill current ssh-agent
    if [ -z "$INHERIT_SSH_AGENT" ]; then
        eval $(ssh-agent -k)
    fi
    exit $exit_code
}

function with_retries {
    local retries=3
    set +e
    set -o pipefail
    for try in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0 ] && break
        if [[ "$try" == "$retries" ]]; then
            exit 1
        fi
    done
    set +o pipefail
    set -e
}

function admin_node_command {
# Accepts commands from args passed to function or multiple commands via stdin,
# one per line.
    if [[ "$ADMIN_IP" == "local" ]]; then
        if [ $# -gt 0 ];then
            eval "$@"
        else
            cat | while read cmd; do
               eval "$cmd"
            done
        fi
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

function wait_for_apt_lock_release {
    while admin_node_command 'sudo lslocks | egrep "apt|dpkg"'; do
        echo 'Waiting for other software managers to release apt lock ...'
        sleep 10
    done
}

function with_ansible {
    local tries=5
    local retry_opt=""
    playbook=$1
    retryfile=${playbook/.yml/.retry}

    until admin_node_command \
        ANSIBLE_CONFIG=$ADMIN_WORKSPACE/utils/kargo/ansible.cfg \
        ansible-playbook \
        --ssh-extra-args "-A\ -o\ StrictHostKeyChecking=no\ -o\ ConnectionAttempts=20" \
        -u ${ADMIN_USER} -b \
        --become-user=root -i $ADMIN_WORKSPACE/inventory/inventory.cfg \
        --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT $DEFAULT_OPTS \
        -e ansible_ssh_user=${ADMIN_USER} \
        $custom_opts $retry_opt $@; do
            if [[ $tries -gt 1 ]]; then
                tries=$((tries - 1))
                echo "Deployment failed! Trying $tries more times..."
            else
                collect_info
                exit_gracefully 1
            fi

            if admin_node_command test -e "$retryfile"; then
                retry_opt="--limit @${retryfile}"
            fi
    done
    rm -f "$retryfile" || true
}

mkdir -p tmp logs

# If SLAVE_IPS or IRONIC_NODE_LIST are specified or REAPPLY is set, then treat env as pre-provisioned
if [[ -z "$REAPPLY" && -z "$SLAVE_IPS" && -z "$IRONIC_NODE_LIST" ]]; then
    ENV_TYPE="fuel-devops"

    echo "Trying to ensure bridge-nf-call-iptables is disabled..."
    br_netfilter=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables)
    if [[ "$br_netfilter" == "1" ]]; then
        sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
    fi

    dos.py erase ${ENV_NAME} || true
    rm -rf logs/*
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} python ${BASH_SOURCE%/*}/env.py create_env

    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} python ${BASH_SOURCE%/*}/env.py get_slaves_ips | tr -d "[],'"))
    # Set ADMIN_IP=local to use current host to run ansible
    ADMIN_IP=${ADMIN_IP:-${SLAVE_IPS[0]}}
    wait_for_nodes ${SLAVE_IPS[0]}
else
    ENV_TYPE=${ENV_TYPE:-other_or_reapply}
    SLAVE_IPS=( $SLAVE_IPS )
fi
ADMIN_IP=${ADMIN_IP:-${SLAVE_IPS[0]}}

# Trap errors during env preparation stage
trap exit_gracefully ERR INT TERM

# FIXME(mattymo): Should be part of underlay
echo "Checking local SSH environment..."
if ssh-add -l &>/dev/null; then
    echo "Local SSH agent detected with at least one identity."
    INHERIT_SSH_AGENT="yes"
else
    echo "No SSH agent available. Preparing SSH key..."
    if ! [ -f $WORKSPACE/id_rsa ]; then
        ssh-keygen -t rsa -f $WORKSPACE/id_rsa -N "" -q
        chmod 600 ${WORKSPACE}/id_rsa*
        test -f ~/.ssh/config && SSH_OPTIONS="${SSH_OPTIONS} -F /dev/null"
    fi
    eval $(ssh-agent)
    ssh-add $WORKSPACE/id_rsa
fi

# Install missing packages on the host running this script
if ! type sshpass 2>&1 > /dev/null; then
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
if [[ -n "$ADMIN_NODE_CLEANUP" ]]; then
    if [[ "$ADMIN_IP" != "local" ]]; then
        admin_node_command rm -rf $ADMIN_WORKSPACE || true
    else
        for dir in inventory kargo utils; do
            admin_node_command rm -rf ${ADMIN_WORKSPACE}/${dir} || true
        done
    fi
fi
admin_node_command mkdir -p "$ADMIN_WORKSPACE/utils/kargo" "$ADMIN_WORKSPACE/inventory"
tar cz ${BASH_SOURCE%/*}/../kargo | admin_node_command tar xzf - -C $ADMIN_WORKSPACE/utils/

echo "Setting up ansible and required dependencies..."
# Install mandatory packages on admin node
if ! admin_node_command type sshpass 2>&1 > /dev/null; then
    admin_node_command "sh -c \"sudo apt-get update && sudo apt-get install -y sshpass\""
fi
if ! admin_node_command type git 2>&1 > /dev/null; then
    admin_node_command "sh -c \"sudo apt-get update && sudo apt-get install -y git\""
fi

if ! admin_node_command type ansible 2>&1 > /dev/null; then
    # Wait for apt lock in case it is updating from cron job
    case $ADMIN_NODE_BASE_OS in
        ubuntu)
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-get update
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-get install -y software-properties-common
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 7BB9C367
            wait_for_apt_lock_release
            with_retries admin_node_command -- "sh -c \"sudo apt-add-repository -y 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu xenial main'\""
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-get update
            wait_for_apt_lock_release
        ;;
        debian)
            cat ${BASH_SOURCE%/*}/files/debian_backports_repo.list | admin_node_command "sudo sh -c 'cat - > /etc/apt/sources.list.d/backports.list'"
            cat ${BASH_SOURCE%/*}/files/debian_pinning | admin_node_command "sudo sh -c 'cat - > /etc/apt/preferences.d/backports'"
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-get update
            wait_for_apt_lock_release
            with_retries admin_node_command -- sudo apt-get -y install --only-upgrade python-setuptools
        ;;
    esac
    wait_for_apt_lock_release
    if [[ "$ANSIBLE_INSTALL_SOURCE" == "apt" ]]; then
        with_retries admin_node_command -- sudo apt-get install -y ansible python-netaddr
    elif [[ "$ANSIBLE_INSTALL_SOURCE" == "pip" ]]; then
        with_retries admin_node_command -- sudo apt-get install -y python-netaddr libssl-dev python-pip
        with_retries admin_node_command -- sudo pip install --upgrade ansible==$required_ansible_version
    else
         echo "ERROR: Unknown Ansible install source: ${ANSIBLE_INSTALL_SOURCE}"
         exit 1
    fi
fi

echo "Checking out kargo playbook..."
admin_node_command git clone "$KARGO_REPO" "$ADMIN_WORKSPACE/kargo" || true
admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/kargo && git fetch --all && git checkout $KARGO_COMMIT'"

echo "Uploading default settings and inventory..."
# Only copy default files if they are absent from inventory dir
if ! admin_node_command test -e "$ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"; then
    cat $COMMON_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"
fi
if ! admin_node_command test -e "$ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"; then
    cat $OS_SPECIFIC_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"
fi
if ! admin_node_command test -e "$ADMIN_WORKSPACE/inventory/${SCALE_DEFAULTS_YAML}"; then
    cat $SCALE_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/${SCALE_DEFAULTS_YAML}"
fi
if ! admin_node_command test -e "${ADMIN_WORKSPACE}/inventory/group_vars"; then
    admin_node_command ln -rsf "${ADMIN_WORKSPACE}/kargo/inventory/group_vars" "${ADMIN_WORKSPACE}/inventory/group_vars"
fi

if [[ -n "${CUSTOM_YAML}" ]]; then
    echo "Uploading custom YAML for deployment..."
    echo -e "$CUSTOM_YAML" | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/custom.yaml"
fi
if admin_node_command test -e "$ADMIN_WORKSPACE/inventory/custom.yaml"; then
    custom_opts="-e @$ADMIN_WORKSPACE/inventory/custom.yaml"
fi

if [ -n "${SLAVE_IPS}" ]; then
    admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/kargo/contrib/inventory_builder/inventory.py ${SLAVE_IPS[@]}
elif [ -n "${IRONIC_NODE_LIST}" ]; then
    inventory_formatted=$(echo -e "$IRONIC_NODE_LIST" | ${BASH_SOURCE%/*}/../ironic/nodelist_to_inventory.py)
    admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/kargo/contrib/inventory_builder/inventory.py load /dev/stdin <<< "$inventory_formatted"
fi

# Try to get IPs from inventory first
if [ -z "${SLAVE_IPS}" ]; then
    if admin_node_command stat $ADMIN_WORKSPACE/inventory/inventory.cfg; then
        SLAVE_IPS=($(admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/kargo/contrib/inventory_builder/inventory.py print_ips))
    else
        echo "No slave nodes available. Unable to proceed!"
        exit_gracefully 1
    fi
fi

COMMON_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"
SCALE_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${SCALE_DEFAULTS_YAML}"
if [[ "${#SLAVE_IPS[@]}" -lt 50 && "$SCALE_MODE" == "no" ]]; then
    DEFAULT_OPTS="${COMMON_DEFAULTS_OPT} ${OS_SPECIFIC_DEFAULTS_OPT}"
else
    DEFAULT_OPTS="${COMMON_DEFAULTS_OPT} ${OS_SPECIFIC_DEFAULTS_OPT} ${SCALE_DEFAULTS_OPT}"
fi

# Stop trapping pre-setup tasks
set +e


echo "Running pre-setup steps on nodes via ansible..."
with_ansible $ADMIN_WORKSPACE/utils/kargo/preinstall.yml -e "ansible_ssh_pass=${ADMIN_PASSWORD}"

echo "Deploying k8s masters/etcds first via ansible..."
with_ansible $ADMIN_WORKSPACE/kargo/cluster.yml --limit kube-master:etcd

# Only run non-master deployment if there are non-masters in inventory.
if admin_node_command ansible-playbook -i $ADMIN_WORKSPACE/inventory/inventory.cfg \
        $ADMIN_WORKSPACE/kargo/cluster.yml --limit kube-node:!kube-master:!etcd \
        --list-hosts &>/dev/null; then
    echo "Deploying k8s non-masters via ansible..."
    with_ansible $ADMIN_WORKSPACE/kargo/cluster.yml --limit kube-node:!kube-master:!etcd
fi

echo "Initial deploy succeeded. Proceeding with post-install tasks..."
with_ansible $ADMIN_WORKSPACE/utils/kargo/postinstall.yml

# FIXME(mattymo): Move this to underlay
# setup VLAN if everything is ok and env will not be deleted
if [ "$VLAN_BRIDGE" ] && [ "${DONT_DESTROY_ON_SUCCESS}" = "1" ];then
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
    echo "Deployment is complete!"
    echo "* VLANs IP addresses"
    echo "* MASTER IP: `head -n1 VLAN_IPS`"
    echo "* NODE IPS: `tail -n +2 VLAN_IPS | tr '\n' ' '`"
    echo "* USERNAME: $ADMIN_USER"
    echo "* PASSWORD: $ADMIN_PASSWORD"
    echo "* K8s dashboard: https://kube:changeme@`head -n1 VLAN_IPS`/ui/"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
set -x
    rm -f VLAN_IPS
else
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
    echo "Deployment is complete!"
    echo "* Node network addresses:"
    echo "* MASTER IP: $ADMIN_IP"
    echo "* NODE IPS: $SLAVE_IPS"
    echo "* USERNAME: $ADMIN_USER"
    echo "* PASSWORD: $ADMIN_PASSWORD"
    echo "* K8s dashboard: https://kube:changeme@${SLAVE_IPS[0]}/ui/"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
fi

# TODO(mattymo): Shift to FORCE_NEW instead of REAPPLY
echo "To reapply deployment, run env REAPPLY=yes ADMIN_IP=$ADMIN_IP $0"
exit_gracefully 0
