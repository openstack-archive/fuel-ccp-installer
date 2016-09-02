=========================
Deploying k8s using Kargo
=========================

This guide provides a step by step instruction of how to deploy k8s cluster on
bare metal or a virtual machine using
`Kargo <https://github.com/kubespray/kargo>`__.

Node requirements
=================

The recommended deployment target requirements:

- At least 3 nodes running Ubuntu 16.04
- At least 8Gb of RAM per node
- At least 20Gb of disk space on each node.


Admin node requirements
=======================

This is a node where to run the installer. Admin node should be Ubuntu 16.04
with the following packages installed:

* ansible (2.1.x)
* python-netaddr
* sshpass
* git

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

    cat > ~/create-kargo-env.sh << EOF
    #!/bin/bash
    set -ex

    # CHANGE ADMIN_IP AND SLAVE_IPS TO MATCH YOUR ENVIRONMENT
    export ADMIN_IP="10.90.0.2"
    export SLAVE_IPS="10.90.0.2 10.90.0.3 10.90.0.4"
    export DEPLOY_METHOD="kargo"
    export WORKSPACE="~/workspace"

    mkdir -p $WORKSPACE
    cd ~/fuel-ccp-installer
    bash -x "~/utils/jenkins/run_k8s_deploy_test.sh"
    EOF

- ``ADMIN_IP`` - IP of the node which will run ansible. When the `$ADMIN_IP`
  refers to a remote node, like a VM, it should take an IP address.
  Otherwise, it should take the `local` value.
- ``SLAVE_IPS`` - IPs of the k8s nodes.

Run script:

::

    bash ~/create-kargo-env.sh
