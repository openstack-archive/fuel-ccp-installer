#!/bin/bash
# Configure hosts entries in the /etc/hosts
echo "127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
" >/tmp/hosts
while (( "$#" )); do
  echo "${1}" >> /tmp/hosts
  shift
done
echo "Overwriting hosts"
cp -f /tmp/hosts /etc/hosts
exit 0
