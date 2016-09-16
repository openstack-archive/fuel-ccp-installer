Express Fuel CCP Kubernetes deployment using Kargo
--------------------------------------------------

Deploy Kubernetes on pre-provisioned virtual or bare metal hosts

This project leverages [Kargo](https://github.com/kubespray/kargo) to deploy
Kubernetes with Calico networking plugin.

There are four ways you can use to deploy:

* Preprovisioned list of hosts
* Precreated Ansible inventory
* Vagrant
* [fuel-devops](https://github.com/openstack/fuel-devops)

Preprovisioned list of hosts
----------------------------

See [Quickstart guide](doc/source/quickstart.rst)

Precreated Ansible inventory
----------------------------

See [Generating Ansible Inventory](doc/source/generate-inventory.rst)

Vagrant
-------

Vagrant support is limited at this time. Try it and report bugs if you see any!

Using VirtualBox
::
vagrant up --provider virtualbox

Using Libvirt
::
sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
vagrant plugin --install vagrant-libvirt
vagrant up --provider libvirt
