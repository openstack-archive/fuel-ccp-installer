#!/usr/bin/env python

import argparse
import os
import re

from netaddr import IPAddress
import yaml
import pbr.version

from solar.core.resource import composer as cr
from solar.core.resource import resource as rs
from solar.events.api import add_event
from solar.events.controls import Dep

DEFAULT_MASTER_NODE_RESOURCE_NAME = 'kube-node-master'
MASTER_NODE_RESOURCE_NAME = None
CONFIG_NAME = 'config.yaml'
DEFAULT_CONFIG_NAME = 'config.yaml.sample'

version_info = pbr.version.VersionInfo('Fuel CCP installer')


def create_config(global_config):
    return cr.create('kube-config', 'k8s/global_config', global_config)[0]


def get_slave_nodes():
    kube_nodes = rs.load_all(startswith='kube-node-')
    p = re.compile('^kube-node-\d+$')
    return [node for node in kube_nodes if p.match(node.name)]


def setup_master(config, user_config, existing_node):
    if existing_node:
        master = existing_node
    else:
        master = cr.create(
            MASTER_NODE_RESOURCE_NAME, 'k8s/node',
            {'name': 'kube-node-master',
             'ip': user_config['ip'],
             'ssh_user': user_config['username'],
             'ssh_password': user_config['password'],
             'ssh_key': user_config['ssh_key']})['kube-node-master']

    master.connect(config, {})
    docker = cr.create('kube-docker-master',
                       'k8s/docker')['kube-docker-master']
    master.connect(docker, {})

    kubelet = cr.create('kubelet-master',
                        'k8s/kubelet_master')['kubelet-master']
    config.connect(kubelet, {'k8s_version': 'k8s_version'})

    calico = cr.create('calico-master', 'k8s/calico_master',
                       {'options': "--nat-outgoing --ipip"})['calico-master']
    master.connect(calico, {'ip': ['ip', 'etcd_host']})
    config.connect(calico, {'network': 'network',
                            'prefix': 'prefix',
                            'calico_version': 'version'})
    calico.connect(calico, {'etcd_host': 'etcd_authority',
                            'etcd_port': 'etcd_authority',
                            'etcd_authority': 'etcd_authority_internal'})
    config.connect(kubelet,
                   {'service_cluster_ip_range': "service_cluster_ip_range"})
    master.connect(kubelet, {'name': 'master_host'})
    kubelet.connect(kubelet, {'master_host': 'master_address',
                              'master_port': 'master_address'})

    add_event(Dep('hosts_file_node_{}'.format(master.name), 'run', 'success',
                  kubelet.name, 'run'))

    add_event(Dep(docker.name, 'run', 'success', kubelet.name, 'run'))
    add_event(Dep(kubelet.name, 'run', 'success', calico.name, 'run'))


def setup_nodes(config, user_config, num=1, existing_nodes=None):
    kube_nodes = []
    kubernetes_master = rs.load('kubelet-master')
    calico_master = rs.load('calico-master')
    internal_network = IPAddress(config.args['network'])

    if existing_nodes:
        kube_nodes = [
            setup_slave_node(config, kubernetes_master, calico_master,
                             internal_network, i, None, node)
            for (i, node) in enumerate(existing_nodes)
        ]
    else:
        kube_nodes = [
            setup_slave_node(config, kubernetes_master, calico_master,
                             internal_network, i, user_config[i])
            for i in xrange(num)
        ]

    kube_master = rs.load(MASTER_NODE_RESOURCE_NAME)
    all_nodes = kube_nodes[:] + [kube_master]
    hosts_files = rs.load_all(startswith='hosts_file_node_')
    for node in all_nodes:
        for host_file in hosts_files:
            node.connect(host_file, {'name': 'hosts:name', 'ip': 'hosts:ip'})


def setup_slave_node(config,
                     kubernetes_master,
                     calico_master,
                     internal_network,
                     i,
                     user_config=None,
                     existing_node=None):
    j = i + 1
    if existing_node:
        kube_node = existing_node
    else:
        kube_node = cr.create(
            'kube-node-%d' % j, 'k8s/node',
            {'name': 'kube-node-%d' % j,
             'ip': user_config['ip'],
             'ssh_user': user_config['username'],
             'ssh_password': user_config['password'],
             'ssh_key': user_config['ssh_key']})['kube-node-%d' % j]

    iface_node = cr.create('kube-node-%d-iface' % j, 'k8s/virt_iface',
                           {'name': 'cbr0',
                            'ipaddr': str(internal_network + 256 * j + 1),
                            'onboot': 'yes',
                            'bootproto': 'static',
                            'type': 'Bridge'})['kube-node-%d-iface' % j]
    kube_node.connect(iface_node, {})

    config.connect(iface_node, {'netmask': 'netmask'})

    calico_node = cr.create('calico-node-%d' % j, 'k8s/calico', {})[0]

    kube_node.connect(calico_node, {'ip': 'ip'})
    config.connect(calico_node, {'calico_version': 'version'})

    calico_master.connect(calico_node, {'etcd_authority': 'etcd_authority'})
    calico_node.connect(calico_node, {
        'etcd_authority': 'etcd_authority_internal'
    })
    calico_cni = cr.create('calico-cni-node-%d' % j, 'k8s/cni', {})[0]
    calico_node.connect(calico_cni,
                        {'etcd_authority_internal': 'etcd_authority'})

    docker = cr.create('kube-docker-%d' % j,
                       'k8s/docker')['kube-docker-%d' % j]

    kube_node.connect(docker, {})
    iface_node.connect(docker, {'name': 'iface'})

    kubelet = cr.create('kubelet-node-%d' % j, 'k8s/kubelet', {
        'kubelet_args': '--v=5',
    })['kubelet-node-%d' % j]

    kube_node.connect(kubelet, {'name': 'kubelet_hostname'})
    kubernetes_master.connect(kubelet, {'master_address': 'master_api'})
    config.connect(kubelet, {'cluster_domain': 'cluster_domain',
                             'cluster_dns': 'cluster_dns',
                             'k8s_version': 'k8s_version'})

    add_event(Dep('hosts_file_node_{}'.format(kube_node.name), 'run',
                  'success', kubernetes_master.name, 'run'))

    add_event(Dep(docker.name, 'run', 'success', calico_node.name, 'run'))
    add_event(Dep(docker.name, 'run', 'success', kubelet.name, 'run'))
    add_event(Dep(calico_node.name, 'run', 'success', kubelet.name, 'run'))
    return kube_node


def add_dashboard(args, *_):
    kube_master = rs.load(MASTER_NODE_RESOURCE_NAME)
    master = rs.load('kubelet-master')
    dashboard = cr.create('kubernetes-dashboard', 'k8s/dashboard', {})[0]
    master.connect(dashboard, {'master_port': 'api_port'})
    kube_master.connect(dashboard, {'ip': 'api_host'})


def add_dns(args, *_):
    config = rs.load('kube-config')
    kube_master = rs.load(MASTER_NODE_RESOURCE_NAME)
    master = rs.load('kubelet-master')
    kube_dns = cr.create('kube-dns', 'k8s/kubedns', {})[0]
    master.connect(kube_dns, {'master_port': 'api_port'})
    kube_master.connect(kube_dns, {'ip': 'api_host'})
    config.connect(kube_dns, {'cluster_domain': 'cluster_domain',
                              'cluster_dns': 'cluster_dns'})


def add_node(args, user_config):
    if args.nodes == 0:
        requested_num = 1
    else:
        requested_num = args.nodes
    config = rs.load('kube-config')
    kubernetes_master = rs.load('kubelet-master')
    calico_master = rs.load('calico-master')
    internal_network = IPAddress(config.args['network'])

    def get_node_id(n):
        return n.name.split('-')[-1]

    kube_nodes = get_slave_nodes()
    newest_id = int(get_node_id(max(kube_nodes, key=get_node_id)))

    user_defined_nodes = user_config['kube_slaves']['slaves']
    new_left = len(user_defined_nodes) - len(kube_nodes)
    if new_left <= 0:
        raise ValueError("You need to configure more nodes in config.yaml")
    if new_left < requested_num:
        raise ValueError("You need to configure more nodes in config.yaml")

    new_nodes = [setup_slave_node(
        config=config, user_config=user_defined_nodes[i],
        kubernetes_master=kubernetes_master, calico_master=calico_master,
        internal_network=internal_network, i=i)
        for i in xrange(newest_id, newest_id + requested_num)]

    kube_master = rs.load(MASTER_NODE_RESOURCE_NAME)
    all_nodes = new_nodes[:] + [kube_master]
    hosts_files = rs.load_all(startswith='hosts_file_node_')
    for node in all_nodes:
        for host_file in hosts_files:
            node.connect(host_file, {'name': 'hosts:name', 'ip': 'hosts:ip'})


def get_master_and_slave_nodes():
    nodes = sorted(rs.load_all(startswith='node'), key=lambda x: x.name)
    # We are using existing nodes only if there are 2 or more of them. One
    # created node will result in all resources being created from scratch.
    if len(nodes) >= 2:
        return (nodes[0], nodes[1:])
    else:
        return (None, None)


def deploy_k8s(args, user_config):
    if args.nodes == 0:
        requested_num = len(user_config['kube_slaves']['slaves'])
    else:
        requested_num = args.nodes
    master_node, slave_nodes = get_master_and_slave_nodes()

    config = create_config(user_config['global_config'])

    setup_master(config, user_config['kube_master'], master_node)
    setup_nodes(config, user_config['kube_slaves']['slaves'], requested_num,
                slave_nodes)

    if args.dashboard:
        add_dashboard(args)

    if args.dns:
        add_dns(args)


commands = {
    'deploy': deploy_k8s,
    'dashboard': add_dashboard,
    'dns': add_dns,
    'add-node': add_node
}


def get_args(user_config):
    parser = argparse.ArgumentParser()
    parser.add_argument('command', type=str, choices=commands.keys())
    parser.add_argument('--nodes',
                        type=int,
                        default=0,
                        help='Slave node count. Works with deploy and '
                        'add-node. WARNING - this parameter does not work if '
                        'you have already created Solar node resources. This '
                        'script will make use of all your previously created '
                        'Solar nodes if their count is bigger than 1.')
    parser.add_argument('--dashboard',
                        dest='dashboard',
                        action='store_true',
                        help='Add dashboard. Works with deploy only. Can be '
                        ' done separately with `mcpinstall.py dashboard`')
    parser.add_argument('--dns',
                        dest='dns',
                        action='store_true',
                        help='Add dns. Works with deploy only. Can be done '
                        'separately with `mcpinstall.py dns')
    parser.set_defaults(dashboard=False, dns=False)

    return parser.parse_args()


def get_user_config():
    global CONFIG_NAME
    global DEFAULT_CONFIG_NAME

    if os.path.exists(CONFIG_NAME):
        with open(CONFIG_NAME) as conf:
            config = yaml.load(conf)
    elif os.path.exists(DEFAULT_CONFIG_NAME):
        with open(DEFAULT_CONFIG_NAME) as conf:
            config = yaml.load(conf)
    else:
        raise Exception('{0} and {1} configuration files not found'.format(
            CONFIG_NAME, DEFAULT_CONFIG_NAME))

    for slave in config['kube_slaves']['slaves']:
        for key, value in config['kube_slaves']['default'].iteritems():
            if key not in slave:
                slave[key] = value

    return config


def setup_master_node_name():
    global MASTER_NODE_RESOURCE_NAME

    master, _ = get_master_and_slave_nodes()
    if master is not None:
        MASTER_NODE_RESOURCE_NAME = master.name
    else:
        MASTER_NODE_RESOURCE_NAME = DEFAULT_MASTER_NODE_RESOURCE_NAME


if __name__ == "__main__":
    user_config = get_user_config()
    args = get_args(user_config)
    setup_master_node_name()
    commands[args.command](args, user_config)
