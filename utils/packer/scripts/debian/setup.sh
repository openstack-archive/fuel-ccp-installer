#!/bin/bash -eux

echo "==> Setting up sudo"
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

echo "==> Configuring logging"
touch /var/log/daemon.log
chmod 666 /var/log/daemon.log
echo "daemon.* /var/log/daemon.log" >> /etc/rsyslog.d/50-default.conf

echo "==> Setting vim as a default editor"
update-alternatives --set editor /usr/bin/vim.basic

echo "==> Setting default locale to en_US.UTF-8"
echo "LC_ALL=en_US.UTF-8" >> /etc/environment
