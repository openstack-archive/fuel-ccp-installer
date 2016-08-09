#!/bin/bash -eux

echo "==> Configuring serial console"
cat >> /etc/default/grub <<EOF
GRUB_TERMINAL=serial
GRUB_CMDLINE_LINUX='0 console=ttyS0,19200n8 cgroup_enable=memory swapaccount=1 net.ifnames=0 biosdevname=0'
GRUB_SERIAL_COMMAND="serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1"
EOF

update-grub2
