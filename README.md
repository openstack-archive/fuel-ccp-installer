This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

Recommended solar version is `git checkout 1a33a7306d1485f503de967531c87a3b3aff5fcb`.

Vagrant setup:

1. Clone [solar](https://github.com/openstack/solar)
2. Copy Vagrantfile_solar from this repo to solar Vagrantfile
3. Add fc23 vagrant box:
	* libvirt: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-libvirt.box --provider libvirt  --force`
	* virtualbox: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box --provider virtualbox --force`
4. ensure that vagrant-settings.yaml contains these values:(slave count 2)
    * slaves_count: 2
    * master_image: solar-master
    * master_image_version: null
    * slaves_image: fc23
    * slaves_image_version: null
5. vagrant up
6. Copy, link or clone this repo to solar-dev VM into k8s folder
8. solar repo import -l k8s
9. cp config.yaml.sample config.yaml
10. ./setup-k8s.py deploy
11. solar changes stage
12. solar changes process
13. solar orch run-once
14. watch solar orch report
15. vagrant ssh solar-dev1
16. kubectl get pods (it works!)


In config.yaml you can set:
- login data for kubernetes master
- ip for master
- login data for kubernetes nodes
- ip for nodes (as a list)
- some global kubernetes settings like dns service ip and dns domain


Kubernetes version change:

1. log in to solar master node
2. solar resource update kube-config k8s_version=v1.2.1
3. solar changes stage
4. solar changes process
5. solar orch run-once
6. watch solar orch report
7. After a while, kubernetes will restart in desired version

