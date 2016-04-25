#! /bin/bash

vagrant up
vagrant ssh -c /vagrant/deploy/deploy.sh
