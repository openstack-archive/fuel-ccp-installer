# -*- mode: ruby -*-
# vi: set ft=ruby :
#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

Vagrant.require_version ">= 1.7.4"

require 'yaml'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# configs, custom updates _defaults
defaults_cfg = YAML.load_file('vagrant-settings.yaml_defaults')
if File.exist?('vagrant-settings.yaml')
  custom_cfg = YAML.load_file('vagrant-settings.yaml')
  cfg = defaults_cfg.merge(custom_cfg)
else
  cfg = defaults_cfg
end

SLAVES_COUNT = cfg["slaves_count"]
SLAVES_RAM = cfg["slaves_ram"]
SLAVES_IPS = cfg["slaves_ips"]
SLAVES_IMAGE = cfg["slaves_image"]
SLAVES_IMAGE_VERSION = cfg["slaves_image_version"]
MASTER_RAM = cfg["master_ram"]
MASTER_IPS = cfg["master_ips"]
MASTER_IMAGE = cfg["master_image"]
MASTER_IMAGE_VERSION = cfg["master_image_version"]
SYNC_TYPE = cfg["sync_type"]
MASTER_CPUS = cfg["master_cpus"]
SLAVES_CPUS = cfg["slaves_cpus"]
PARAVIRT_PROVIDER = cfg.fetch('paravirtprovider', false)
PREPROVISIONED = cfg.fetch('preprovisioned', true)
SOLAR_DB_BACKEND = cfg.fetch('solar_db_backend', 'riak')

# Initialize noop plugins only in case of PXE boot
require_relative 'bootstrap/vagrant_plugins/noop' unless PREPROVISIONED

def ansible_playbook_command(filename, args=[])
  "ansible-playbook -v -i \"localhost,\" -c local /vagrant/bootstrap/playbooks/#{filename} #{args.join ' '}"
end

def shell_script(filename, env=[], args=[])
  "/bin/bash -c \"#{env.join ' '} #{filename} #{args.join ' '} 2>/dev/null\""
end

solar_script = ansible_playbook_command("solar.yaml")
solar_agent_script = ansible_playbook_command("solar-agent.yaml")
# NOTE(bogdando) w/a for a centos7 issue
fix_six = shell_script("/vagrant/bootstrap/playbooks/fix_centos7_six.sh")

master_pxe = ansible_playbook_command("pxe.yaml")

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "solar-dev", primary: true do |config|
    config.vm.box = MASTER_IMAGE
    config.vm.box_version = MASTER_IMAGE_VERSION

    config.vm.provision "shell", inline: fix_six, privileged: true
    config.vm.provision "shell", inline: solar_script, privileged: true, env: {"SOLAR_DB_BACKEND": SOLAR_DB_BACKEND}
    config.vm.provision "shell", inline: master_pxe, privileged: true unless PREPROVISIONED
    config.vm.provision "file", source: "~/.vagrant.d/insecure_private_key", destination: "/vagrant/tmp/keys/ssh_private"
    config.vm.host_name = "solar-dev"

    config.vm.provider :virtualbox do |v|
      v.memory = MASTER_RAM
      v.cpus = MASTER_CPUS
      v.customize [
        "modifyvm", :id,
        "--memory", MASTER_RAM,
        "--cpus", MASTER_CPUS,
        "--ioapic", "on",
      ]
      if PARAVIRT_PROVIDER
        v.customize ['modifyvm', :id, "--paravirtprovider", PARAVIRT_PROVIDER] # for linux guest
      end
      v.name = "solar-dev"
    end

    config.vm.provider :libvirt do |libvirt|
      libvirt.driver = 'kvm'
      libvirt.memory = MASTER_RAM
      libvirt.cpus = MASTER_CPUS
      libvirt.nested = true
      libvirt.cpu_mode = 'host-passthrough'
      libvirt.volume_cache = 'unsafe'
      libvirt.disk_bus = "virtio"
    end

    if SYNC_TYPE == 'nfs'
      config.vm.synced_folder ".", "/vagrant", type: "nfs"
    end
    if SYNC_TYPE == 'rsync'
      config.vm.synced_folder ".", "/vagrant", type: "rsync",
        rsync__args: ["--verbose", "--archive", "--delete", "-z"]
    end

    ind = 0
    MASTER_IPS.each do |ip|
      config.vm.network :private_network, ip: "#{ip}", :dev => "solbr#{ind}", :mode => 'nat'
      ind = ind + 1
    end
  end

  SLAVES_COUNT.times do |i|
    index = i + 1
    ip_index = i + 3
    config.vm.define "solar-dev#{index}" do |config|

      # Standard box with all stuff preinstalled
      config.vm.box = SLAVES_IMAGE
      config.vm.box_version = SLAVES_IMAGE_VERSION
      config.vm.host_name = "solar-dev#{index}"

      if PREPROVISIONED
        # config.vm.provision "shell", inline: fix_six, privileged: true
        # config.vm.provision "shell", inline: solar_agent_script, privileged: true
        #TODO(bogdando) figure out how to configure multiple interfaces when was not PREPROVISIONED
        ind = 0
        SLAVES_IPS.each do |ip|
          config.vm.network :private_network, ip: "#{ip}#{ip_index}", :dev => "solbr#{ind}", :mode => 'nat'
          ind = ind + 1
        end
      else
        # Disable attempts to install guest os and check that node is booted using ssh,
        # because nodes will have ip addresses from dhcp, and vagrant doesn't know
        # which ip to use to perform connection
        config.vm.communicator = :noop
        config.vm.guest = :noop_guest
        # Configure network to boot vm using pxe
        config.vm.network "private_network", adapter: 1, ip: "10.0.0.#{ip_index}"
        config.vbguest.no_install = true
        config.vbguest.auto_update = false
      end

      config.vm.provider :virtualbox do |v|
        boot_order(v, ['net', 'disk'])
        v.customize [
            "modifyvm", :id,
            "--memory", SLAVES_RAM,
            "--cpus", SLAVES_CPUS,
            "--ioapic", "on",
            "--macaddress1", "auto",
        ]
        if PARAVIRT_PROVIDER
          v.customize ['modifyvm', :id, "--paravirtprovider", PARAVIRT_PROVIDER] # for linux guest
        end
        v.name = "solar-dev#{index}"
      end

      config.vm.provider :libvirt do |libvirt|
        libvirt.driver = 'kvm'
        libvirt.memory = SLAVES_RAM
        libvirt.cpus = SLAVES_CPUS
        libvirt.nested = true
        libvirt.cpu_mode = 'host-passthrough'
        libvirt.volume_cache = 'unsafe'
        libvirt.disk_bus = "virtio"
      end

      if PREPROVISIONED
        if SYNC_TYPE == 'nfs'
          config.vm.synced_folder ".", "/vagrant", type: "nfs"
        end
        if SYNC_TYPE == 'rsync'
          config.vm.synced_folder ".", "/vagrant", type: "rsync",
          rsync__args: ["--verbose", "--archive", "--delete", "-z"]
        end
      end
    end
  end

end


def boot_order(virt_config, order)
  # Boot order is specified with special flag:
  # --boot<1-4> none|floppy|dvd|disk|net
  4.times do |idx|
    device = order[idx] || 'none'
    virt_config.customize ['modifyvm', :id, "--boot#{idx + 1}", device]
  end
end
