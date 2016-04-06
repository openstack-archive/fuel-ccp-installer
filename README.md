This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

You need solar dev env for now. Put Vagrantfile_solar instead of default Vagrantfile that is included in solar.

1. Login on solar-dev, link this directory as /var/lib/solar/resources/k8s (or solar repository import -l ...)
2. Install python on solar-dev* (sudo dnf install python). It's required for ansible
3. `setup_k8s.py` is a naive script that adds resources. Then you can proceed with normal solar steps.
