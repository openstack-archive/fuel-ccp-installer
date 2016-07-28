#!/usr/bin/python
# Usage: kargo_inventory.py ip1 [ip2 ...]
# Examples: kargo_inventory.py 10.10.1.3 10.10.1.4 10.10.1.5
#
# Advanced usage:
# Add another host after initial creation: kargo_inventory.py 10.10.1.5
# Delete a host: kargo_inventory.py -10.10.1.3
# Delete a host by id: kargo_inventory.py -node1

from collections import OrderedDict
try:
    import configparser
except ImportError:
    import ConfigParser as configparser

import os
import re
import sys

ROLES = ['kube-master', 'all', 'k8s-cluster:children', 'kube-node', 'etcd']
PROTECTED_NAMES = ROLES
_boolean_states = {'1': True, 'yes': True, 'true': True, 'on': True,
                   '0': False, 'no': False, 'false': False, 'off': False}


def get_var_as_bool(name, default):
    value = os.environ.get(name, '')
    return _boolean_states.get(value.lower(), default)

CONFIG_FILE = os.environ.get("CONFIG_FILE", "./inventory.cfg")
DEBUG = get_var_as_bool("DEBUG", True)
HOST_PREFIX = os.environ.get("HOST_PREFIX", "node")


class KargoInventory(object):

    def __init__(self, changed_hosts=None, config_file=None):
        self.config = configparser.ConfigParser(allow_no_value=True,
                                                delimiters=('\t', ' '))
        if config_file:
            self.config.read(config_file)

        self.ensure_required_groups(ROLES)

        if changed_hosts:
            self.hosts = self.build_hostnames(changed_hosts)
            self.purge_invalid_hosts(self.hosts.keys(), PROTECTED_NAMES)
            self.set_kube_master(list(self.hosts.keys())[:2])
            self.set_all(self.hosts)
            self.set_k8s_cluster()
            self.set_kube_node(self.hosts.keys())
            self.set_etcd(list(self.hosts.keys())[:3])

        if config_file:
            with open(config_file, 'w') as f:
                self.config.write(f)

    def debug(self, msg):
        if DEBUG:
            print("DEBUG: {0}".format(msg))

    def get_ip_from_opts(self, optstring):
        opts = optstring.split(' ')
        for opt in opts:
            if '=' not in opt:
                continue
            k, v = opt.split('=')
            if k == "ip":
                return v
        raise ValueError("IP parameter not found in options")

    def ensure_required_groups(self, groups):
        for group in groups:
            try:
                self.config.add_section(group)
            except configparser.DuplicateSectionError:
                pass

    def get_host_id(self, host):
        '''Returns integer host ID (without padding) from a given hostname.'''
        try:
            short_hostname = host.split('.')[0]
            return int(re.findall("\d+$", short_hostname)[-1])
        except IndexError:
            raise ValueError("Host name must end in an integer")

    def build_hostnames(self, changed_hosts):
        existing_hosts = OrderedDict()
        highest_host_id = 0
        try:
            for host, opts in self.config.items('all'):
                existing_hosts[host] = opts
                host_id = self.get_host_id(host)
                if host_id > highest_host_id:
                    highest_host_id = host_id
        except configparser.NoSectionError:
            pass

        # FIXME(mattymo): Fix condition where delete then add reuses highest id
        next_host_id = highest_host_id + 1

        all_hosts = existing_hosts.copy()
        for host in changed_hosts:
            if host[0] == "-":
                realhost = host[1:]
                if self.exists_hostname(all_hosts, realhost):
                    self.debug("Marked {0} for deletion.".format(realhost))
                    all_hosts.pop(realhost)
                elif self.exists_ip(all_hosts, realhost):
                    self.debug("Marked {0} for deletion.".format(realhost))
                    self.delete_host_by_ip(all_hosts, realhost)
            elif host[0].isdigit():
                if self.exists_hostname(all_hosts, host):
                    self.debug("Skipping existing host {0}.".format(host))
                    continue
                elif self.exists_ip(all_hosts, host):
                    self.debug("Skipping existing host {0}.".format(host))
                    continue

                next_host = "{0}{1}".format(HOST_PREFIX, next_host_id)
                next_host_id += 1
                all_hosts[next_host] = "ansible_ssh_host={0} ip={1}".format(
                    host, host)
            elif host[0].isalpha():
                raise Exception("Adding hosts by hostname is not supported.")

        return all_hosts

    def exists_hostname(self, existing_hosts, hostname):
        return hostname in existing_hosts.keys()

    def exists_ip(self, existing_hosts, ip):
        for host_opts in existing_hosts.values():
            if ip == self.get_ip_from_opts(host_opts):
                return True
        return False

    def delete_host_by_ip(self, existing_hosts, ip):
        for hostname, host_opts in existing_hosts.items():
            if ip == self.get_ip_from_opts(host_opts):
                del existing_hosts[hostname]
                return
        raise ValueError("Unable to find host by IP: {0}".format(ip))

    def purge_invalid_hosts(self, hostnames, protected_names=[]):
        for role in self.config.sections():
            for host, _ in self.config.items(role):
                if host not in hostnames and host not in protected_names:
                    self.debug("Host {0} removed from role {1}".format(host,
                               role))
                    self.config.remove_option(role, host)

    def add_host_to_group(self, group, host, opts=""):
        self.debug("adding host {0} to group {1}".format(host, group))
        self.config.set(group, host, opts)

    def set_kube_master(self, hosts):
        for host in hosts:
            self.add_host_to_group('kube-master', host)

    def set_all(self, hosts):
        for host, opts in hosts.items():
            self.add_host_to_group('all', host, opts)

    def set_k8s_cluster(self):
        self.add_host_to_group('k8s-cluster:children', 'kube-node')
        self.add_host_to_group('k8s-cluster:children', 'kube-master')

    def set_kube_node(self, hosts):
        for host in hosts:
            self.add_host_to_group('kube-node', host)

    def set_etcd(self, hosts):
        for host in hosts:
            self.add_host_to_group('etcd', host)


def main(argv=None):
    if not argv:
        argv = sys.argv[1:]
    KargoInventory(argv, CONFIG_FILE)

if __name__ == "__main__":
    sys.exit(main())
