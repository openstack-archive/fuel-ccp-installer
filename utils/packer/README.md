# [Packer](https://www.packer.io) Templates

The most of settings are specified as variables. This allows to override them
with `-var` key without template modification. A few environment variables
should be specified as a safety measure. See `debian.json` `ubuntu.json` with
the post-processors section with all details about deploying the Vagrant Boxes
to Atlas.

## Github repository for bug reports or feature requests:

[https://github.com/holser/packer-templates/](https://github.com/holser/packer-templates/)

## Custom builds

### Ubuntu build

```sh
jq 'del(.["post-processors", "push"])' ubuntu.json | \
  UBUNTU_MAJOR_VERSION=16.04 \
  UBUNTU_MINOR_VERSION=.1 \
  UBUNTU_TYPE=server \
  ARCH=amd64 \
  HEADLESS=true \
  packer build -var 'cpus=2' -
```

### Debian build
```sh
jq 'del(.["post-processors", "push"])' debian.json | \
  DEBIAN_MAJOR_VERSION=8 \
  DEBIAN_MINOR_VERSION=5 \
  ARCH=amd64 \
  HEADLESS=true \
  packer build -var 'cpus=2' - 
```

## Login Credentials

(root password is "vagrant" or is not set )

* Username: vagrant
* Password: vagrant

SSH_USER may be used to create a different user whci may be used later to
access environment.

## VM Specifications

* Vagrant Libvirt Provider
* Vagrant Virtualbox Provider

### qemu

* VirtIO dynamic Hard Disk (up to 10 GiB)

#### Customized installation

Debian configuration is based on 
[jessie preseed](https://www.debian.org/releases/jessie/example-preseed.txt).
Ubuntu configuration is based on 
[xenial preseed](https://help.ubuntu.com/lts/installation-guide/example-preseed.txt).
A few modifications have been made. Use `diff` for more details.

##### Debian/Ubuntu installation

* en_US.UTF-8
* keymap for standard US keyboard
* UTC timezone
* NTP enabled (default configuration)
* full-upgrade
* unattended-upgrades
* /dev/vda1 mounted on / using ext4 filesystem (all files in one partition)
* no swap
