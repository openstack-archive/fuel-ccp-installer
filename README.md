This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

Vagrant setup:

1. Clone [solar](https://github.com/openstack/solar)
2. Copy Vagrantfile_solar from this repo to solar Vagrantfile
3. Add fc23 vagrant box:
	* libvirt: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-libvirt.box --provider libvirt  --force`
	* virtualbox: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box --provider virtualbox --force`
4. ensure that vagrant-settings.yaml contains these values:(slave count na 2)
    * slaves_count: 2
    * master_image: solar-master
    * master_image_version: null
    * slaves_image: fc23
    * slaves_image_version: null
5. vagrant up
6. Copy, link or clone this repo to solar-dev VM into k8s folder
8. solar repo import -l k8s
9. ./setup-k8s.py
10. solar changes stage
11. solar changes process
12. solar orch run-once
13. watch solar orch report
14. vagrant ssh solar-dev1
15. kubectl get pods (it works!)
