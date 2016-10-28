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

For each inventory repo commit, it expects the following content of
the repo root directory:

* ``inventory.cfg`` - a mandatory inventory file. It must be created manually
  or generated based on ``$SLAVE_IPS`` provided with the
  `helper script <https://github.com/openstack/fuel-ccp-installer/blob/master/utils/kargo/inventory.py>`_.
* ``kargo_default_common.yaml`` - a mandatory vars file, overrides the kargo
  defaults in the ``$ADMIN_WORKSPACE/kargo/inventory/group_vars/all.yml``)
  and defaults for roles.
* ``kargo_default_ubuntu.yaml`` - a mandatory vars file for Ubuntu nodes,
  overrides the common file.
* ``custom.yaml`` - not a mandatory vars file, overrides all vars.

Note, that the ``custom.yaml`` make all data vars defined inside to override
same vars defined at other place. The data priority precedes as the following:
kargo defaults, then common defaults, then ubuntu defaults, then custom YAML.

Final data decisions is done automatically by the installer:

* If ``$INVENTORY_REPO`` is unset, make a local git repo and carry on and deploy.
* Or clone the given repo and checkout to ``$INVENTORY_COMMIT``, if any.
* Copy installer defaults into the repo and decide on which data to accept:
* If a file changes, do git reset (shall not overwrite a commited state).
* If a new file, or has no changes, go with it (shall auto-populate defaults).
* Stage only new files, if any, then commit and run deployment with Kargo.
* If result is OK, submit changes as a gerrit review
* Or fail deployment, as we usually would, don't submit anything to gerrit.

Ongoing inventory changes must be submitted by a user to ``$INVENTORY_REPO``
manually. Installer only initializes the repo during the initial install if it
is missing.
