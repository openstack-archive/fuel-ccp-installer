===========================
Kubernetes deployment guide
===========================

This guide provides a step by step instruction of how to deploy k8s cluster on
bare metal or a virtual machine.

k8s node requirements
=====================

The recommended deployment target requirements:

- At least 3 nodes running Ubuntu 16.04
- At least 8Gb of RAM per node
- At least 20Gb of disk space on each node.


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

Run script:

::

    bash ~/deploy-k8s.sh

Use a specific hyperkube image
------------------------------

By default ``fuel-ccp-installer`` uses an hyperkube image downloaded from the
``quay.io`` images repository. See the variables ``hyperkube_image_repo`` and
``hyperkube_image_tag`` variables in the `kargo_default_common.yaml file`_.

To use a specific version of ``hyperkube`` the ``hyperkube_image_repo`` and
``hyperkube_image_tag`` variables can be set in the ``deploy-k8s.sh`` script.
This is done through the ``CUSTOM_YAML`` environment variable. Here is an
example:

::

    #!/bin/bash
    set -ex

    # CHANGE ADMIN_IP AND SLAVE_IPS TO MATCH YOUR ENVIRONMENT
    export ADMIN_IP="10.90.0.2"
    export SLAVE_IPS="10.90.0.2 10.90.0.3 10.90.0.4"
    export DEPLOY_METHOD="kargo"
    export WORKSPACE="${HOME}/workspace"
    export CUSTOM_YAML='hyperkube_image_repo: "http://registry.mcp.fuel-infra.org/mcp/hyperkube-amd64"
    hyperkube_image_tag: "v1.4.0-beta.0-1-gcfa61_72"
    '

    mkdir -p $WORKSPACE
    cd ./fuel-ccp-installer
    bash -x "./utils/jenkins/run_k8s_deploy_test.sh"

In this example the ``CUSTOM_YAML`` variable includes the definitions of
the ``hyperkube_image_repo`` and ``hyperkube_image_tag`` variables, defining
what ``hyperkube`` image to use and what repository to get the image from.

.. _kargo_default_common.yaml file: https://github.com/openstack/fuel-ccp-installer/blob/master/utils/kargo/kargo_default_common.yaml
