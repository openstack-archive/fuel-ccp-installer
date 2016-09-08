#!/bin/bash -eux
dmidecode -s processor-manufacturer | grep -q QEMU || exit 0
apt-get update
systemctl disable docker
systemctl stop docker
apt-get -y install --reinstall linux-image-extra-$(uname -r) \
  linux-image-extra-virtual
systemctl start docker
systemctl enable docker
apt-get -y install --reinstall docker-engine
