#!/bin/bash -eux
apt-get -y update
apt-get -y dist-upgrade

PACKAGES="
curl
ethtool
htop
isc-dhcp-client
nfs-common
vim
git-review
python-tox
screen
sshpass
tmux
python-dev
python-netaddr
software-properties-common
python-setuptools
"

echo "==> Installing packages"
apt-get -y install $PACKAGES

# Install pip
curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
python /tmp/get-pip.py
rm /tmp/get-pip.py
pip install --upgrade pip

# Preinstall Docker version required by Kargo:
KARGO_DEFAULTS_MAIN_URL="https://raw.githubusercontent.com/kubespray/kargo/652cbedee5c29cdcf760737a9c08836729bd3630/roles/docker/defaults/main.yml"
DOCKER_REQUIRED_VERSION=`wget --output-document=- ${KARGO_DEFAULTS_MAIN_URL}\
| grep docker_version | sed -e 's/docker_version: //'`
apt-get install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80\
--recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main"\
> /etc/apt/sources.list.d/docker.list
apt-get update
apt-get purge lxc-docker
DOCKER_APT_PACKAGE=`apt-cache policy docker-engine\
| grep ${DOCKER_REQUIRED_VERSION} | head -1\
| grep -o "${DOCKER_REQUIRED_VERSION}.*\ "`
apt-get install docker-engine=${DOCKER_APT_PACKAGE}

# Pull K8s hyperkube image version required by Kargo:
KARGO_KUBE_VERSION_URL="https://raw.githubusercontent.com/kubespray/kargo/66da43bbbc37d7080db3381be33a6a6251196a45/roles/download/vars/kube_versions.yml"
HYPERKUBE_REQUIRED_VERSION=`wget --output-document=- ${KARGO_KUBE_VERSION_URL}\
| grep kube_version | sed -e 's/kube_version: //'`
HYPERKUBE_IMAGE_NAME="quay.io/coreos/hyperkube:"${HYPERKUBE_REQUIRED_VERSION}"_coreos.0"
docker pull ${HYPERKUBE_IMAGE_NAME}
