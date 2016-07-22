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
tmux
python-dev
gcc
libssl-dev
libffi-dev
software-properties-common
ansible
"
#PACKAGES="${PACKAGES} docker-engine"
apt-get -y install $PACKAGES

#Installer/CCP tools
pip install git+https://git.openstack.org/openstack/fuel-ccp.git --upgrade
