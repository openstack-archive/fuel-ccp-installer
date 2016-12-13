Configurable Parameters in Fuel CCP Installer
=============================================

Configurable parameters are divided into three sections:

* generic Ansible variables
* Fuel CCP Installer specific
* Kargo specific

These variables only relate to Ansible global variables. Variables can be
defined in facts gathered by Ansible automatically, facts set in tasks,
variables registered from task results, and then in external variable files.
This document covers custom.yaml, which is either defined by a shell
variable or in custom.yaml in your inventory repo. (See :doc:`inventory_repo`
for more details.)

Generic Ansible variables
-------------------------

You can view facts gathered by Ansible automatically
`here <http://docs.ansible.com/ansible/playbooks_variables.html#information-discovered-from-systems-facts>`_

Some variables of note include:

* **ansible_user**: user to connect to via SSH
* **ansible_default_ipv4.address**: IP address Ansible automatically chooses.
  Generated based on the output from the command ``ip -4 route get 8.8.8.8``

Fuel CCP Installer specific variables
-------------------------------------

Fuel CCP Installer currently overrides several variables from Kargo currently.
Below is a list of variables and what they affect.

Common vars that are used in Kargo
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* **calico_version** - Specify version of Calico to use
* **calico_cni_version** - Specify version of Calico CNI plugin to use
* **docker_version** - Specify version of Docker to used (should be quoted
  string)
* **etcd_version** - Specify version of ETCD to use
* **ipip** - Enables Calico ipip encapsulation by default
* **hyperkube_image_repo** - Specify the Docker repository where Hyperkube
  resides
* **hyperkube_image_tag** - Specify the Docker tag where Hyperkube resides
* **kube_network_plugin** - Changes k8s plugin to Calico
* **kube_proxy_mode** - Changes k8s proxy mode to iptables mode
* **kube_version** - Specify a given Kubernetes hyperkube version
* **searchdomains** - Array of DNS domains to search when looking up hostnames
* **nameservers** - Array of nameservers to use for DNS lookup

Fuel CCP Installer-only vars
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* **e2e_conformance_image_repo** - Docker repository where e2e conformance
  container resides
* **e2e_conformance_image_tag** - Docker tag where e2e conformance container
  resides


Kargo variables
---------------

There are several variables used in deployment that are necessary for certain
situations. The first section is related to addressing.

Addressing variables
^^^^^^^^^^^^^^^^^^^^

* **ip** - IP to use for binding services (host var)
* **access_ip** - IP for other hosts to use to connect to. Useful when using
  OpenStack and you have separate floating and private ips (host var
* **ansible_default_ipv4.address** - Not Kargo-specific, but it is used if ip
  and access_ip are undefined
* **loadbalancer_apiserver** - If defined, all hosts will connect to this
  address instead of localhost for kube-masters and kube-master[0] for
  kube-nodes. See more details in the
  `HA guide <https://github.com/kubernetes-incubator/kargo/blob/master/docs/ha-mode.md>`_.
* **loadbalancer_apiserver_localhost** - If enabled, all hosts will connect to
  the apiserver internally load balanced endpoint.  See more details in the
  `HA guide <https://github.com/kubernetes-incubator/kargo/blob/master/docs/ha-mode.md>`_.

Cluster variables
^^^^^^^^^^^^^^^^^

Kubernetes needs some parameters in order to get deployed. These are the
following default cluster paramters:

* **cluster_name** - Name of cluster DNS domain (default is cluster.local)
* **kube_network_plugin** - Plugin to use for container networking
* **kube_service_addresses** - Subnet for cluster IPs (default is
  10.233.0.0/18)
* **kube_pods_subnet** - Subnet for Pod IPs (default is 10.233.64.0/18)
* **dns_setup** - Enables dnsmasq
* **dns_server** - Cluster IP for dnsmasq (default is 10.233.0.2)
* **skydns_server** - Cluster IP for KubeDNS (default is 10.233.0.3)
* **cloud_provider** - Enable extra Kubelet option if operating inside GCE or
  OpenStack (default is unset)
* **kube_hostpath_dynamic_provisioner** - Required for use of PetSets type in
  Kubernetes

Other service variables
^^^^^^^^^^^^^^^^^^^^^^^

* **docker_options** - Commonly used to set
  ``--insecure-registry=myregistry.mydomain:5000``
* **http_proxy/https_proxy/no_proxy** - Proxy variables for deploying behind a
  proxy

User accounts
^^^^^^^^^^^^^

Kargo sets up two Kubernetes accounts by default: ``root`` and ``kube``. Their
passwords default to changeme. You can set this by changing ``kube_api_pwd``.


