# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
require 'yaml'

Vagrant.require_version ">= 1.8.0"

CONFIG = File.join(File.dirname(__FILE__), "vagrant/config.rb")

# Defaults for config options defined in CONFIG
$num_instances = 3
$instance_name_prefix = "node"
$vm_gui = false
$vm_memory = 2048
$vm_cpus = 1
$shared_folders = {}
$forwarded_ports = {}
$subnet_prefix = "172.17"
$public_subnet = "#{$subnet_prefix}.0"
$private_subnet = "#{$subnet_prefix}.1"
$mgmt_cidr = "#{$subnet_prefix}.2.0/24"
# Must contain string debian or ubuntu
# Has memory cgroups set wrong
#$box = "debian/jessie64"
#$box = "yk0/ubuntu-xenial"
$box = "adidenko/ubuntu-1604-k8s"
#$box = "bento/ubuntu-16.04"
$kube_version = "v1.3.0"

host_vars = {}
node_ips = []

if File.exist?(CONFIG)
  require CONFIG
end

Vagrant.configure("2") do |config|
  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'
  config.vm.box = $box

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  ($num_instances.downto(1)).each do |i|
    config.vm.define vm_name = "%s%02d" % [$instance_name_prefix, i] do |config|
      config.vm.box = $box
      config.vm.hostname = vm_name

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v|
          v.vmx['memsize'] = $vm_memory
          v.vmx['numvcpus'] = $vm_cpus
        end
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = $vm_gui
        vb.memory = $vm_memory
        vb.cpus = $vm_cpus
      end

      config.vm.provider :libvirt do |domain|
        domain.uri = "qemu+unix:///system"
        domain.memory = $vm_memory
        domain.cpus = $vm_cpus
        domain.driver = "kvm"
        domain.host = "localhost"
        domain.connect_via_ssh = false
        domain.username = $user
        domain.storage_pool_name = "default"
        domain.nic_model_type = "e1000"
        domain.management_network_name = "#{$instance_name_prefix}-mgmt-net"
        domain.management_network_address = $mgmt_cidr
        domain.nested = true
        domain.cpu_mode = "host-passthrough"
        domain.volume_cache = "unsafe"
        domain.disk_bus = "virtio"
      end

      # Networks and interfaces
      ip = "#{$private_subnet}.#{i+10}"
      pub_ip = "#{$public_subnet}.#{i+10}"
      # "public" network with nat forwarding
      config.vm.network :private_network,
        :ip => pub_ip,
        :model_type => "e1000",
        :libvirt__network_name => "#{$instance_name_prefix}-public",
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "nat"
      # "private" isolated network
      config.vm.network :private_network,
        :ip => ip,
        :model_type => "e1000",
        :libvirt__network_name => "#{$instance_name_prefix}-private",
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"

      node_ips << ip

      host_vars[vm_name] = {
        "ip" => ip,
        "access_ip" => ip,
        "cloud_provider" => "generic",
        "kube_proxy_mode" => "iptables",
        "kube_network_plugin" => "calico",
        "kube_version" => $kube_version,
        "local_release_dir" => "/vagrant/temp",
        "download_run_once" => "True"
      }

      # Only execute once the Ansible provisioner,
      # when all the machines are up and ready.
      if i == 1
        # Run kargo_deploy.sh
        image_name = $box.sub('/','_')
        deploy = <<SCRIPT
export KARGO_REPO="#{ENV['KARGO_REPO']}"
export KARGO_COMMIT="#{ENV['KARGO_REPO']}"
export CUSTOM_YAML="---
cloud_provider : \"generic\"
kube_proxy_mode:  \"iptables\"
kube_network_plugin: \"calico\"
kube_version: \"#{$kube_version}\"
etcd_deployment_type: \"host\""
export SLAVE_IPS="#{node_ips.join(' ')}"
export ADMIN_IP="#{ip}"
export IMAGE_PATH="#{image_name}"
#echo bash /vagrant/utils/packer/debian8.5/scripts/setup.sh
#echo bash /vagrant/utils/packer/debian8.5/scripts/packages.sh
echo bash /vagrant/utils/packer/ubuntu16.04/scripts/setup.sh
bash /vagrant/utils/packer/ubuntu16.04/scripts/packages.sh
bash /vagrant/utils/jenkins/kargo_deploy.sh
SCRIPT
        config.vm.provision "shell", inline: "bash -x #{deploy}"
      end
    end
  end
end

