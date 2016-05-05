os = $("lsb_release -si")

if [[ "$os" == "Fedora" ]]
then
   sudo dnf install -y python python-dnf ansible libselinux-python
   sudo /usr/sbin/setenforce 0
else if [[ "$os" == "Ubuntu" ]]
     then
         sudo apt-get install -y python ansible
     fi
fi
