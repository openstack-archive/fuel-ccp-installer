#!/bin/bash -eux

### Install packages
echo "==> Installing cloud-init"
apt-get install -y cloud-init cloud-guest-utils cloud-initramfs-growroot cloud-initramfs-copymods
