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
tox
screen
tmux
"
apt-get -y install $PACKAGES
