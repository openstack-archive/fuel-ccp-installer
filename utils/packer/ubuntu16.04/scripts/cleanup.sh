#!/bin/bash -eux

# see https://github.com/geerlingguy/packer-ubuntu-1604/issues/1
echo 'GRUB_CMDLINE_LINUX="biosdevname=0 net.ifnames=0"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

sed '/ens/d' -i /etc/network/interfaces

echo 'auto eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces

apt-get -y autoremove --purge
find /var/cache -type f -exec rm -rf {} \;
find /var/lib/apt -type f | xargs rm -f

rm -rf /dev/.udev/
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules
mkdir -p /etc/udev/rules.d/70-persistent-net.rules

if [ -d "/var/lib/dhcp" ]; then
    rm -f /var/lib/dhcp/*
fi

rm -rf /tmp/*

unset HISTFILE
rm -f /root/.bash_history
rm -f /home/vagrant/.bash_history

find /var/log -type f | while read f; do echo -ne '' > $f; done;

>/var/log/lastlog
>/var/log/wtmp
>/var/log/btmp

sync
