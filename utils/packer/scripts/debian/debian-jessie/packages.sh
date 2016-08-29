#!/bin/bash -eux

apt-get update
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
apt-get -y purge "lxc-docker*"
apt-get -y purge "docker.io*"
KARGO_DEFAULT_DEBIAN_URL="https://raw.githubusercontent.com/openstack/fuel-ccp-installer/master/utils/kargo/kargo_default_debian.yaml"
DOCKER_REQUIRED_VERSION=`wget --output-document=- ${KARGO_DEFAULT_DEBIAN_URL}\
| awk '/docker_version/ {gsub(/"/, "", $NF); print $NF}'`
apt-get -y install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 \
--recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" \
> /etc/apt/sources.list.d/docker.list
apt-get update
DOCKER_APT_PACKAGE_VERSION=`apt-cache policy docker-engine \
| grep ${DOCKER_REQUIRED_VERSION} | head -1 \
| grep -o "${DOCKER_REQUIRED_VERSION}.*\ "`
DOCKER_APT_PACKAGE_FULL_NAME="docker-engine"
# FIXME(mzawadzki): this is workaround for non-maching Docker version
[ ! -z ${DOCKER_APT_PACKAGE_VERSION} ] \
&& DOCKER_APT_PACKAGE_FULL_NAME+="="${DOCKER_APT_PACKAGE_VERSION}
apt-get -y install ${DOCKER_APT_PACKAGE_FULL_NAME}
