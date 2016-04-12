#!/usr/bin/env python

from solar.core.resource import composer as cr
from solar.core.resource import resource as rs

from solar.events.controls import Dep
from solar.events.controls import React
from solar.events.api import add_event

from itertools import combinations


def setup_master():
    config = cr.create('kube-config', 'k8s/global_config', {'cluster_dns': '10.254.0.10',
                                                            'cluster_domain': 'cluster.local'})[0]
    master = cr.create('kube-node-master', 'k8s/node', {'name': 'kube-node-master',
                                                        'ip': '10.0.0.3',
                                                        'ssh_user': 'vagrant',
                                                        'ssh_password': 'vagrant',
                                                        'ssh_key': None})['kube-node-master']
    # etcd = cr.create('etcd', 'k8s/etcd', {'listen_client_port': 4001})['etcd']
    # master.connect(etcd, {'name': 'listen_client_host'})
    # etcd.connect(etcd, {'listen_client_host': 'listen_client_url',
    #                     'listen_client_port': 'listen_client_url'})
    #                     # 'listen_client_port_events': 'listen_client_url_events',
    #                     # 'listen_client_host': 'listen_client_url_events'})

    master.connect(config, {})
    docker = cr.create('kube-docker-master', 'k8s/docker')['kube-docker-master']
    master.connect(docker, {})

    kubelet = cr.create('kubelet-master', 'k8s/kubelet_master')['kubelet-master']

    calico = cr.create('calico-master', 'k8s/calico_master', {'options': "--nat-outgoing --ipip"})['calico-master']
    master.connect(calico, {'ip': ['ip', 'etcd_host']})
    config.connect(calico, {'network': 'network',
                            'prefix': 'prefix'})
    calico.connect(calico, {'etcd_host': 'etcd_authority',
                            'etcd_port': 'etcd_authority',
                            'etcd_authority': 'etcd_authority_internal'})
    config.connect(kubelet, {'service_cluster_ip_range': "service_cluster_ip_range"})
    master.connect(kubelet, {'name': 'master_host'})
    kubelet.connect(kubelet, {'master_host': 'master_address',
                              'master_port': 'master_address'})

    add_event(Dep(docker.name, 'run', 'success', kubelet.name, 'run'))
    add_event(Dep(kubelet.name, 'run', 'success', calico.name, 'run'))


def setup_nodes(num=1):
    kube_nodes = []
    kubernetes_master = rs.load('kubelet-master')
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
             'ipaddr': '192.168.%d.1' % (i + 1),  # TODO(jnowak) support config for it
             'onboot': 'yes',
             'bootproto': 'static',
             'type': 'Bridge'})['kube-node-%d-iface' % j]
        kube_node.connect(iface_node, {})

        config.connect(iface_node, {'netmask': 'netmask'})

        calico_node = cr.create('calico-node-%d' % j, 'k8s/calico', {})[0]

        kube_node.connect(calico_node, {'ip': 'ip'})
        calico_master.connect(calico_node, {'etcd_authority': 'etcd_authority'})
        calico_node.connect(calico_node, {
            'etcd_authority': 'etcd_authority_internal'
        })
        calico_cni = cr.create('calico-cni-node-%d' % j, 'k8s/cni', {})[0]
        calico_node.connect(calico_cni, {'etcd_authority_internal': 'etcd_authority'})

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
    master = rs.load('kubelet-master')
    dashboard = cr.create('kubernetes-dashboard', 'k8s/dashboard', {})[0]
    master.connect(dashboard, {'master_port': 'api_port'})
    kube_master.connect(dashboard, {'ip': 'api_host'})


def add_dns():
    config = rs.load('kube-config')
    kube_master = rs.load('kube-node-master')
    master = rs.load('kubelet-master')
    kube_dns = cr.create('kube-dns', 'k8s/kubedns', {})[0]
    master.connect(kube_dns, {'master_port': 'api_port'})
    kube_master.connect(kube_dns, {'ip': 'api_host'})
    config.connect(kube_dns, {'cluster_domain': 'cluster_domain',
                              'cluster_dns': 'cluster_dns'})


setup_master()

setup_nodes(1)

# add_dashboard()

# add_dns()
