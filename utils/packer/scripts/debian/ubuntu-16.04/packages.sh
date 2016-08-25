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

[ "${PULL_IMAGES}" = "true" ] || exit 0
# Preinstall Docker version required by Kargo:
KARGO_DEFAULT_UBUNTU_URL="https://raw.githubusercontent.com/openstack/fuel-ccp-installer/master/utils/kargo/kargo_default_ubuntu.yaml"
DOCKER_REQUIRED_VERSION=`wget --output-document=- ${KARGO_DEFAULT_UBUNTU_URL}\
| awk '/docker_version/ {gsub(/"/, "", $NF); print $NF}'`
apt-get -y install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 \
--recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" \
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

# Pull K8s hyperkube image version required by Kargo:
KARGO_DEFAULT_COMMON_URL="https://raw.githubusercontent.com/openstack/fuel-ccp-installer/master/utils/kargo/kargo_default_common.yaml"
TMP_FILE=output_${RANDOM}.yaml
wget --output-document ${TMP_FILE} ${KARGO_DEFAULT_COMMON_URL}
HYPERKUBE_IMAGE_NAME=`awk '/hyperkube_image_repo/ {gsub(/"/, "", $NF); \
print $NF}' ${TMP_FILE}`
HYPERKUBE_IMAGE_TAG=`awk '/hyperkube_image_tag/ {gsub(/"/, "", $NF); \
print $NF}' ${TMP_FILE}`
docker pull ${HYPERKUBE_IMAGE_NAME}:${HYPERKUBE_IMAGE_TAG}

# Pull K8s calico images version required by Kargo:
CALICO_IMAGE_TAG=`awk '/calico_version/ {gsub(/"/, "", $NF); \
print $NF}' ${TMP_FILE}`
docker pull calico/ctl:${CALICO_IMAGE_TAG}
docker pull calico/node:${CALICO_IMAGE_TAG}

# Pull K8s etcd image version required by Kargo:
ETCD_IMAGE_TAG=`awk '/etcd_version/ {gsub(/"/, "", $NF); \
print $NF}' ${TMP_FILE}`
docker pull quay.io/coreos/etcd:${ETCD_IMAGE_TAG}

# Pull required images w/o version preferences:
docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.1.0
rm ${TMP_FILE}
