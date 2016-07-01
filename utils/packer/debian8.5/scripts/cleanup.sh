#!/bin/bash -eux

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
