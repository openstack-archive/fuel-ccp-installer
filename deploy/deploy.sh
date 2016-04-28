#! /bin/bash
export SOLAR_CONFIG_OVERRIDE="/.solar_config_override"
sudo pip install netaddr
sudo pip install -I zmq

wget https://storage.googleapis.com/kubernetes-release/release/v1.2.2/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

pushd ~
mkdir .kube
cp /vagrant/kube-config .kube/config
git clone https://github.com/pigmej/pykube.git
sudo pip install -I pykube
sudo start solar-worker

pushd /vagrant
solar repo import -l . --name k8s
cp config.yaml.sample config.yaml
./setup_k8s.py deploy
./setup_k8s.py dns
solar changes stage
solar changes process
solar orch run-once -w 1200
