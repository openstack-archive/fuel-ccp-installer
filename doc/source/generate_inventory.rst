Generating Ansible Inventory
============================

Ansible makes use of an inventory file in order to list hosts, host groups, and
specify individual host variables. This file can be in any of three formats:
inifile, JSON, or YAML. Fuel CCP Installer only makes use of inifile format.

For many users, it is possible to generate Ansible inventory with the help of
your bare metal provisioner, such as `Cobbler <http://cobbler.github.io>`_ or
`Foreman <http://theforman.org>`_. For further reading, refer to the
documentation on `Dynamic Inventory <http://docs.ansible.com/ansible/intro_dynamic_inventory.html>`_.

Fuel CCP Installer takes a different approach, due its git-based workflow. You
can still use any tool you wish to generate Ansible inventory, but you need to
save this inventory file to the path `$ADMIN_WORKSPACE/inventory`.

Below you can find a few examples on how generate Ansible inventory that can be
used for deployment.

Using Fuel CCP's simple inventory generator
-------------------------------------------
If you run kargo_deploy.sh with a predefined list of nodes, it will generate
Ansible inventory for you automatically. Below is an example:

::
$ SLAVE_IPS="10.90.0.2 10.90.0.3 10.90.0.4" utils/jenkins/kargo_deploy.sh

This will generate the same inventory as the example
`inventory <https://github.com/openstack/fuel-ccp-installer/blob/master/inventory.cfg.sample>`_
file. Role distribution is as follows:

* The first 2 hosts have Kubernetes Master role
* The first 3 hosts have ETCD role
* All hosts have Kubernetes Node role

Using Kargo-cli
---------------

You can use `Kargo-cli <https://github.com/kubespray/kargo-cli>` tool to
generate Ansible inventory with some more complicated role distribution. Below
is an example you can use (indented for visual effect):

::
$ sudo apt-get install python-dev python-pip gcc libssl-dev libffi-dev
$ pip install kargo
$ kargo --noclone -i inventory.cfg prepare \
  --nodes \
    node1[ansible_ssh_host=10.90.0.2,ip=10.90.0.2] \
    node2[ansible_ssh_host=10.90.0.3,ip=10.90.0.3] \
    node3[ansible_ssh_host=10.90.0.4,ip=10.90.0.4] \
  --etcds \
    node4[ansible_ssh_host=10.90.0.5,ip=10.90.0.5] \
    node5[ansible_ssh_host=10.90.0.6,ip=10.90.0.6] \
    node6[ansible_ssh_host=10.90.0.7,ip=10.90.0.7] \
  --masters \
    node7[ansible_ssh_host=10.90.0.5,ip=10.90.0.8] \
    node8[ansible_ssh_host=10.90.0.6,ip=10.90.0.9]

This allows more granular control over role distribution, but kargo-cli has
several dependencies because it several other functions.

Manual inventory creation
-------------------------

You can simply Generate your inventory by hand by using the example
`inventory <https://github.com/openstack/fuel-ccp-installer/blob/master/inventory.cfg.sample>`_
file and save it as inventory.cfg. Note that all groups are required and you
should only define host variables inside the [all] section.
