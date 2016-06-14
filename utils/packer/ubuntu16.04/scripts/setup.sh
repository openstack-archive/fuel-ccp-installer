#!/bin/sh

# Set up sudo
echo 'vagrant ALL=NOPASSWD:ALL' > /etc/sudoers.d/vagrant
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# Set vim as a default editor
update-alternatives --set editor /usr/bin/vim.basic
