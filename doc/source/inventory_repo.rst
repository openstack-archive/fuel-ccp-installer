Inventory and deployment data management
========================================

Deployment data and ansible inventory are represented as a git repository,
either remote or local. It is clonned and being updated at the admin node
`$ADMIN_WORKSPACE/inventory` directory. The `$ADMIN_WORKSPACE` copies a value
of a given `$WORKSPACE` env var (defaults to the current directory of the
admin node). Or it takes a `workspace`, when the `$ADMIN_IP` refers to not a
`local` admin node. For example, if it is a VM.

Installer passes that data and inventory to
`Kargo <https://github.com/kubespray/kargo>`_ ansible installer.

For each inventory repo commit, it expects the following content of
the `./inventory` directory:

* `inventory.cfg` - a mandatory inventory file. By default, it describes a
  Kubernetes cluster of 3 nodes. It may be updated manually or generated for
  a given set of `$SLAVE_IPS` with the
  `helper script <https://github.com/openstack/fuel-ccp-installer/blob/master/utils/kargo/inventory.py>`_.
* `kargo_default_common.yaml` - a mandatory vars file, overrides the kargo
  defaults in the `$ADMIN_WORKSPACE/kargo/inventory/group_vars/all.yml`)
  and defaults for roles.
* `kargo_default_ubuntu.yaml` - a mandatory vars file for Ubuntu nodes,
  overrides the common file.
* `custom.yaml` - not a mandatory vars file, overrides all vars.

Note, that the `custom.yml` make all data vars defined inside to override same
vars defined at other place. The data priority grows as the following: kargo
defaults, then common defaults, then ubuntu defaults, then custom YAML.

Final data decisions is done automatically by the installer:

* if `$INVENTORY_REPO` is unset, make a local git repo and carry on and deploy.
* Or clone the given repo and checkout to `$INVENTORY_COMMIT`, if any.
* Copy installer defaults into the repo and decide on which data to accept:
* If a file changes, do git reset (shall not overwrite a commited state).
* If a new file, or has no changes, go with it (shall auto-populate defaults).
* Stage only new files, if any, then commit and run deployment with Kargo.
* If result is OK, submit changes as a gerrit review
* Or fail deployment, as we usually would, don't submit anything to gerrit.

This flow requires user changes to be submitted by a user and committed
manually. Installer only populates defaults for a mandatory files.
