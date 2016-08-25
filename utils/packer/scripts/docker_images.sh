#!/bin/bash -eux

[ "${PULL_IMAGES}" = "true" ] || exit 0
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
