This repository contains resources for configuring kubernetes with calico networking plugin using Solar.

Express Vagrant setup:
---------------------

1. `git clone -b stable https://github.com/pigmej/mcpinstall.git && cd mcpinstall`
2. `./deploy/kube-up.sh`
3. `vagrant ssh solar`
4. `kubectl get pods`

You can adjust any setting value from `utils/vagrant/vagrant-settings.yaml_defaults` by setting it in `utils/vagrant/vagrant-settings.yaml`. For example on Linux you should consider setting `sync_type` to `nfs` by adding `sync_type: nfs` to your vagrant-settings.yaml.

Fedora slave nodes:
-------------------

If you don't want to use Ubuntu for slaves, you can use Fedora. After step 2 in above steps, please do as follow:

1. Download box file for the Vagrant provider you are using from [here](https://dl.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/)
2. Import it to Vagrant `vagrant box add fc23 <downloaded-box-name> --provider <provider> --force`
3. Change slaves_image value to `fc23` in vagrant-settings.yaml file.
4. Proceed from step 3 from "Express Vagrant setup" section.


Configuration:
--------------

In config.yaml you can set:
- login data for kubernetes master
- IP address for master
- default login data for kubernetes slave nodes
- node-specific config (IP address is required, but you can override default access data)
- global_config resource inputs including:
  - cluster dns ip and domain
  - cluster ip range
  - default k8s version
  - default calico version

LCM example: Kubernetes version change:
--------------------------------------

1. log in to solar master node (`vagrant ssh solar`)
2. solar resource update kube-config k8s_version=v1.2.1
3. solar changes stage
4. solar changes process
5. solar orch run-once -w 600
6. After a while, kubernetes will restart in desired version
