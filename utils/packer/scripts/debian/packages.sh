#!/bin/bash -eux
apt-get -y update
apt-get -y dist-upgrade

PACKAGES="
ansible
bind9-host
curl
dnsutils
ethtool
gcc
git-review
htop
isc-dhcp-client
libffi-dev
libssl-dev
nfs-common
python-dev
python-setuptools
python-tox
screen
software-properties-common
sshpass
tmux
vim
"

echo "==> Installing packages"
apt-get -y install $PACKAGES

# Install pip
curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
python /tmp/get-pip.py
rm /tmp/get-pip.py
pip install --upgrade pip
