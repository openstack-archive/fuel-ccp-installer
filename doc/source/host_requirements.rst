Preliminary host configuration
==============================

If you use standalone bare metal servers, or if you experience issues with a
Calico bird daemon and networking for a Kubernetes cluster VMs, ensure that
netfilter for bridge interfaces is disabled for your host node(s):

.. code:: sh

     echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables

Otherwise, bird daemon inside Calico won't function correctly because of
libvirt and NAT networks. More details can be found in this
`bug <https://bugzilla.redhat.com/show_bug.cgi?id=512206>`_.
