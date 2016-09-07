#!/bin/bash
set -xe

export SLAVES_COUNT=${SLAVES_COUNT:-3}
export DEPLOY_TIMEOUT=1200
export BUILD_TAG=${BUILD_TAG:-unknown}

./utils/jenkins/kargo_deploy.sh

# Archive logs if they were generated
mkdir "${WORKSPACE}/_artifacts"
if [ -f "${WORKSPACE}/logs.tar.gz" ]; then
    mv "${WORKSPACE}/logs.tar.gz" "${WORKSPACE}/_artifacts"
fi
