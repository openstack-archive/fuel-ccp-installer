.. _diag-info-tools:

Diagnostic info collection tools
================================

Configuring ansible logs and plugins
------------------------------------

Ansible logs and plugins are configured with the preinstall role and playbook
located in the ``utils/kargo`` directory.

In order to make changes to logs configuration without running the
``kargo_deploy.sh`` completely, run the following Ansible command from the
admin node::

.. code:: sh

      export ws=~/workspace/
      /usr/bin/ansible-playbook --ssh-extra-args '-o\ StrictHostKeyChecking=no' \
      -u vagrant -b --become-user=root -i ~/${ws}inventory/inventory.cfg \
      -e @${ws}kargo/inventory/group_vars/all.yml \
      -e @${ws}utils/kargo/roles/configure_logs/defaults/main.yml \
      ${ws}utils/kargo/preinstall.yml

Note that the ``ws`` var should point to the actual admin workspace directory.

Collecting diagnostic info
--------------------------

There is a diagnostic info helper script located in the
``/usr/local/bin/collect_logs.sh`` directory. It issues commands and collects
files given in the ``${ws}utils/kargo/roles/configure_logs/defaults/main.yml``
file, from all of the cluster nodes online. Results are aggregated to the
admin node in the ``logs.tar.gz`` tarball.

In order to re-build the tarball with fresh info, run from the admin node:

.. code:: sh

      ADMIN_WORKSPACE=$ws /usr/local/bin/collect_logs.sh

You can also adjust ansible forks with the ``FORKS=X`` and switch to the
password based ansible auth with the ``ADMIN_PASS=foopassword``.
