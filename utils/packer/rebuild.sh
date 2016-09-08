#!/bin/bash -eux
apt-get update
apt-get -y install --reinstall linux-image-extra-$(uname -r) \
  linux-image-extra-virtual docker-engine
