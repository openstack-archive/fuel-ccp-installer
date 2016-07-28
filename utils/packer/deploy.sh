#!/bin/bash -x

USER=${ATLAS_USER:-mirantis}
DEBIAN_MAJOR_VERSION=${DEBIAN_MAJOR_VERSION:-8}
DEBIAN_MINOR_VERSION=${DEBIAN_MINOR_VERSION:-5}
ARCH=${ARCH:-amd64}
TYPE=${TYPE:-libvirt}
NAME="debian-${DEBIAN_MAJOR_VERSION}.${DEBIAN_MINOR_VERSION}.0-${ARCH}"

create_atlas_box() {
  if curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} | grep -q "Resource not found"; then
    #Create box, because it doesn't exists
    echo "*** Creating box: ${NAME}, Short Description: ${SHORT_DESCRIPTION}"
    curl -s https://atlas.hashicorp.com/api/v1/boxes -X POST -d box[name]="${NAME}" -d box[short_description]="${SHORT_DESCRIPTION}" -d box[is_private]=false -d access_token="${ATLAS_TOKEN}"
  fi
}

remove_atlas_box() {
  echo "*** Removing box: ${USER}/${NAME}"
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} -X DELETE -d access_token="${ATLAS_TOKEN}"
}

remove_atlas_box_version() {
  echo "*** Removing previous version: https://atlas.hashicorp.com/api/v1/box/$USER/$NAME/version/$1"
  curl -s https://atlas.hashicorp.com/api/v1/box/$USER/$NAME/version/$1 -X DELETE -d access_token="$ATLAS_TOKEN" > /dev/null
}

upload_boxfile_to_atlas() {
  echo "*** Getting current version of the box (if exists)"
  local CURRENT_VERSION=$(curl -sS -L https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME} -X GET -d access_token="${ATLAS_TOKEN}" | jq 'if .current_version.version == null then "0" else .current_version.version end | tonumber')
  local VERSION=$(echo "${CURRENT_VERSION} + 0.1" | bc | sed 's/^\./0./')
  echo "*** Uploading a version: ${VERSION}"
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/versions -X POST -d version[version]="${VERSION}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VERSION} -X PUT -d version[description]="${DESCRIPTION}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VERSION}/providers -X POST -d provider[name]="${TYPE}" -d access_token="${ATLAS_TOKEN}" > /dev/null
  UPLOAD_PATH=$(curl -sS https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VERSION}/provider/${TYPE}/upload?access_token=${ATLAS_TOKEN} | jq -r '.upload_path')
  echo "*** Uploding \"${NAME}-${TYPE}.box\" to ${UPLOAD_PATH}"
  curl -sSL -X PUT --upload-file ${NAME}-${TYPE}.box ${UPLOAD_PATH}
  curl -sSL https://atlas.hashicorp.com/api/v1/box/${USER}/${NAME}/version/${VERSION}/release -X PUT -d access_token="${ATLAS_TOKEN}" > /dev/null
}

export DESCRIPTION=$(cat ../../doc/PACKER.md)
export SHORT_DESCRIPTION="${NAME} for ${TYPE}"
create_atlas_box
upload_boxfile_to_atlas

#remove_atlas_box
