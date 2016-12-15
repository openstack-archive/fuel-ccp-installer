.. _external_ip_controller:

=================================
Installing External IP Controller
=================================

This document describes how to expose Kubernetes services using External IP
Controller.

Introduction
~~~~~~~~~~~~

One of the possible ways to expose k8s services on a bare metal deployments is
using External IPs. Each node runs a kube-proxy process which programs
iptables rules to trap access to External IPs and redirect them to the correct
backends.

So in order to access k8s service from the outside we just need to route public
traffic to one of k8s worker nodes which has kube-proxy running and thus has
needed iptables rules for External IPs.

Deployment scheme
~~~~~~~~~~~~~~~~~

Description
-----------

External IP controller is k8s application which is deployed on top of k8s
cluster and which configures External IPs on k8s worker node(s) to provide IP
connectivity.

For further details please read `External IP controller documentation
<https://github.com/Mirantis/k8s-externalipcontroller/blob/master/doc/>`_

Ansible Playbook
----------------

The playbook is ``utils/kargo/externalip.yaml`` and the ansible role is
``utils/kargo/roles/externalip``.

The nodes that have ``externalip`` role assigned to them will run External IP
controller application which will manage Kubernetes services' external IPs.
Playbook labes such nodes and then creates DaemonSet with ``nodeSelector``.

External IP scheduler will be running as a standard ReplicaSet with specified
number of replicas.

ECMP deployment
~~~~~~~~~~~~~~~

Deployment model
----------------

In this sample deployment we're going to deploy External IP controller on a set
of nodes and provide load balancing and high availability for External IPs
based on Equal-cost multi-path routing (ECMP).

For further details please read `Documentation about ECMP deployment
<https://github.com/Mirantis/k8s-externalipcontroller/blob/master/doc/ecmp-load-balancing.md>`_

Inventory
---------

You can take inventory generated previously for Kargo deployment. Using
``utils/kargo/externalip.yaml`` playbook with such inventory will deploy
External IP controller on all ``kube-node`` worker nodes.

Custom yaml
-----------

Custom Ansible yaml for ECMP deployment is stored here:
``utils/jenkins/extip_ecmp.yaml``. Here is the content:

::

    # Type of deployment
    extip_ctrl_app_kind: "DaemonSet"
    # IP distribution model
    extip_distribution: "all"
    # Netmask for external IPs
    extip_mask: 32
    # Interface to bring IPs on, should be "lo" for ECMP
    extip_iface: "lo"

Deployment
----------

Just run the following ansible-playbook command:

.. code:: sh

      export ws=/home/workspace
      /usr/bin/ansible-playbook -e ansible_ssh_pass=vagrant -u vagrant -b \
      --become-user=root -i ${ws}/inventory/inventory.cfg \
      -e @${ws}/utils/jenkins/extip_ecmp.yaml \
      ${ws}/utils/kargo/externalip.yaml

This will deploy the application according to your inventory.

Routing
-------

Application only brings IPs up or down on specified interface. We also need to
provide routing to those nodes with external IPs. So for Kubernetes cluster
with Calico networking plugin we already have ``calico-node`` container running
on every k8s worker node. This container also includes BGP speaker which
monitors local routing tables and announces changes via BGP protocol.
So in order to include external IPs to BGP speaker export we need to add the
following custom export filter for Calico:

.. code:: sh

      cat << EOF | etcdctl set /calico/bgp/v1/global/custom_filters/v4/lo_iface
      if ( ifname = "lo" ) then {
        if net != 127.0.0.0/8 then accept;
      }
      EOF

Please note that this will only configure BGP for ``calico-node``. In order to
announce routing to your network infrastructure you may want to peer Calico
with routers. Please check this URL for details:

`Kargo docs: Calico BGP Peering with border routers
<https://github.com/kubernetes-incubator/kargo/blob/master/docs/calico.md#optional--bgp-peering-with-border-routers>`_

Uninstalling and undoing customizations
---------------------------------------

Uninstall k8s applications by running the following commands on the first
kube-master node in your ansible inventory:

.. code:: sh

      kubectl delete -f /etc/kubernetes/extip_scheduler.yml
      kubectl delete -f /etc/kubernetes/extip_controller.yml

Remove custom Calico export filter:

.. code:: sh

      etcdctl rm /calico/bgp/v1/global/custom_filters/v4/lo_iface

Also remove external IPs from `lo` interface on the nodes with the command
like this:

.. code:: sh

      ip ad del 10.0.0.7/32 dev lo

Where ``10.0.0.7/32`` is external IP.
