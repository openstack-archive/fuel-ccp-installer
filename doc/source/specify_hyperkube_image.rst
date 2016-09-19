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
    export CUSTOM_YAML='hyperkube_image_repo: "http://registry.mcp.fuel-infra.org/mcp/hyperkube-amd64"
    hyperkube_image_tag: "v1.4.0-beta.5-15-gb7cf4_51"
    '

    mkdir -p $WORKSPACE
    cd ./fuel-ccp-installer
    bash -x "./utils/jenkins/run_k8s_deploy_test.sh"

In this example the ``CUSTOM_YAML`` variable includes the definitions of
the ``hyperkube_image_repo`` and ``hyperkube_image_tag`` variables, defining
what ``hyperkube`` image to use and what repository to get the image from.

.. _kargo_default_common.yaml: https://github.com/openstack/fuel-ccp-installer/blob/master/utils/kargo/kargo_default_common.yaml
