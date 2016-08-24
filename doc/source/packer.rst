`Packer <https://www.packer.io>`_ Templates
===========================================

Custom build examples
---------------------

Ubuntu build for libvrit
~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: sh

      PACKER_LOG=1 \
      UBUNTU_MAJOR_VERSION=16.04 \
      UBUNTU_MINOR_VERSION=.1 \
      UBUNTU_TYPE=server \
      ARCH=amd64 \
      HEADLESS=true \
      packer build -var 'cpus=2' -var 'memory=2048' -only=qemu ubuntu.json

Note, in order to preserve manpages, sources and docs to the image, define
the ``-var 'cleanup=false'``.

Debian build for virtualbox
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code:: sh

      DEBIAN_MAJOR_VERSION=8 \
      DEBIAN_MINOR_VERSION=5 \
      ARCH=amd64 \
      HEADLESS=true \
      packer build -only=virtualbox-iso debian.json

Login Credentials
-----------------

(root password is "vagrant" or is not set )

-  Username: vagrant
-  Password: vagrant

Manual steps
------------

To add a local box into Vagrant, run from the repo root dir:

.. code:: sh

      vagrant box add --name debian \
      utils/packer/debian-8.5.0-amd64-libvirt.box

      vagrant box add --name ubuntu \
      utils/packer/ubuntu-16.04.1-server-amd64-libvirt.box

To upload a local box into `Atlas <https://atlas.hashicorp.com/>`_,
run from the `./utils/packer` dir:

.. code:: sh

      VERSION=0.1.0 DEBIAN_MAJOR_VERSION=8 DEBIAN_MINOR_VERSION=5 ARCH=amd64 \
      OSTYPE=debian TYPE=libvirt ATLAS_USER=john NAME=foobox ./deploy.sh

      UBUNTU_MAJOR_VERSION=16.04 UBUNTU_MINOR_VERSION=.1 UBUNTU_TYPE=server \
      ARCH=amd64 OSTYPE=ubuntu TYPE=virtualbox ATLAS_USER=doe ./deploy.sh

The first command creates a box named `john/foobox` which has the version
`0.1.0` and the libvirt provider. The second one uses the version autoincrement
and puts the box as `john/ubuntu-16.04.1-server-amd64` and virtualbox provider.
