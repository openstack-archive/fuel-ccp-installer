#!/bin/bash -xe

ADMIN_USER=${ADMIN_USER:-vagrant}

WORKSPACE=${WORKSPACE:-.}
SSH_OPTIONS="-A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Default deployment settings
COMMON_DEFAULTS_YAML="kargo_default_common.yaml"
COMMON_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${COMMON_DEFAULTS_YAML}"

NODE_BASE_OS=${NODE_BASE_OS:-ubuntu}
OS_SPECIFIC_DEFAULTS_YAML="kargo_default_${NODE_BASE_OS}.yaml"
OS_SPECIFIC_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${OS_SPECIFIC_DEFAULTS_YAML}"

SLAVE_IPS=( $SLAVE_IPS )
ADMIN_IP=${ADMIN_IP:-${SLAVE_IPS[0]}}

required_ansible_version="2.3.0"

function exit_gracefully {
    local exit_code=$?
    set +e
    # set exit code if it is a param
    [[ -n "$1" ]] && exit_code=$1
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
            report=$(ssh ${SSH_OPTIONS} -o PasswordAuthentication=no ${ADMIN_USER}@${IP} echo ok || echo not ready)
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
    local tries=1
    until admin_node_command ansible-playbook \
        --ssh-extra-args "-A\ -o\ StrictHostKeyChecking=no" -u ${ADMIN_USER} -b \
        --become-user=root -i $ADMIN_WORKSPACE/inventory/inventory.cfg \
        $@ $KARGO_DEFAULTS_OPT $COMMON_DEFAULTS_OPT \
        $OS_SPECIFIC_DEFAULTS_OPT $custom_opts; do
            if [[ $tries > 1 ]]; then
                (( tries-- ))
                echo "Deployment failed! Trying $tries more times..."
            else
                exit_gracefully 1
            fi
    done
}

mkdir -p tmp logs


# Trap errors during env preparation stage
trap exit_gracefully ERR INT TERM

# FIXME(mattymo): Should be part of underlay
echo "Checking local SSH environment..."
if ssh-add -l &>/dev/null; then
    echo "Local SSH agent detected with at least one identity."
    INHERIT_SSH_AGENT="yes"
else
    echo "No SSH agent available. Using precreated SSH key..."
    if ! [ -f $WORKSPACE/id_rsa ]; then
        echo "ERROR: This script expects an active SSH agent or a key already \
available at $WORKSPACE/id_rsa. Exiting."
        exit_gracefully 1
    fi
    eval $(ssh-agent)
    ssh-add $WORKSPACE/id_rsa
fi

# Install missing packages on the host running this script
if ! type sshpass > /dev/null; then
    sudo apt-get update && sudo apt-get install -y sshpass
fi


echo "Preparing admin node..."
if [[ "$ADMIN_IP" != "local" ]]; then
    ADMIN_WORKSPACE="workspace"
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

# Ensure inventory exists
if ! admin_node_command test -f $ADMIN_WORKSPACE/inventory/inventory.cfg; then
    echo "ERROR: $ADMIN_WORKSPACE/inventory/inventory.cfg does not exist. \
Cannot proceed."
    exit_gracefully 1
fi

if [ -n "$SLAVE_IPS" ]; then
    SLAVE_IPS=($(admin_node_command CONFIG_FILE=$ADMIN_WORKSPACE/inventory/inventory.cfg python3 $ADMIN_WORKSPACE/utils/kargo/inventory.py print_ips))
fi

COMMON_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${COMMON_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_OPT="-e @$ADMIN_WORKSPACE/inventory/${OS_SPECIFIC_DEFAULTS_YAML}"
# Kargo opts are not needed for this
KARGO_DEFAULTS_OPT=""
if admin_node_command test -f $ADMIN_WORKSPACE/inventory/custom.yaml; then
    custom_opts="-e @$ADMIN_WORKSPACE/inventory/custom.yaml"
fi

echo "Waiting for all nodes to be reachable by SSH..."
wait_for_nodes ${SLAVE_IPS[@]}

# Stop trapping pre-setup tasks
set +e

echo "Running e2e conformance tests via ansible..."
with_ansible $ADMIN_WORKSPACE/utils/kargo/e2e_conformance.yml

exit_gracefully ${deploy_res}
