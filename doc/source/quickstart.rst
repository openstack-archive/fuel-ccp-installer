===========================
Kubernetes deployment guide
===========================

This guide provides a step by step instruction of how to deploy k8s cluster on
bare metal or a virtual machine.

K8s node requirements
=====================

The recommended deployment target requirements:

- At least 3 nodes running Ubuntu 16.04
- At least 8Gb of RAM per node
- At least 20Gb of disk space on each node.

Configure BM nodes (or the host running VMs) with the commands:
::

    sysctl net.ipv4.ip_forward=1
    sysctl net.bridge.bridge-nf-call-iptables=0

.. NOTE:: If you deploy on Ubuntu Trusty BM nodes or host running your VM
    nodes, make sure you have at least Kernel version 3.19.0-15 installed
    and ``modprobe br_netfilter`` enabled. Lucky you, if your provisioning
    underlay took care for that!

Admin node requirements
=======================

This is a node where to run the installer. Admin node should be Debian/Ubuntu
based with the following packages installed:

* ansible (2.1.x)
* python-netaddr
* sshpass
* git

.. NOTE:: You could use one of the k8s node as an admin node. In this case this
          node should meet both k8s and admin node requirements.

Node access requirements
========================

- Each node must have a user "vagrant" with a password "vagrant" created or
  have access via ssh key.
- Each node must have passwordless sudo for "vagrant" user.

Deploy k8s cluster
==================

Clone fuel-ccp-installer repository:

::

    git clone https://review.openstack.org/openstack/fuel-ccp-installer

Create deployment script:

::

    cat > ./deploy-k8s.sh << EOF
    #!/bin/bash
    set -ex

    # CHANGE ADMIN_IP AND SLAVE_IPS TO MATCH YOUR ENVIRONMENT
    export ADMIN_IP="10.90.0.2"
    export SLAVE_IPS="10.90.0.2 10.90.0.3 10.90.0.4"
    export DEPLOY_METHOD="kargo"
    export WORKSPACE="${HOME}/workspace"

    mkdir -p $WORKSPACE
    cd ./fuel-ccp-installer
    bash -x "./utils/jenkins/run_k8s_deploy_test.sh"
    EOF

- ``ADMIN_IP`` - IP of the node which will run ansible. When the `$ADMIN_IP`
  refers to a remote node, like a VM, it should take an IP address.
  Otherwise, it should take the `local` value.
- ``SLAVE_IPS`` - IPs of the k8s nodes.

.. NOTE:: If you deploy on Ubuntu Trusty BM nodes or host running your VM
    nodes, make sure to add ``export CUSTOM_YAML='ipip: true'`` to the
    ``./deploy-k8s.sh`` file.

Run script:

::

    bash ~/deploy-k8s.sh

.. note::

   See :ref:`specify-hyperkube-image` if you want to specify the location
   and version of the ``hyperkube`` image to use.
