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
