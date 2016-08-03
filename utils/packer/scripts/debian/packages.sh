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
python-pip
python-setuptools
python-tox
screen
software-properties-common
sshpass
tmux
vim
"

echo "==> Installing packages"
apt-get -y --allow-unauthenticated install $PACKAGES

# Upgrading pip
pip install --upgrade pip

#Installer/CCP tools
pip install git+https://git.openstack.org/openstack/fuel-ccp.git --upgrade
