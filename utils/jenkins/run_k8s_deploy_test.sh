#!/bin/bash
set -xe

export SLAVES_COUNT=3
export DEPLOY_TIMEOUT=1200
export TEST_SCRIPT="/usr/bin/python mcpinstall.py deploy --dns --dashboard"

./utils/jenkins/run.sh
