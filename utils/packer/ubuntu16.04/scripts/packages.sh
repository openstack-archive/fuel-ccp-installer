# add Docker repo:
#apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#cat > /etc/apt/sources.list.d/docker.list <<EOF
#deb https://apt.dockerproject.org/repo ubuntu-trusty main
#deb https://apt.dockerproject.org/repo ubuntu-xenial main
#EOF

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
