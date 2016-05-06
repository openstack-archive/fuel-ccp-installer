#!/bin/bash
set -xe

export SLAVES_COUNT=3
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python setup_k8s.py deploy"

./utils/jenkins/run.sh
