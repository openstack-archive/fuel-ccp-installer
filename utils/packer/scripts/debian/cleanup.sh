#!/bin/bash -euxo

# Clean up the apt cache
apt-get -y autoremove --purge
apt-get -y autoclean

echo "==> Cleaning up udev rules"
rm -rf /dev/.udev/ /lib/udev/rules.d/75-persistent-net-generator.rules

echo "==> Cleaning up leftover dhcp leases"
if [ -d "/var/lib/dhcp" ]; then
  rm /var/lib/dhcp/*
fi

if [ "${CLEANUP}" = "true" ] ; then
  echo "==> Removing man pages"
  rm -rf /usr/share/man/*
  echo "==> Removing anything in /usr/src"
  rm -rf /usr/src/*
  echo "==> Removing any docs"
  rm -rf /usr/share/doc/*
fi
echo "==> Removing caches"
find /var/cache -type f -exec rm -rf {} \;
echo "==> Cleaning up log files"
find /var/log -type f -exec sh -c 'echo -n > {}' \;
echo "==> Cleaning up tmp"
rm -rf /tmp/*
echo "==> Clearing last login information"
> /var/log/lastlog
> /var/log/wtmp
> /var/log/btmp

echo "==> Removing bash history"
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/vagrant/.bash_history
