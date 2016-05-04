#! /bin/bash

vagrant up
vagrant ssh solar -c /vagrant/deploy/deploy.sh
