This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

Recommended solar version is `git checkout 1a33a7306d1485f503de967531c87a3b3aff5fcb`.

Express Vagrant setup:

1. Clone this repo and cd to it
2. Add fc23 vagrant box:
	* libvirt: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-libvirt.box --provider libvirt  --force`
	* virtualbox: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box --provider virtualbox --force`
3. `./deploy/kube-up.sh`
4. `vagrant ssh solar-dev1`
5. `kubectl get pods`

In config.yaml you can set:
- login data for kubernetes master
- ip for master
- login data for kubernetes nodes
- ip for nodes (as a list)
- some global kubernetes settings like dns service ip and dns domain


Kubernetes version change:

1. log in to solar master node (`vagrant ssh`)
2. solar resource update kube-config k8s_version=v1.2.1
3. solar changes stage
4. solar changes process
5. solar orch run-once
6. watch solar orch report
7. After a while, kubernetes will restart in desired version

