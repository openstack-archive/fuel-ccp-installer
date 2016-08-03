#!/bin/bash
set -xe

export SLAVES_COUNT=${SLAVES_COUNT:-3}
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python mcpinstall.py deploy --dns --dashboard"
export BUILD_TAG="${BUILD_TAG:-unknown}"
DEPLOY_METHOD="${DEPLOY_METHOD:-kargo}"

if [[ "$DEPLOY_METHOD" == "kargo" ]]; then
    ./utils/jenkins/kargo_deploy.sh
else
    echo "Deploy method ${DEPLOY_METHOD} is not implemented!"
    exit 1
fi
