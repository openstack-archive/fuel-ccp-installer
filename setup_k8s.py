#!/usr/bin/env python

import argparse
import re

from netaddr import IPAddress

from solar.core.resource import composer as cr
from solar.core.resource import resource as rs
from solar.events.api import add_event
from solar.events.controls import Dep


def create_config():
    return cr.create('kube-config', 'k8s/global_config',
                     {'cluster_dns': '10.254.0.10',
                      'cluster_domain': 'cluster.local'}
                     )[0]


def setup_master(config):
    master = cr.create('kube-node-master', 'k8s/node',
                       {'name': 'kube-node-master',
                        'ip': '10.0.0.3',
                        'ssh_user': 'vagrant',
                        'ssh_password': 'vagrant',
                        'ssh_key': None})['kube-node-master']

    master.connect(config, {})
    docker = cr.create('kube-docker-master',
                       'k8s/docker')['kube-docker-master']
    master.connect(docker, {})

    kubelet = cr.create('kubelet-master',
                        'k8s/kubelet_master')['kubelet-master']

    calico = cr.create('calico-master', 'k8s/calico_master',
                       {'options': "--nat-outgoing --ipip"})['calico-master']
    master.connect(calico, {'ip': ['ip', 'etcd_host']})
    config.connect(calico, {'network': 'network',
                            'prefix': 'prefix'})
    calico.connect(calico, {'etcd_host': 'etcd_authority',
                            'etcd_port': 'etcd_authority',
                            'etcd_authority': 'etcd_authority_internal'})
    config.connect(kubelet,
                   {'service_cluster_ip_range': "service_cluster_ip_range"})
    master.connect(kubelet, {'name': 'master_host'})
    kubelet.connect(kubelet, {'master_host': 'master_address',
                              'master_port': 'master_address'})

    add_event(Dep(docker.name, 'run', 'success', kubelet.name, 'run'))
    add_event(Dep(kubelet.name, 'run', 'success', calico.name, 'run'))


def setup_nodes(config, num=1):
    kube_nodes = []
    kubernetes_master = rs.load('kubelet-master')
    calico_master = rs.load('calico-master')
    network = IPAddress('10.0.0.0')
    internal_network = IPAddress(config.args['network'])

    kube_nodes = [
        setup_slave_node(config, kubernetes_master, calico_master,
                         network, internal_network, i)
        for i in xrange(num)]

    kube_master = rs.load('kube-node-master')
    all_nodes = kube_nodes[:] + [kube_master]
    hosts_files = rs.load_all(startswith='hosts_file_node_kube-')
    for node in all_nodes:
        for host_file in hosts_files:
            node.connect(host_file, {
                'name': 'hosts:name',
                'ip': 'hosts:ip'
            })


def setup_slave_node(config, kubernetes_master, calico_master,
                     network, internal_network, i):
    j = i + 1
    kube_node = cr.create(
        'kube-node-%d' % j,
        'k8s/node',
        {'name': 'kube-node-%d' % j,
         'ip': str(network + j + 3),
         'ssh_user': 'vagrant',
         'ssh_password': 'vagrant',
         'ssh_key': None}
    )['kube-node-%d' % j]

    iface_node = cr.create(
        'kube-node-%d-iface' % j,
        'k8s/virt_iface',
        {'name': 'cbr0',
         'ipaddr': str(internal_network + 256 * j + 1),
         'onboot': 'yes',
         'bootproto': 'static',
         'type': 'Bridge'})['kube-node-%d-iface' % j]
    kube_node.connect(iface_node, {})

    config.connect(iface_node, {'netmask': 'netmask'})

    calico_node = cr.create('calico-node-%d' % j, 'k8s/calico', {})[0]

    kube_node.connect(calico_node, {'ip': 'ip'})
    calico_master.connect(calico_node,
                          {'etcd_authority': 'etcd_authority'})
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
                             'cluster_dns': 'cluster_dns'})

    add_event(Dep(docker.name, 'run', 'success', calico_node.name, 'run'))
    add_event(Dep(docker.name, 'run', 'success', kubelet.name, 'run'))
    add_event(Dep(calico_node.name, 'run', 'success', kubelet.name, 'run'))
    return kube_node


def add_dashboard(args):
    kube_master = rs.load('kube-node-master')
    master = rs.load('kubelet-master')
    dashboard = cr.create('kubernetes-dashboard', 'k8s/dashboard', {})[0]
    master.connect(dashboard, {'master_port': 'api_port'})
    kube_master.connect(dashboard, {'ip': 'api_host'})


def add_dns(args):
    config = rs.load('kube-config')
    kube_master = rs.load('kube-node-master')
    master = rs.load('kubelet-master')
    kube_dns = cr.create('kube-dns', 'k8s/kubedns', {})[0]
    master.connect(kube_dns, {'master_port': 'api_port'})
    kube_master.connect(kube_dns, {'ip': 'api_host'})
    config.connect(kube_dns, {'cluster_domain': 'cluster_domain',
                              'cluster_dns': 'cluster_dns'})


def add_node(args):
    config = rs.load('kube-config')
    kubernetes_master = rs.load('kubelet-master')
    calico_master = rs.load('calico-master')
    network = IPAddress('10.0.0.0')
    internal_network = IPAddress(config.args['network'])

    def get_node_id(n):
        return n.name.split('-')[-1]

    kube_nodes = rs.load_all(startswith='kube-node-')
    p = re.compile('^kube-node-\d+$')
    kube_nodes = [node for node in kube_nodes if p.match(node.name)]
    newest_id = int(get_node_id(max(kube_nodes, key=get_node_id)))

    new_nodes = [setup_slave_node(config, kubernetes_master, calico_master,
                                  network, internal_network, i)
                 for i in xrange(newest_id, newest_id + args.nodes)]

    kube_master = rs.load('kube-node-master')
    all_nodes = kube_nodes[:] + [kube_master]
    hosts_files = rs.load_all(startswith='hosts_file_node_kube-')
    for node in all_nodes:
        for host_file in hosts_files:
            node.connect(host_file, {
                'name': 'hosts:name',
                'ip': 'hosts:ip'
            })


def deploy_k8s(args):
    config = create_config()
    setup_master(config)
    setup_nodes(config, args.nodes)

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


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', type=str, choices=commands.keys())
    parser.add_argument('--nodes', type=int, default=1,
                        help='Slave node count. Works with deploy and '
                        'add-node')
    parser.add_argument('--dashboard', dest='dashboard', action='store_true',
                        help='Add dashboard. Works with deploy only. Can be '
                             ' done separately with `setup_k8s.py dashboard`')
    parser.add_argument('--dns', dest='dns', action='store_true',
                        help='Add dns. Works with deploy only. Can be done '
                             'separately with `setup_k8s.py dns')
    parser.set_defaults(dashboard=False, dns=False)

    return parser.parse_args()


if __name__ == "__main__":
    args = get_args()
    commands[args.command](args)
