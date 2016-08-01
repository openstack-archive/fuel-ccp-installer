#!/bin/bash -eux

# Use only http://httpredir.debian.org/ over cdn.debian.net or fixed mirrors
cat > /tmp/sources.list << EOF
deb http://httpredir.debian.org/debian jessie main
deb http://httpredir.debian.org/debian jessie-updates main
deb http://security.debian.org jessie/updates main
EOF
mv -f /tmp/sources.list /etc/apt/sources.list

if [[ $UPDATE  =~ true || $UPDATE =~ 1 || $UPDATE =~ yes ]]; then
  	echo "==> Updating list of repositories"
    # apt-get update does not actually perform updates, it just downloads and indexes the list of packages
    apt-get -y update

    echo "==> Performing dist-upgrade (all packages and kernel)"
    apt-get -y dist-upgrade --force-yes
fi
