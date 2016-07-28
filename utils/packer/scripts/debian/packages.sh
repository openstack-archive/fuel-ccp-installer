#!/bin/bash -eux
#FIXME(bogdando) switch to jessie-backports
cat > /etc/apt/preferences.d/testing << EOF
Package: ansible
Pin: release a=testing
Pin-Priority: 1001

Package: python-setuptools
Pin: release a=testing
Pin-Priority: 1001

Package: python-pkg-resources
Pin: release a=testing
Pin-Priority: 1001

Package: *
Pin: release a=testing
Pin-Priority: 100
EOF

cat > /etc/apt/sources.list.d/testing.list << EOF
deb http://http.us.debian.org/debian testing main
deb-src http://http.us.debian.org/debian testing main
EOF

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
python-setuptools
"

echo "==> Installing packages"
apt-get -y --allow-unauthenticated install $PACKAGES

# Upgrading pip
pip install --upgrade pip

#Installer/CCP tools
pip install git+https://git.openstack.org/openstack/fuel-ccp.git --upgrade
