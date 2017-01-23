Express Fuel CCP Kubernetes deployment using Kargo
--------------------------------------------------

Deploy Kubernetes on pre-provisioned virtual or bare metal hosts

This project leverages `Kargo <https://github.com/kubespray/kargo>`_ to deploy
Kubernetes with Calico networking plugin.

There are four ways you can use to deploy:

* Preprovisioned list of hosts
* Precreated Ansible inventory
* Vagrant
* `fuel-devops <https://github.com/openstack/fuel-devops>`_

Preprovisioned list of hosts
----------------------------

See :doc:`Quickstart guide <quickstart>`.

Precreated Ansible inventory
----------------------------

See :doc:`Generating Ansible Inventory <generate_inventory>`.

Vagrant
-------

Vagrant support is limited at this time. Try it and report bugs if you see any!

Using VirtualBox
================
::
vagrant up --provider virtualbox

Using Libvirt
=============

See :doc:`Vagrant libvirt guide <vagrant>`.
