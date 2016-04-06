This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

You need solar dev env for now. Put Vagrantfile_solar instead of default Vagrantfile that is included in solar.

`setup_k8s.py` is a naive script that adds resources. Then you can proceed with normal solar steps.

Login on solar-dev, link this directory as /var/lib/solar/resources/k8s (or solar repository import -l ...)
