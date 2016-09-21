.. _specify-hyperkube-image:

=================================
Deploy a specific hyperkube image
=================================

By default ``fuel-ccp-installer`` uses an hyperkube image downloaded from the
``quay.io`` images repository. See the variables ``hyperkube_image_repo`` and
``hyperkube_image_tag`` variables in the `kargo_default_common.yaml`_ file.

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
    export CUSTOM_YAML='hyperkube_image_repo: "gcr.io/google_containers/hyperkube-amd64"
    hyperkube_image_tag: "v1.3.7"
    '

    mkdir -p $WORKSPACE
    cd ./fuel-ccp-installer
    bash -x "./utils/jenkins/run_k8s_deploy_test.sh"

In this example the ``CUSTOM_YAML`` variable includes the definitions of
the ``hyperkube_image_repo`` and ``hyperkube_image_tag`` variables, defining
what ``hyperkube`` image to use and what repository to get the image from.

.. note::
   If you use an inventory Git repo please refer
   :ref:`inventory-and-deployment-data-management` to know how you can set
   variables for the environment.

.. _kargo_default_common.yaml: https://github.com/openstack/fuel-ccp-installer/blob/master/utils/kargo/kargo_default_common.yaml
