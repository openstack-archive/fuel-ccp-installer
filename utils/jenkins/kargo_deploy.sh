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

KARGO_REPO=${KARGO_REPO:-https://github.com/kubespray/kargo.git}
KARGO_COMMIT=${KARGO_COMMIT:-origin/master}

# Default deployment settings
COMMON_DEFAULTS_YAML="kargo_default_common.yaml"
COMMON_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_YAML="kargo_default_${NODE_BASE_OS}.yaml"
OS_SPECIFIC_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${OS_SPECIFIC_DEFAULTS_YAML}"
LOG_LEVEL=${LOG_LEVEL:--v}

required_ansible_version="2.1.0"

function collect_info {
    # Get diagnostic info and store it as the logs.tar.gz at the admin node
    admin_node_command ADMIN_USER=$ADMIN_USER LOG_LEVEL="" \
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

function with_ansible {
    local tries=3
    until admin_node_command /usr/bin/ansible-playbook \
        --ssh-extra-args "-A\ -o\ StrictHostKeyChecking=no" -u ${ADMIN_USER} -b \
        --become-user=root -i $ADMIN_WORKSPACE/inventory/inventory.cfg \
        $@ $KARGO_DEFAULTS_OPT $COMMON_DEFAULTS_OPT \
        $OS_SPECIFIC_DEFAULTS_OPT $custom_opts; do
            if [[ $tries > 1 ]]; then
                (( tries-- ))
                echo "Deployment failed! Trying $tries more times..."
            else
                collect_info
                exit_gracefully 1
            fi
    done
}

mkdir -p tmp logs

# If INVENTORY_REPO or SLAVE_IPS are specified or REAPPLY is set, then treat env as pre-provisioned
if [[ -z "$INVENTORY_REPO" && -z "$REAPPLY" && -z "$SLAVE_IPS" ]]; then
    ENV_TYPE="fuel-devops"
    dos.py erase ${ENV_NAME} || true
    rm -rf logs/*
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} python ${BASH_SOURCE%/*}/env.py create_env

    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} python ${BASH_SOURCE%/*}/env.py get_slaves_ips | tr -d "[],'"))
    # Set ADMIN_IP=local to use current host to run ansible
    ADMIN_IP=${SLAVE_IPS[0]}
    wait_for_nodes $ADMIN_IP
else
    ENV_TYPE=${ENV_TYPE:-other_or_reapply}
    SLAVE_IPS=( $SLAVE_IPS )
    ADMIN_IP=${ADMIN_IP:-${SLAVE_IPS[0]}}
fi

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
    while admin_node_command pgrep -a -f apt; do echo 'Waiting for apt lock...'; sleep 30; done
    case $ADMIN_NODE_BASE_OS in
        ubuntu)
            with_retries admin_node_command -- sudo apt-get update
            with_retries admin_node_command -- sudo apt-get install -y software-properties-common
            with_retries admin_node_command -- sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 7BB9C367
            with_retries admin_node_command -- "sh -c \"sudo apt-add-repository -y 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu xenial main'\""
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
admin_node_command git clone "$KARGO_REPO" "$ADMIN_WORKSPACE/kargo" || true
admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/kargo && git fetch --all && git checkout $KARGO_COMMIT'"

# If no inventory repo, just make a local git repo and carry on and deploy.
# Otherwise, clone it and decide on the final deployment data.
if [ "${INVENTORY_REPO}" ]; then
    admin_node_command "sh -c 'git clone $INVENTORY_REPO $ADMIN_WORKSPACE/inventory'" || true
    if [ -n "${INVENTORY_COMMIT}" ]; then
        admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/inventory && git fetch --all && git checkout $INVENTORY_COMMIT'"
    fi
    if [ "${SLAVE_IPS}" -a -f $ADMIN_WORKSPACE/inventory/inventory.cfg ]; then
        echo "ERROR: Updating inventory via SLAVE_IPS env var after initial deployment is not supported."
        exit 1
    fi
else
    echo "Generating ansible inventory on admin node..."
    admin_node_command mkdir -p $ADMIN_WORKSPACE/inventory
    admin_node_command git init $ADMIN_WORKSPACE/inventory
fi

echo "Uploading default settings and inventory..."
cat $COMMON_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"
cat $OS_SPECIFIC_DEFAULTS_SRC | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"
if [ "${CUSTOM_YAML}" ]; then
    echo "Uploading custom YAML for deployment..."
    echo -e "$CUSTOM_YAML" | admin_node_command "cat > $ADMIN_WORKSPACE/inventory/custom.yaml"
    custom_opts="-e @$ADMIN_WORKSPACE/inventory/custom.yaml"
fi
if [ "${SLAVE_IPS}" ]; then
    admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/utils/kargo/inventory.py ${SLAVE_IPS[@]}
fi

# Data committed to the inventory has the highest priority, then installer defaults
echo "Deciding on deployment data to the inventory repo..."
# Stage only new data files
admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/inventory && git ls-files -o --exclude-standard | xargs -n1 git add'"
if [ -z "${INVENTORY_REPO}" ]; then
    # Local only repos must stage any changes as well
    admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/inventory && git ls-files -m | xargs -n1 git add'"
else
    # Reset changed data files for remote repos
    admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/inventory && git ls-files -m | xargs -n1 git checkout -- .'"
fi

# Try to get IPs from inventory first
if [ -z "${SLAVE_IPS}" ]; then
    if admin_node_command stat $ADMIN_WORKSPACE/inventory/inventory.cfg; then
        SLAVE_IPS=($(admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/utils/kargo/inventory.py print_ips))
    else
        echo "No slave nodes available. Unable to proceed!"
        exit_gracefully 1
    fi
fi

COMMON_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"
KARGO_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/kargo/inventory/group_vars/all.yml"

echo "Committing inventory changes..."
if ! admin_node_command git config --get user.name; then
    admin_node_command git config --global user.name "Anonymous User"
    admin_node_command git config --global user.email "anon@example.org"
fi
# Commit only if there are changes
if ! admin_node_command git -C $ADMIN_WORKSPACE/inventory diff --cached --name-only --exit-code; then
    admin_node_command "sh -c 'cd $ADMIN_WORKSPACE/inventory && git commit -a -m Automated\ commit'"
    COMMIT_DONE=true
fi

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
with_ansible $ADMIN_WORKSPACE/utils/kargo/preinstall.yml

echo "Running kargo preinstall early via ansible..."
with_ansible $ADMIN_WORKSPACE/kargo/cluster.yml --tags preinstall

echo "Configuring DNS settings on nodes via ansible..."
# FIXME(bogdando) a hack to w/a https://github.com/kubespray/kargo/issues/452
with_ansible $ADMIN_WORKSPACE/kargo/cluster.yml --tags dnsmasq -e inventory_hostname=skip_k8s_part

echo "Deploying k8s via ansible..."
with_ansible $ADMIN_WORKSPACE/kargo/cluster.yml

echo "Initial deploy succeeded. Proceeding with post-install tasks..."
with_ansible $ADMIN_WORKSPACE/utils/kargo/postinstall.yml

# Submit the commit to gerrit
if [ "${COMMIT_DONE}" = "true" ]; then
    if admin_node_command test -e $ADMIN_WORKSPACE/inventory/.gitreview; then
        echo "Changes were made to deployment. Proposing change request to configuration repository..."
        admin_node_command git -C $ADMIN_WORKSPACE/inventory git review -s
        admin_node_command git -C $ADMIN_WORKSPACE/inventory git review || true
        echo "Go to the Gerrit link above and review the changes."
    fi
fi

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
