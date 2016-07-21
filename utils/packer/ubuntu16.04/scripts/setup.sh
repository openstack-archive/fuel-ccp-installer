#!/bin/sh

# configure serial console:
cat >> /etc/default/grub <<EOF
GRUB_TERMINAL=serial
GRUB_CMDLINE_LINUX='console=tty0 console=ttyS0,19200n8'
GRUB_SERIAL_COMMAND="serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1"
EOF

# Set up sudo
echo 'vagrant ALL=NOPASSWD:ALL' > /etc/sudoers.d/vagrant
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# Setup key-based authentication between VMs:
mkdir /home/vagrant/.ssh
cat > /home/vagrant/.ssh/id_rsa_vagrant.pub <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCy1JMEoVy4XyLVBpHcMG+2u1yfs1SKl8u9VKsnmfBRp+0zAT3fd+Y/p8oRnw7cmqNJtREXf4RrS2uqY2+kUww7x92dbF48+5OrGIh16x1pDXgJMmOQyQdIHz+s8847U/uF9v0aT5Do90MVVLfPk4gsJEWSqINJZduQpW2kLY+9kD5xsXZQlCCmWOyMEYl9RJC02TU06xKVIyzT6iSpC6+UwFEKkaLAeMGtc7Qgcvv3r7oXJ7tWm9nURx1Is/trihuPQUX15czBkfzlGz2Uj4G5ff/oJCLO0Uwbojr1NQDOJywr4/KH3ZJHS+63/O9fAXfbryA1HgtTq412Eete4iTR vagrant@vm
EOF
cat /home/vagrant/.ssh/id_rsa_vagrant.pub >> /home/vagrant/.ssh/authorized_keys
cat > /home/vagrant/.ssh/id_rsa_vagrant <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAstSTBKFcuF8i1QaR3DBvtrtcn7NUipfLvVSrJ5nwUaftMwE9
33fmP6fKEZ8O3JqjSbURF3+Ea0trqmNvpFMMO8fdnWxePPuTqxiIdesdaQ14CTJj
kMkHSB8/rPPOO1P7hfb9Gk+Q6PdDFVS3z5OILCRFkqiDSWXbkKVtpC2PvZA+cbF2
UJQgpljsjBGJfUSQtNk1NOsSlSMs0+okqQuvlMBRCpGiwHjBrXO0IHL796+6Fye7
VpvZ1EcdSLP7a4obj0FF9eXMwZH85Rs9lI+BuX3/6CQiztFMG6I69TUAzicsK+Py
h92SR0vut/zvXwF3268gNR4LU6uNdhHrXuIk0QIDAQABAoIBAE/FRzd/i06rEWyZ
G6Nu78ZBWZXbdtDD2ZxBEn/9yReDoulnmmP+pfSrMhYeL5D0YfZVEKS8uyLpZ8N/
y6MvcHuSMicw2fC2AC8IKIcBNANSgMMJeSRyqA7h8ZOCxfHtCnu9qzV7XJavBXuU
aNHta4bVPzumc7nf98tUH85mjIHwARWcQt+9eqV11J2EUEAbmyFsBlEipMMenyMK
AZAcFryXgEX3PAVfQ2BE8eZL9HVaUSqjPBFd3VFWFrM4tgpBJgRd4OpME1vTin3x
V8ZfDnVwK5/FZYIq9Vt+JT/fx6/8QkrkLmQsRSXJEiV25puFP82ihkiHyLamfg90
qcuXRikCgYEA29NcL2mYetsJgfUf+3Yaoul8gnMg22Qis43yl5lKVQdQlhIHyjoE
i6wRajTPPwynFfLOaEkqpXeuU/0CldC13vQQIsbyDiiMyHSJpsMPhSe/tI4RPmAB
97j+3k2FHQINAgE8QF2L15z02WoTsITRVTHgv5unaqgs9dn0TU2fMmMCgYEA0EIy
zjJghifrV29oG60k0k5fhTF8H0l92mh6DxnULHezHbf4HPbLSIWKaVjSfktsV87p
r1hic65ow1RZlsH6yEiP/65oxm1irGoFHOyoGoN/wrWTIpNo5S+W8CgSdi4cNh5W
s17j2mritEpYvPLHWx7HP/q8GBxO5VG6X3z62DsCgYAsczy8yZlvnkL56FsjOeqA
7r2iky0dr83kiNt5FCIXt3bwIY05symgJJcQ5sTRdvmCUqqyI7lf5Cd4DD0tlhpw
juGEZr4jZsew8P+0nNTSlAsLs36BImDDesDuqrYz+2ot8ZoBWekhHDfWjsCUfQbn
N0K++/aKdp9Ax2XDC+MZCQKBgA98/N5M7NTNXzlPdcSpKdXiMkRrm7mP86YsovdA
ioEMHewV5IPy7sdj9xlCm9T8swAMyWBbCGdmDzCHs2n83zPKAbuYMv6e3/nGoL63
8wCVywimDF1D7UcuNOGDeWwEneCAfR417mguDtItvU/AFod2UIc3lImOgWeYnm2/
k8BFAoGAGCDf2s1t5Tu9phiiS9Ue1PxnyFTC0nc+K+tFFEXC6WcGLDwzE818bsV1
boBpiw+MjP0EC1Kw28c8es/yiggu8Wn67vIxiKlIxnirQoDci49XNy9I6yX/9JvU
hsh9v6um/A8O2hqgGZSNps/0j+w8L10X/M1jIzV5EQv+lEs9ATo=
-----END RSA PRIVATE KEY-----
EOF
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/authorized_keys

# configure logging:
touch /var/log/daemon.log
chmod 666 /var/log/daemon.log
echo "daemon.* /var/log/daemon.log" >> /etc/rsyslog.d/50-default.conf

# add default user to necessary groups:
# workaround for Docker not being installed yet:
groupadd -f docker
usermod -aG docker vagrant

# Set vim as a default editor
update-alternatives --set editor /usr/bin/vim.basic
