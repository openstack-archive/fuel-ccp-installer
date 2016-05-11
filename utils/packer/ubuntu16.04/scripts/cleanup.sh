#!/bin/bash -eux

# see https://github.com/geerlingguy/packer-ubuntu-1604/issues/1
echo 'GRUB_CMDLINE_LINUX="biosdevname=0 net.ifnames=0"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

sed '/ens/d' -i /etc/network/interfaces

echo 'auto eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces

# Apt cleanup.
apt autoremove
apt update
