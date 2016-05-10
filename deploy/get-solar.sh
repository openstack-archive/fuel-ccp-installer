#! /bin/bash
pushd /vagrant/deploy
rm -rf solar
rm -rf solar-resources

git clone https://github.com/openstack/solar.git
pushd solar/bootstrap/playbooks
find . -type f -print0 |
    xargs -0 perl -pi -e 's;(?<!(home|/tmp))/vagrant;/vagrant/deploy/solar;g'
perl -pi -e 's;pip install -e .;'\
     'pip install -e /vagrant/deploy/solar;g' solar.yaml
