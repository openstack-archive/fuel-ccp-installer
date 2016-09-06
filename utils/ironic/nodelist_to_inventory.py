#!/usr/bin/python
# Converts Ironic YAML output to Ansible YAML inventory
# Example input:
#   openstack --os-cloud=bifrost baremetal node list -f yaml --noindent \
#   --fields name instance_info | python nodelist_to_inventory.py

import sys
import yaml

nodes = yaml.load(sys.stdin.read())

groups = {}
for node in nodes:
    for tag in node['Instance Info']['tags']:
        if tag not in groups.keys():
            groups[tag] = {}
        ip = node['Instance Info']['ipv4_address']
        groups[tag][node['Name']] = {'ip': ip}
print(yaml.dump(groups, indent=2, default_flow_style=False))
