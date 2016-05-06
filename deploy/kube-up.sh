#! /bin/bash

pushd utils/vagrant
vagrant up
vagrant ssh solar -c /vagrant/deploy/deploy.sh
