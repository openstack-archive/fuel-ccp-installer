.. _inventory-and-deployment-data-management:

Inventory and deployment data management
========================================

Deployment data and ansible inventory are represented as a git repository,
either remote or local. It is cloned and being updated on the admin node's
``$ADMIN_WORKSPACE/inventory`` directory. The ``$ADMIN_WORKSPACE`` copies
a value of a given ``$WORKSPACE`` env var (defaults to the current directory of
the admin node). Or it takes a ``workspace``, when the ``$ADMIN_IP`` refers to
not a ``local`` admin node. For example, if it is a VM.

Installer passes that data and inventory to
`Kargo <https://github.com/kubernetes-incubator/kargo>`_ ansible installer.

Pre-prepared inventory should have the following content in
the repo root directory:

* ``inventory.cfg`` - a mandatory inventory file. It must be created manually
  or generated based on ``$SLAVE_IPS`` provided with the
  `helper script <https://github.com/kubernetes-incubator/kargo/blob/master/contrib/inventory_builder/inventory.py>`_.
* ``kargo_default_common.yaml`` - a mandatory vars file, overrides the kargo
  defaults in the ``$ADMIN_WORKSPACE/kargo/inventory/group_vars/all.yml``)
  and defaults for roles.
* ``kargo_default_ubuntu.yaml`` - a mandatory vars file for Ubuntu nodes,
  overrides the common file.
* ``custom.yaml`` - not a mandatory vars file, overrides all vars.

Note, that the ``custom.yaml`` overrides all data vars defined elsewhere in
Kargo or in defaults files. The data priority precedes as the following:
kargo defaults, then common defaults, then ubuntu defaults, then custom YAML.

Final data decisions are done automatically by the installer:

* If the ADMIN_WORKSPACE/inventory directory has content, it gets used.
* If SLAVE_IPS or fuel-devops deploy mode gets used, inventory is overwritten.
* Copy installer defaults into the inventory directory if they don't exist.
