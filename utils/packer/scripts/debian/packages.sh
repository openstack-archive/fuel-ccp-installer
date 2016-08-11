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
git-review
python-tox
screen
sshpass
tmux
python-dev
python-netaddr
gcc
libssl-dev
libffi-dev
software-properties-common
python-setuptools
"

echo "==> Installing packages"
apt-get -y install $PACKAGES

# Install pip
curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
python /tmp/get-pip.py
rm /tmp/get-pip.py
pip install --upgrade pip

# Install ansible
# Retry because launchpad errors sometimes
until apt-add-repository -y ppa:ansible/ansible; do sleep 1; done
apt-get -y install ansible

