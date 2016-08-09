#!/bin/bash

set -xe

ADMIN_PASSWORD="${ADMIN_PASSWORD:-vagrant}"
ADMIN_USER="${ADMIN_USER:-vagrant}"

WORKSPACE="${WORKSPACE:-.}"
ENV_NAME="${ENV_NAME:-kargo-example}"
SLAVES_COUNT="${SLAVES_COUNT:-0}"
if [ "$VLAN_BRIDGE" ]; then
    CONF_PATH="${CONF_PATH:-${BASH_SOURCE%/*}/default30-kargo-bridge.yaml}"
else
    CONF_PATH="${CONF_PATH:-${BASH_SOURCE%/*}/default30-kargo.yaml}"
fi

IMAGE_PATH="${IMAGE_PATH:-bootstrap/output-qemu/ubuntu1404}"

# detect OS type from the image name, assume debian by default
NODE_BASE_OS="$(basename "${IMAGE_PATH}" | grep -io -e ubuntu -e debian)"
NODE_BASE_OS="${NODE_BASE_OS:-debian}"
ADMIN_NODE_BASE_OS="${ADMIN_NODE_BASE_OS:-$NODE_BASE_OS}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-60}"

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
VM_LABEL="${BUILD_TAG:-unknown}"

KARGO_REPO="${KARGO_REPO:-https://github.com/kubespray/kargo.git}"
KARGO_COMMIT="${KARGO_COMMIT:-master}"

# Default deployment settings
COMMON_DEFAULTS_YAML="kargo_default_common.yaml"
COMMON_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${COMMON_DEFAULTS_YAML}"
COMMON_DEFAULTS_OPT=(-e "@~/kargo/${COMMON_DEFAULTS_YAML}")
OS_SPECIFIC_DEFAULTS_YAML="kargo_default_${NODE_BASE_OS}.yaml"
OS_SPECIFIC_DEFAULTS_SRC="${BASH_SOURCE%/*}/../kargo/${OS_SPECIFIC_DEFAULTS_YAML}"
OS_SPECIFIC_DEFAULTS_OPT=(-e "@~/kargo/${OS_SPECIFIC_DEFAULTS_YAML}")

required_ansible_version="2.1.0"

function exit_gracefully {
    exit_code=$?
    set +e
    # set exit code if it is a param
    [[ -n "$1" ]] && exit_code=$1
    if [[ "$ENV_TYPE" == "fuel-devops" && "$KEEP_ENV" != "0" ]]; then
        if [[ "${exit_code}" -eq "0" && "${DONT_DESTROY_ON_SUCCESS}" != "1" ]]; then
            dos.py erase "${ENV_NAME}"
        else
            if [ "${exit_code}" -ne "0" ];then
                dos.py suspend "${ENV_NAME}"
                dos.py snapshot "${ENV_NAME}" "${ENV_NAME}.snapshot"
                dos.py destroy "${ENV_NAME}"
                echo "To revert snapshot please run: dos.py revert-resume --no-timesync ${ENV_NAME} ${ENV_NAME}.snapshot"
            fi
        fi
    fi
    exit "$exit_code"
}

function with_retries {
    set +e
    local retries=3
    for try in $(seq 1 $retries); do
        "${@}"
        [ $? -eq 0 ] && break
        if [[ "$try" -ge "$retries" ]]; then
            exit 1
        fi
    done
    set -e
}

function admin_node_command {
    if [[ "$ADMIN_IP" == "local" ]];then
        eval "$@"
    else
        ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${ADMIN_IP}" "$@" # shellcheck disable=SC2029
    fi
}

function wait_for_nodes {
    for IP in "$@"; do
        elapsed_time=0
        master_wait_time=30
        while true; do
            report="$(sshpass -p "${ADMIN_PASSWORD}" ssh "${SSH_OPTIONS[@]}" -o PreferredAuthentications=password "${ADMIN_USER}@${IP}" echo ok || echo not ready)"

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
    dos.py erase "${ENV_NAME}" || true
    rm -rf logs/*
    ENV_NAME="${ENV_NAME}" SLAVES_COUNT="${SLAVES_COUNT}" IMAGE_PATH="${IMAGE_PATH}" CONF_PATH="${CONF_PATH}" python "${BASH_SOURCE%/*}/env.py" create_env

    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} python "${BASH_SOURCE%/*}/env.py" get_slaves_ips | tr -d "[],'"))
    # Set ADMIN_IP=local to use current host to run ansible
    ADMIN_IP="${SLAVE_IPS[0]}"
    wait_for_nodes "$ADMIN_IP"
else
    ENV_TYPE="${ENV_TYPE:-other}"
    SLAVE_IPS=( ${SLAVE_IPS[*]} )
    ADMIN_IP="${ADMIN_IP:-${SLAVE_IPS[0]}}"
fi

# Trap errors during env preparation stage
trap exit_gracefully ERR INT TERM

# FIXME(mattymo): Should be part of underlay
echo "Preparing SSH key..."
if ! [ -f "${WORKSPACE}/id_rsa" ]; then
    ssh-keygen -t rsa -f "${WORKSPACE}/id_rsa" -N "" -q
    chmod 600 "${WORKSPACE}/id_rsa"*
    test -f ~/.ssh/config && SSH_OPTIONS+=(-F /dev/null)
fi
eval "$(ssh-agent)"
ssh-add "${WORKSPACE}/id_rsa"

# Install missing packages on the host running this script
if ! type sshpass > /dev/null; then
    sudo apt-get update && sudo apt-get install -y sshpass
fi


if [[ "$ADMIN_IP" != "local" ]]; then
    sshpass -p "${ADMIN_PASSWORD}" ssh-copy-id "${SSH_OPTIONS[@]}" -o PreferredAuthentications=password "${ADMIN_USER}@${ADMIN_IP}"
fi

echo "Setting up ansible and required dependencies..."
installed_ansible_version="$(admin_node_command "dpkg-query -W -f='\${Version}\n' ansible" || echo "0.0")"
if ! admin_node_command type ansible > /dev/null || \
        dpkg --compare-versions "$installed_ansible_version" "lt" "$required_ansible_version"; then
    case $ADMIN_NODE_BASE_OS in
        ubuntu)
            with_retries admin_node_command -- sudo apt-get update
            with_retries admin_node_command -- sudo apt-get install -y software-properties-common
            with_retries admin_node_command -- sudo apt-add-repository -y ppa:ansible/ansible
            with_retries admin_node_command -- sudo apt-get update
        ;;
        debian)
            admin_node_command "sudo sh -c 'cat - > /etc/apt/sources.list.d/backports.list'" < "${BASH_SOURCE%/*}/files/debian_backports_repo.list"
            admin_node_command "sudo sh -c 'cat - > /etc/apt/preferences.d/backports'" < "${BASH_SOURCE%/*}/files/debian_pinning"
            with_retries admin_node_command sudo apt-get update
            with_retries admin_node_command sudo apt-get -y install --only-upgrade python-setuptools
        ;;
    esac
    admin_node_command sudo apt-get install -y ansible python-netaddr git
fi

echo "Checking out kargo playbook..."
admin_node_command git clone "$KARGO_REPO"
admin_node_command "sh -c 'cd kargo && git checkout $KARGO_COMMIT'"

echo "Setting up admin node for deployment..."
admin_node_command "cat > inventory.py" < "${BASH_SOURCE%/*}/../kargo/inventory.py"
admin_node_command CONFIG_FILE=kargo/inventory/inventory.cfg python3 inventory.py "${SLAVE_IPS[@]}"


admin_node_command "cat - > .ssh/id_rsa" < "${WORKSPACE}/id_rsa"
admin_node_command chmod 600 .ssh/id_rsa

echo "Uploading default settings..."
admin_node_command "cat > kargo/${COMMON_DEFAULTS_YAML}" < "$COMMON_DEFAULTS_SRC"
admin_node_command "cat > kargo/${OS_SPECIFIC_DEFAULTS_YAML}" < "$OS_SPECIFIC_DEFAULTS_SRC"

if [ -n "$CUSTOM_YAML" ]; then
    echo "Uploading custom YAML for deployment..."
    echo -e "$CUSTOM_YAML" | admin_node_command "cat > kargo/custom.yaml"
    CUSTOM_OPTS=(-e @~/kargo/custom.yaml)
fi

# TODO(mattymo): move to ansible
echo "Waiting for all nodes to be reachable by SSH..."
wait_for_nodes "${SLAVE_IPS[@]}"

CURRENT_SLAVE=1

echo "Adding ssh key authentication and labels to nodes..."
for SLAVE_IP in "${SLAVE_IPS[@]}"; do
    # FIXME(mattymo): Underlay provisioner should set up keys
    sshpass -p "${ADMIN_PASSWORD}" ssh-copy-id "${SSH_OPTIONS[@]}" -o PreferredAuthentications=password "${ADMIN_USER}@${SLAVE_IP}"

    # FIXME(mattymo): underlay should set hostnames
    ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo sed -i '\$a ${SLAVE_IP}\tnode${CURRENT_SLAVE}' /etc/hosts" # shellcheck disable=SC2026
    ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo hostnamectl set-hostname node${CURRENT_SLAVE}" # shellcheck disable=SC2026

    # TODO(mattymo): Move to kargo
    # Workaround to disable ipv6 dns which can cause docker pull to fail
    echo "precedence ::ffff:0:0/96  100" | ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo sh -c 'cat - >> /etc/gai.conf'"

    # Workaround to fix DNS search domain: https://github.com/kubespray/kargo/issues/322
    # Retry in case of apt lock
    with_retries ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y resolvconf"

    # If resolvconf was installed, copy its conf to fix dangling symlink
    ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo cp --remove-destination \`realpath /etc/resolv.conf\` /etc/resolv.conf" || :
    ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo rm -rf /etc/resolvconf"

    # Add VM label:
    ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "echo $VM_LABEL > /home/${ADMIN_USER}/vm_label" # shellcheck disable=SC2026

    # Install Debian (Ubuntu) packges which are needed for deployment or health check scripts
    if [[ "${SLAVE_IP}" == "${ADMIN_IP}" && "${ADMIN_NODE_BASE_OS}" =~ ^(ubuntu|debian)$ ]] || \
       [[ "${SLAVE_IP}" != "${ADMIN_IP}" && "${NODE_BASE_OS}" =~ ^(ubuntu|debian)$ ]]; then
        if [ -f "${BASH_SOURCE%/*}/../packer/scripts/debian/packages.sh" ]; then
            echo "Installing required Debian (Ubuntu) packages..."
            scp "${SSH_OPTIONS[@]}" "${BASH_SOURCE%/*}/../packer/scripts/debian/packages.sh" "${ADMIN_USER}@${SLAVE_IP}:/tmp/packages.sh"
            ssh "${SSH_OPTIONS[@]}" "${ADMIN_USER}@${SLAVE_IP}" "sudo bash /tmp/packages.sh &> /tmp/pkgs_install.log && rm -f /tmp/packages.sh"
        else
            echo 'WARNING! Script for installing Debian packages not found!'
        fi
    fi

    ((CURRENT_SLAVE++))
done

# Stop trapping pre-setup tasks
set +e

echo "Deploying k8s via ansible..."
tries=3
until admin_node_command /usr/bin/ansible-playbook \
    --ssh-extra-args "-o\ StrictHostKeyChecking=no" -u "${ADMIN_USER}" -b \
    --become-user=root -i "/home/${ADMIN_USER}/kargo/inventory/inventory.cfg" \
    "/home/${ADMIN_USER}/kargo/cluster.yml" "${COMMON_DEFAULTS_OPT[@]}" \
    "${OS_SPECIFIC_DEFAULTS_OPT[@]}" "${CUSTOM_OPTS[@]}"; do
        if [[ $tries -gt 0 ]]; then
            (( tries-- ))
            echo "Deployment failed! Trying $tries more times..."
        else
            exit_gracefully 1
        fi
done
deploy_res=0

echo "Initial deploy succeeded. Proceeding with post-install tasks..."

# NOTE: This needs to run on a node with kube-config.yml and kubelet (kube-master role)
echo "Setting up kubedns..."
admin_node_command "sudo pip install kpm"
admin_node_command "sudo /usr/local/bin/kpm deploy kube-system/kubedns --namespace=kube-system"

tries=26
for waiting in $(seq 1 $tries); do
    if admin_node_command "kubectl get po --namespace=kube-system" | grep kubedns | grep -q Running; then
        admin_node_command "host kubernetes" && break
    fi
    if [ "$waiting" -lt "$tries" ]; then
        echo "Waiting for kubedns to be up..."
        sleep 5
    else
        echo "Kubedns did not come up in time"
        deploy_res=1
    fi
done

if [ "$deploy_res" -eq "0" ]; then
    echo "Testing network connectivity..."
    . "${BASH_SOURCE%/*}/../kargo/test_networking.sh"
    test_networking
    deploy_res=$?
    if [ "$deploy_res" -eq "0" ]; then
        echo "Copying connectivity script to node..."
        scp "${SSH_OPTIONS[@]}" "${BASH_SOURCE%/*}/../kargo/test_networking.sh" "${ADMIN_USER}@${ADMIN_IP}:test_networking.sh"
    fi
fi

if [ "$deploy_res" -eq "0" ]; then
    echo "Enabling dashboard UI..."
    admin_node_command "kubectl create -f -" < "${BASH_SOURCE%/*}/../kargo/kubernetes-dashboard.yaml"
    deploy_res=$?
    if [ "$deploy_res" -ne "0" ]; then
        echo "Unable to create dashboard UI!"
    fi
fi

# setup VLAN if everything is ok and env will not be deleted
if [ "$VLAN_BRIDGE" ] && [ "${deploy_res}" -eq "0" ] && [ "${DONT_DESTROY_ON_SUCCESS}" = "1" ];then
    rm -f VLAN_IPS
    for IP in "${SLAVE_IPS[@]}"; do
        bridged_iface_mac="$(ENV_NAME=${ENV_NAME} python "${BASH_SOURCE%/*}/env.py" get_bridged_iface_mac "$IP")"
        # the variable $bridged_iface_mac should be expanded on the client side
        # shellcheck disable=SC2087
        admin_node_command bash -s << EOF >> VLAN_IPS
bridged_iface=\$(ip -o l | awk -v mac="$bridged_iface_mac" -F': ' '/mac/{print $2}')
sudo ip route del default
sudo dhclient "\${bridged_iface}"
ip -o -4 addr show dev "\${bridged_iface}" | sed -rn 's/.*inet\s+(\S+)\/.*/\1/p'
EOF

    done
set +x
    sed -i '/^\s*$/d' VLAN_IPS
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
    echo "* VLANs IP addresses"
    echo "* MASTER IP: $(head -n1 VLAN_IPS)"
    echo "* SLAVES IPS: $(tail -n +2 VLAN_IPS | tr '\n' ' ')"
    echo "* USERNAME: $ADMIN_USER"
    echo "* PASSWORD: $ADMIN_PASSWORD"
    echo "* K8s dashboard: https://kube:changeme@$(head -n1 VLAN_IPS)/ui/"
    echo "**************************************"
    echo "**************************************"
    echo "**************************************"
set -x
fi


exit_gracefully ${deploy_res}
