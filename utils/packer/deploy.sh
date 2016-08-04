#!/bin/bash -x
# VERSION=0.1.0 DEBIAN_MAJOR_VERSION=8 DEBIAN_MINOR_VERSION=5 ARCH=amd64 OSTYPE=debian TYPE=libvirt ATLAS_USER=john NAME=foobox ./deploy.sh
# UBUNTU_MAJOR_VERSION=16.04 UBUNTU_MINOR_VERSION=.1 UBUNTU_TYPE=server ARCH=amd64 OSTYPE=ubuntu TYPE=virtualbox ATLAS_USER=doe ./deploy.sh

USER=${ATLAS_USER:-mirantis}
DEBIAN_MAJOR_VERSION=${DEBIAN_MAJOR_VERSION:-8}
DEBIAN_MINOR_VERSION=${DEBIAN_MINOR_VERSION:-5}
UBUNTU_MAJOR_VERSION=${UBUNTU_MAJOR_VERSION:-16.04}
UBUNTU_MINOR_VERSION=${UBUNTU_MINOR_VERSION:-.1}
UBUNTU_TYPE=${UBUNTU_TYPE:-server}
ARCH=${ARCH:-amd64}
TYPE=${TYPE:-libvirt}
VERSION=${VERSION:-0.0.0}
case ${OSTYPE} in
  ubuntu) NAME="ubuntu-${UBUNTU_MAJOR_VERSION}${UBUNTU_MINOR_VERSION}-${UBUNTU_TYPE}-${ARCH}" ;;
  debian) NAME="debian-${DEBIAN_MAJOR_VERSION}.${DEBIAN_MINOR_VERSION}.0-${ARCH}" ;;
  *) echo "Unsupported OSTYPE" >&2; exit 1;;
esac
BOXNAME="${BOXNAME:-${NAME}-${TYPE}.box}"

create_atlas_box() {
  if curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} | grep -q "Resource not found"; then
    #Create box, because it doesn't exists
    echo "*** Creating box: ${NAME}, Short Description: ${SHORT_DESCRIPTION}"
    set +x
    curl -s https://atlas.hashicorp.com/api/v1/boxes -X POST -d box[name]="${NAME}" -d box[short_description]="${SHORT_DESCRIPTION}" -d box[is_private]=false -d access_token="${ATLAS_TOKEN}"
    set -x
  fi
}

remove_atlas_box() {
  echo "*** Removing box: ${USER}/${NAME}"
  set +x
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} -X DELETE -d access_token="${ATLAS_TOKEN}"
  set -x
}

remove_atlas_box_version() {
  echo "*** Removing previous version: https://atlas.hashicorp.com/api/v1/box/$USER/$NAME/version/$1"
  set +x
  curl -s https://atlas.hashicorp.com/api/v1/box/$USER/$NAME/version/$1 -X DELETE -d access_token="$ATLAS_TOKEN" > /dev/null
  set -x
}

upload_boxfile_to_atlas() {
  echo "*** Getting current version of the box (if exists)"
  local VER
  set +x
  local CURRENT_VERSION=$(curl -sS -L https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} -X GET -d access_token="${ATLAS_TOKEN}" | jq 'if .current_version.version == null then "0" else .current_version.version end | tonumber')
  set -x
  if [ "${VERSION}" == "0.0.0" ]; then
    VER=$(echo "${CURRENT_VERSION} + 0.1" | bc | sed 's/^\./0./')
  else
    VER=${VERSION}
  fi
  echo "*** Uploading a version: ${VER}"
  set +x
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/versions -X POST -d version[version]="${VER}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VER} -X PUT -d version[description]="${DESCRIPTION}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VER}/providers -X POST -d provider[name]="${TYPE}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  UPLOAD_PATH=$(curl -sS https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VER}/provider/${TYPE}/upload?access_token=${ATLAS_TOKEN} | jq -r '.upload_path')
  set -x
  echo "*** Uploading \"${BOXNAME}\" to ${UPLOAD_PATH}"
  curl -sSL -X PUT --upload-file ${BOXNAME} ${UPLOAD_PATH}
  set +x
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VERSION}/release -X PUT -d access_token="${ATLAS_TOKEN}" > /dev/null
  set -x
}

export DESCRIPTION=$(cat ../../doc/source/packer.rst)
export SHORT_DESCRIPTION="${NAME} for ${TYPE}"
create_atlas_box
upload_boxfile_to_atlas
#remove_atlas_box
