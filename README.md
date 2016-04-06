This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

Setup:

1. You need solar dev env for now.
2. Put Vagrantfile_solar instead of default Vagrantfile that is included in solar.
3. Add fc23 vagrant box: `vagrant box add fc23 Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-libvirt.box --provider libvirt  --force`
4. Change boxes in `vagrant-settings.yaml` like:

    master_image: solar-master
    master_image_version: null
    slaves_image: fc23
    slaves_image_version: null

5. Login on solar-dev, link this directory as /var/lib/solar/resources/k8s (or solar repository import -l ...)
6. Install python on solar-dev* (sudo dnf install python). It's required for ansible
7. `setup_k8s.py` is a naive script that adds resources. Then you can proceed with normal solar steps.
