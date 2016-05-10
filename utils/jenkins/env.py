# -*- coding: utf-8 -*-
from copy import deepcopy
import os
import subprocess as sub
import sys
import yaml

from devops.models import Environment


def create_overlay_image(env_name, node_name, base_image):
    overlay_image_path = 'tmp/{}_{}.qcow2'.format(env_name, node_name)
    base_image = os.path.abspath(base_image)
    if os.path.exists(overlay_image_path):
        os.unlink(overlay_image_path)
    try:
        sub.call(['qemu-img', 'create', '-b', base_image, '-f', 'qcow2',
                  overlay_image_path])
    except sub.CalledProcessError as e:
        sys.stdout.write(e.output)
        raise
    return overlay_image_path


def create_config():
    env = os.environ

    conf_path = env['CONF_PATH']
    with open(conf_path) as c:
        conf = yaml.load(c.read())

    env_name = env['ENV_NAME']
    image_path = env['IMAGE_PATH']
    master_image_path = env.get('MASTER_IMAGE_PATH', None)
    if master_image_path is None:
        master_image_path = image_path
    slaves_count = int(env['SLAVES_COUNT'])

    conf['env_name'] = env_name
    node_params = conf['rack-01-node-params']

    group = conf['groups'][0]
    for i in range(slaves_count):
        group['nodes'].append({'name': 'slave-{}'.format(i), 'role': 'slave'})
    for node in group['nodes']:
        node['params'] = deepcopy(node_params)
        if node['role'] == 'master':
            path = master_image_path
        else:
            path = image_path
        vol_path = create_overlay_image(env_name, node['name'], path)
        node['params']['volumes'][0]['source_image'] = vol_path
    return {'template': {'devops_settings': conf}}


def get_env():
    env = os.environ
    env_name = env['ENV_NAME']
    return Environment.get(name=env_name)


def get_master_ip(env):
    admin = env.get_node(role='master')
    return admin.get_ip_address_by_network_name('public')


def get_slave_ips(env):
    slaves = env.get_nodes(role='slave')
    ips = []
    for slave in slaves:
        ips.append(slave.get_ip_address_by_network_name('public'))
    return ips


def define_from_config(conf):
    env = Environment.create_environment(conf)
    env.define()
    env.start()


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == 'create_env':
        config = create_config()
        define_from_config(config)
    elif cmd == 'get_admin_ip':
        sys.stdout.write(get_master_ip(get_env()))
    elif cmd == 'get_slaves_ips':
        sys.stdout.write(get_slave_ips(get_env()))
