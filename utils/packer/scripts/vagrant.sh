#!/bin/bash -euxo

date > /etc/vagrant_box_build_time

SSH_USER=${SSH_USER:-vagrant}
SSH_USER_HOME=${SSH_USER_HOME:-/home/${SSH_USER}}
VAGRANT_INSECURE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCy1JMEoVy4XyLVBpHcMG+2u1yfs1SKl8u9VKsnmfBRp+0zAT3fd+Y/p8oRnw7cmqNJtREXf4RrS2uqY2+kUww7x92dbF48+5OrGIh16x1pDXgJMmOQyQdIHz+s8847U/uF9v0aT5Do90MVVLfPk4gsJEWSqINJZduQpW2kLY+9kD5xsXZQlCCmWOyMEYl9RJC02TU06xKVIyzT6iSpC6+UwFEKkaLAeMGtc7Qgcvv3r7oXJ7tWm9nURx1Is/trihuPQUX15czBkfzlGz2Uj4G5ff/oJCLO0Uwbojr1NQDOJywr4/KH3ZJHS+63/O9fAXfbryA1HgtTq412Eete4iTR vagrant@vm
"

VAGRANT_SECURE_KEY="-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----"

# Packer passes boolean user variables through as '1', but this might change in
# the future, so also check for 'true'.
if [ "${INSTALL_VAGRANT_KEY}" = "true" ] || [ "${INSTALL_VAGRANT_KEY}" = "1" ]; then
    # Create Vagrant user (if not already present)
    if ! id -u ${SSH_USER} >/dev/null 2>&1; then
        echo "==> Creating ${SSH_USER} user"
        /usr/sbin/groupadd ${SSH_USER}
        /usr/sbin/useradd ${SSH_USER} -g ${SSH_USER} -G sudo -d ${SSH_USER_HOME} --create-home
        echo "${SSH_USER}:${SSH_USER}" | chpasswd
    fi

    # Set up sudo
    echo "==> Giving ${SSH_USER} sudo powers"
    echo "${SSH_USER}        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant

    echo "==> Installing vagrant keys"
    mkdir ${SSH_USER_HOME}/.ssh
    chmod 700 ${SSH_USER_HOME}/.ssh

    pushd ${SSH_USER_HOME}/.ssh

    # https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
    echo "${VAGRANT_INSECURE_KEY}" > ${SSH_USER_HOME}/.ssh/authorized_keys
    chmod 600 ${SSH_USER_HOME}/.ssh/authorized_keys

    echo "${VAGRANT_SECURE_KEY}" > ${SSH_USER_HOME}/.ssh/id_rsa
    chmod 600 ${SSH_USER_HOME}/.ssh/id_rsa
    chown -R ${SSH_USER}:${SSH_USER} ${SSH_USER_HOME}/.ssh
    popd

    # add default user to necessary groups:
    # workaround for Docker not being installed yet:
    groupadd -f docker
    usermod -aG docker vagrant
fi
