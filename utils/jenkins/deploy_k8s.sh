#!/bin/bash
set -xe

export DONT_DESTROY_ON_SUCCESS=1
export SLAVES_COUNT=3
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python mcpinstall.py deploy"
DEPLOY_METHOD="${DEPLOY_METHOD:-kargo}"

if [[ "$DEPLOY_METHOD" == "kargo" ]]; then
    "${BASH_SOURCE%/*}/kargo_deploy.sh"
else
    echo "Deploy method ${DEPLOY_METHOD} is not implemented!"
    exit 1
fi
