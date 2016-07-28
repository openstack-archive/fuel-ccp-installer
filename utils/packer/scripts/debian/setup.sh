#!/bin/bash -eux

echo "==> Configuring serial console"
cat >> /etc/default/grub <<EOF
GRUB_TERMINAL=serial
GRUB_CMDLINE_LINUX='console=tty0 console=ttyS0,19200n8 cgroup_enable=memory swapaccount=1'
GRUB_SERIAL_COMMAND="serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1"
EOF

echo "==> Setting up sudo"
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

echo "==> Configuring logging"
touch /var/log/daemon.log
chmod 666 /var/log/daemon.log
echo "daemon.* /var/log/daemon.log" >> /etc/rsyslog.d/50-default.conf

echo "==> Setting vim as a default editor"
update-alternatives --set editor /usr/bin/vim.basic
