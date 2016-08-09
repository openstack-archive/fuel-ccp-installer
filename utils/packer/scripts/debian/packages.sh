#!/bin/bash -eux
apt-get -y update
apt-get -y dist-upgrade

PACKAGES="
curl
ethtool
htop
isc-dhcp-client
nfs-common
vim
python-pip
git-review
python-tox
screen
sshpass
tmux
python-dev
gcc
libssl-dev
libffi-dev
software-properties-common
ansible
python-setuptools
"

echo "==> Installing packages"
apt-get -y install $PACKAGES

# Upgrading pip
pip install --upgrade pip
