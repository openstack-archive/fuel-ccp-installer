apt-get -y update
apt-get -y dist-upgrade

PACKAGES="
curl
htop
isc-dhcp-client
nfs-common
"
apt-get -y install $PACKAGES
