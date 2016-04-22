#! /bin/bash
export SOLAR_CONFIG_OVERRIDE="/.solar_config_override"
sudo pip install netaddr

pushd /vagrant
solar repo import -l . --name k8s
cp config.yaml.sample config.yaml
./setup_k8s.py deploy
solar changes stage
solar changes process
solar orch run-once -w 1200
