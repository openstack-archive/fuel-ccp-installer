.. _tshoot:

===============
Troubleshooting
===============

Calico related problems
=======================

If you use standalone bare metal servers, or if you experience issues with a
Calico bird daemon and networking for a Kubernetes cluster VMs, ensure that
netfilter for bridge interfaces is disabled for your host node(s):

.. code:: sh

     echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables

Otherwise, bird daemon inside Calico won't function correctly because of
libvirt and NAT networks. More details can be found in this
`bug <https://bugzilla.redhat.com/show_bug.cgi?id=512206>`_.

Then reporting issues, please also make sure to include details on the host
OS type and its kernel version.

DNS resolve issues
==================

See a `known configuration issue <https://bugs.launchpad.net/fuel-ccp/+bug/1627680>`_.
The workaround is as simple as described in the bug: always define custom
intranet DNS resolvers in the ``upstream_dns_servers`` var listed in the first
place, followed by public internet resolvers, if any.

Network check
=============

While a net check is a part of deployment process, you can run it manually
from the admin node as well:

.. code:: sh

      export ws=~/workspace/
      /usr/bin/ansible-playbook -e ansible_ssh_pass=vagrant -u vagrant -b \
      --become-user=root -i ~/${ws}inventory/inventory.cfg \
      -e @${ws}kargo/inventory/group_vars/all.yml \
      -e @${ws}inventory/kargo_default_common.yaml \
      -e @${ws}inventory/kargo_default_ubuntu.yaml \
      -e @${ws}inventory/custom.yaml \
      ${ws}utils/kargo/postinstall.yml -v --tags netcheck

There is also K8s netcheck server and agents applications running.
In order to verify networking health and status of agents, which include
timestamps of the last known healthy networking state, those may be quieried
from cluster nodes with:

.. code:: sh

      curl -s -X GET 'http://localhost:31081/api/v1/agents/' | \
      python -mjson.tool
      curl -X GET 'http://localhost:31081/api/v1/connectivity_check'
