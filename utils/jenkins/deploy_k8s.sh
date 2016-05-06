#!/bin/bash
set -xe

export DONT_DESTROY_ON_SUCCESS=1
export SLAVES_COUNT=3
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python mcpinstall.py deploy"

./utils/jenkins/run.sh
