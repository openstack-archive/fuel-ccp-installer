# Copyright 2016 Mirantis, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

from __future__ import print_function

import mock
import unittest

from collections import OrderedDict
import sys

path = "./utils/kargo"
if path not in sys.path:
    sys.path.append(path)

import inventory


class TestInventory(unittest.TestCase):
    def setUp(self):
        super(TestInventory, self).setUp()
        self.data = ['10.90.3.2', '10.90.3.3', '10.90.3.4']
        self.inv = inventory.KargoInventory()

    def test_get_ip_from_opts(self):
        optstring = "ansible_ssh_host=10.90.3.2 ip=10.90.3.2"
        expected = "10.90.3.2"
        result = self.inv.get_ip_from_opts(optstring)
        self.assertEqual(expected, result)

    def test_get_ip_from_opts_invalid(self):
        optstring = "notanaddr=value something random!chars:D"
        self.assertRaisesRegexp(ValueError, "IP parameter not found",
                                self.inv.get_ip_from_opts, optstring)

    def test_ensure_required_groups(self):
        groups = ['group1', 'group2']
        self.inv.config.add_section = mock.Mock()
        self.inv.ensure_required_groups(groups)
        calls = [mock.call('group1'), mock.call('group2')]
        self.inv.config.add_section.assert_has_calls(calls)

    def test_get_host_id(self):
        hostnames = ['node99', 'no99de01', '01node01']
        expected = [99, 1, 1]
        for hostname, expected in zip(hostnames, expected):
            result = self.inv.get_host_id(hostname)
            self.assertEqual(expected, result)

    def test_build_hostnames_add_one(self):
        changed_hosts = ['10.90.0.2']
        expected = OrderedDict([('node1',
                               'ansible_ssh_host=10.90.0.2 ip=10.90.0.2')])
        result = self.inv.build_hostnames(changed_hosts)
        self.assertEqual(expected, result)

    def test_build_hostnames_add_duplicate(self):
        changed_hosts = ['10.90.0.2']
        expected = OrderedDict([('node1',
                               'ansible_ssh_host=10.90.0.2 ip=10.90.0.2')])
        self.inv.config['all'] = expected
        result = self.inv.build_hostnames(changed_hosts)
        self.assertEqual(expected, result)

    def test_build_hostnames_add_two(self):
        changed_hosts = ['10.90.0.2', '10.90.0.3']
        expected = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        self.inv.config['all'] = OrderedDict()
        result = self.inv.build_hostnames(changed_hosts)
        self.assertEqual(expected, result)

    def test_build_hostnames_delete_first(self):
        changed_hosts = ['-10.90.0.2']
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        self.inv.config['all'] = existing_hosts
        expected = OrderedDict([
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        result = self.inv.build_hostnames(changed_hosts)
        self.assertEqual(expected, result)

    def test_exists_hostname_positive(self):
        hostname = 'node1'
        expected = True
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        result = self.inv.exists_hostname(existing_hosts, hostname)
        self.assertEqual(expected, result)

    def test_exists_hostname_negative(self):
        hostname = 'node99'
        expected = False
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        result = self.inv.exists_hostname(existing_hosts, hostname)
        self.assertEqual(expected, result)

    def test_exists_ip_positive(self):
        ip = '10.90.0.2'
        expected = True
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        result = self.inv.exists_ip(existing_hosts, ip)
        self.assertEqual(expected, result)

    def test_exists_ip_negative(self):
        ip = '10.90.0.200'
        expected = False
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        result = self.inv.exists_ip(existing_hosts, ip)
        self.assertEqual(expected, result)

    def test_delete_host_by_ip_positive(self):
        ip = '10.90.0.2'
        expected = OrderedDict([
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        self.inv.delete_host_by_ip(existing_hosts, ip)
        self.assertEqual(expected, existing_hosts)

    def test_delete_host_by_ip_negative(self):
        ip = '10.90.0.200'
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3')])
        self.assertRaisesRegexp(ValueError, "Unable to find host",
                                self.inv.delete_host_by_ip, existing_hosts, ip)

    def test_purge_invalid_hosts(self):
        proper_hostnames = ['node1', 'node2']
        bad_host = 'doesnotbelong2'
        existing_hosts = OrderedDict([
            ('node1', 'ansible_ssh_host=10.90.0.2 ip=10.90.0.2'),
            ('node2', 'ansible_ssh_host=10.90.0.3 ip=10.90.0.3'),
            ('doesnotbelong2', 'whateveropts=ilike')])
        self.inv.config['all'] = existing_hosts
        self.inv.purge_invalid_hosts(proper_hostnames)
        self.assertTrue(bad_host not in self.inv.config['all'].keys())

    def test_add_host_to_group(self):
        group = 'etcd'
        host = 'node1'
        opts = 'ip=10.90.0.2'

        self.inv.debug = mock.Mock()
        self.inv.config.set = mock.Mock()
        self.inv.add_host_to_group(group, host, opts)
        self.inv.config.set.assert_called_once_with(group, host, opts)

    def test_set_kube_master(self):
        group = 'kube-master'
        hosts = ['node1']
        self.inv.add_host_to_group = mock.Mock()
        self.inv.set_kube_master(hosts)
        self.inv.add_host_to_group.assert_called_once_with(group, hosts[0])

    def test_set_all(self):
        group = 'all'
        hosts = OrderedDict([
            ('node1', 'opt1'),
            ('node2', 'opt2')])

        self.inv.add_host_to_group = mock.Mock()
        self.inv.set_all(hosts)
        calls = [
            mock.call(group, 'node1', 'opt1'),
            mock.call(group, 'node2', 'opt2')]

        self.inv.add_host_to_group.assert_has_calls(calls)

    def test_set_k8s_cluster(self):
        group = 'k8s-cluster:children'
        self.inv.add_host_to_group = mock.Mock()
        self.inv.set_k8s_cluster()
        calls = [
            mock.call(group, 'kube-node'),
            mock.call(group, 'kube-master')]
        self.inv.add_host_to_group.assert_has_calls(calls)

    def test_set_kube_node(self):
        group = 'kube-node'
        hosts = ['node1']
        self.inv.add_host_to_group = mock.Mock()
        self.inv.set_kube_node(hosts)
        self.inv.add_host_to_group.assert_called_once_with(group, hosts[0])

    def test_set_etcd(self):
        group = 'etcd'
        hosts = ['node1']
        self.inv.add_host_to_group = mock.Mock()
        self.inv.set_etcd(hosts)
        self.inv.add_host_to_group.assert_called_once_with(group, hosts[0])
