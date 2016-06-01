#!/bin/bash
set -xe

export SLAVES_COUNT=3
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python mcpinstall.py deploy --dns --dashboard"

if [[ "$DEPLOY_METHOD" == "kargo" ]]; then
    ./utils/jenkins/kargo_deploy.sh
else
    ./utils/jenkins/run.sh
fi
