#!/bin/bash -eux
# Use only http://httpredir.debian.org/ over cdn.debian.net or fixed mirrors
cat > /etc/apt/sources.list << EOF
deb http://httpredir.debian.org/debian jessie main
deb http://httpredir.debian.org/debian jessie-updates main
deb http://httpredir.debian.org/debian jessie-backports main
deb http://security.debian.org jessie/updates main
EOF
