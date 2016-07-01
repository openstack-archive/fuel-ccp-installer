#!/bin/bash -eux
apt-get -y update
apt-get -y dist-upgrade

PACKAGES="
curl
htop
isc-dhcp-client
nfs-common
vim
python-pip
git-review
python-tox
screen
tmux
"
#PACKAGES="${PACKAGES} docker-engine"
apt-get -y install $PACKAGES
