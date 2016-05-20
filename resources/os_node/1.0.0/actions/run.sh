set -xe

os=`lsb_release -si`

if [[ ! "$os" == "Ubuntu" ]]; then
    sudo dnf install -y python python-dnf ansible libselinux-python
    sudo /usr/sbin/setenforce 0 || echo 'ok'
    sudo systemctl stop firewalld.service || echo 'ok'
    sudo hostnamectl set-hostname --static "{{name}}"
else
    if [[ "$os" == "Ubuntu" ]]; then
        sudo apt-get install -y python ansible
        sudo hostname {{name}}
        sudo bash -c  "echo {{name}} > /etc/hostname"
    fi
fi
