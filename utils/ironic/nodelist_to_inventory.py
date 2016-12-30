#!/usr/bin/python

import yaml

with open('nodes.yaml', 'r') as f:
    nodes = yaml.load(f)

groups = {}
for node in nodes:
    for tag in node['Instance Info']['tags']:
        if not tag in groups.keys():
           groups[tag] = {}
        groups[tag][node['Name']] = {'ip':
                           node['Instance Info']['ipv4_address']}
print yaml.dump(groups, indent=2, default_flow_style=False)
