#!/usr/bin/env python

from solar.core.resource import composer as cr
from solar.core.resource import resource as rs

from solar.events.controls import Dep
from solar.events.controls import React
from solar.events.api import add_event

from itertools import combinations


def setup_master():
    config = cr.create('kube-config', 'k8s/global_config', {'dns_cluster_ip': '10.254.0.10',
                                                            'dns_domain': 'cluster.local'})[0]
    master = cr.create('kube-node-master', 'k8s/node', {'name': 'kube-node-master',
                                                         'ip': '10.0.0.3',
                                                         'ssh_user': 'vagrant',
                                                         'ssh_password': 'vagrant',
                                                         'ssh_key': None})['kube-node-master']
    etcd = cr.create('etcd', 'k8s/etcd', {'listen_client_port': 4001})['etcd']
    master.connect(etcd, {'name': 'listen_client_host'})
    etcd.connect(etcd, {'listen_client_host': 'listen_client_url',
                        'listen_client_port': 'listen_client_url'})

    kubernetes = cr.create('k8s-master', 'k8s/kubernetes', {'master_port': 8080})['k8s-master']
    master.connect(kubernetes, {'name': 'master_host'})
    etcd.connect(kubernetes, {'listen_client_url': 'etcd_servers'})
    kubernetes.connect(kubernetes, {'master_port': 'master_address',
                                    'master_host': 'master_address'})

    calico = cr.create('calico-master', 'k8s/calico', {})['calico-master']
    master.connect(calico, {'ip': 'ip'})
    etcd.connect(calico, {'listen_client_url': 'etcd_authority'})
    calico.connect(calico, {'etcd_authority': 'etcd_authority_internal'})
    master.connect(config, {})


def setup_nodes(num=1):
    kube_nodes = []
    etcd = rs.load('etcd')
    kubernetes_master = rs.load('k8s-master')
    calico_master = rs.load('calico-master')
    config = rs.load('kube-config')
    for i in xrange(num):
        j = i + 1
        kube_node = cr.create(
            'kube-node-%d' % j,
            'k8s/node',
            {'name': 'kube-node-%d' % j,
             'ip': '10.0.0.%d' % (3 + j),
             'ssh_user': 'vagrant',
             'ssh_password': 'vagrant',
             'ssh_key': None}
        )['kube-node-%d' % j]

        iface_node = cr.create(
            'kube-node-%d-iface' % j,
            'k8s/virt_iface',
            {'name': 'cbr0',
             'netmask': '255.255.255.0',
             'ipaddr': '192.168.%d.1' % (i + 1),
             'onboot': 'yes',
             'bootproto': 'static',
             'type': 'Bridge'})['kube-node-%d-iface' % j]
        kube_node.connect(iface_node, {})

        calico_node = cr.create('calico-node-%d' % j, 'k8s/calico', {})[0]

        add_event(Dep(calico_master.name, 'run', 'success', calico_node.name, 'run'))

        kube_node.connect(calico_node, {'ip': 'ip'})

        calico_node.connect(calico_node, {
            'etcd_authority': 'etcd_authority_internal'
        })

        etcd.connect(calico_node, {'listen_client_url': 'etcd_authority'})

        calico_cni = cr.create('calico-cni-node-%d' % j, 'k8s/cni', {})[0]
        calico_node.connect(calico_cni, {'etcd_authority_internal': 'etcd_authority'})

        docker = cr.create('kube-docker-%d' % j,
                           'k8s/docker')['kube-docker-%d' % j]

        add_event(Dep(docker.name, 'run', 'success', calico_node.name, 'run'))

        kube_node.connect(docker, {})
        iface_node.connect(docker, {'name': 'iface'})

        kubelet = cr.create('kubelet-node-%d' % j, 'k8s/kubelet', {
            'kubelet_args': '--v=5',
        })['kubelet-node-%d' % j]

        kube_node.connect(kubelet, {'name': 'kubelet_hostname'})
        kubernetes_master.connect(kubelet, {'master_address': 'master_api'})
        calico_node.connect(kubelet, {'etcd_authority_internal': 'etcd_authority'})
        config.connect(kubelet, {'dns_domain': 'dns_domain',
                                 'dns_cluster_ip': 'dns_cluster_ip'})

        kube_nodes.append(kube_node)
    kube_master = rs.load('kube-node-master')
    all_nodes = kube_nodes[:] + [kube_master]
    hosts_files = rs.load_all(startswith='hosts_file_node_kube-')
    for node in all_nodes:
        for host_file in hosts_files:
            node.connect(host_file, {
                'name': 'hosts:name',
                'ip': 'hosts:ip'
            })


def add_dashboard():
    kube_master = rs.load('kube-node-master')
    master = rs.load('k8s-master')
    dashboard = cr.create('kubernetes-dashboard', 'k8s/dashboard', {})[0]
    master.connect(dashboard, {'master_port': 'api_port'})
    kube_master.connect(dashboard, {'ip': 'api_host'})


def add_dns():
    config = rs.load('kube-config')
    kube_master = rs.load('kube-node-master')
    master = rs.load('k8s-master')
    kube_dns = cr.create('kube-dns', 'k8s/kubedns', {})[0]
    master.connect(kube_dns, {'master_port': 'api_port'})
    kube_master.connect(kube_dns, {'ip': 'api_host'})
    config.connect(kube_dns, {'dns_domain': 'dns_domain'})


setup_master()

setup_nodes(1)

# add_dashboard()

# add_dns()
