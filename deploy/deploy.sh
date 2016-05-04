#! /bin/bash

# set -xe

export SOLAR_CONFIG_OVERRIDE="/.solar_config_override"

# install kubectl if not exists
if ! type "kubectl" > /dev/null; then
    wget https://storage.googleapis.com/kubernetes-release/release/v1.2.2/bin/linux/amd64/kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
fi

pushd ~
if [ ! -d ".kube" ]; then
   mkdir .kube
   cp /vagrant/kube-config .kube/config
fi

# solar-resources stuff
git clone https://github.com/openstack/solar-resources
solar repo import -l solar-resources/resources -n resources
solar repo import -l solar-resources/templates -n templates

pushd /vagrant
sudo pip install -r requirements.txt
solar repo import -l resources --name k8s
cp config.yaml.sample config.yaml
./setup_k8s.py deploy
./setup_k8s.py dns
solar changes stage
solar changes process
solar orch run-once -w 1200
