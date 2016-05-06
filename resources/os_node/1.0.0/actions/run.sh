os=`lsb_release -si`

if [[ ! "$os" == "Ubuntu" ]]
then
   sudo dnf install -y python python-dnf ansible libselinux-python
   sudo /usr/sbin/setenforce 0 || echo 'ok'
   sudo systemctl stop firewalld.service || echo 'ok'
else if [[ "$os" == "Ubuntu" ]]
     then
         sudo apt-get install -y python ansible
     fi
fi
