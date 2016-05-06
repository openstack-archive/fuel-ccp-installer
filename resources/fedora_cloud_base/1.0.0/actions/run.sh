sudo dnf install -y python python-dnf ansible libselinux-python
sudo /usr/sbin/setenforce 0 || echo 'ok'
sudo systemctl stop firewalld.service || echo 'ok'
