Admin node
==========

This is a node where to run the installer. Admin node should be Ubuntu/Debian
based with the following packages installed:

* ansible (2.1.x),
* python-netaddr,
* sshpass,
* git.

The env var `$ADMIN_IP` determines where to run `admin_node_command` function
of the installer main script. When the `$ADMIN_IP` refers to a remote node,
like a VM, it should take an IP address. Otherwise, it should take the `local`
value.
