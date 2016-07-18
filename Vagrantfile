# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
require 'yaml'

Vagrant.require_version ">= 1.8.0"

CONFIG = File.join(File.dirname(__FILE__), "vagrant/config.rb")

# Defaults for config options defined in CONFIG
$num_instances = 1
$instance_name_prefix = "node"
$vm_gui = false
$vm_memory = 2048
$vm_cpus = 1
$shared_folders = {}
$forwarded_ports = {}
$subnet = "172.17.8"
# Must contain string debian or ubuntu
$box = "debian/jessie64"
$kube_version = "v1.3.0"

host_vars = {}
node_ips = []

if File.exist?(CONFIG)
  require CONFIG
end

# if $inventory is not set, try to use example
#$inventory = File.join(File.dirname(__FILE__), "inventory") if ! $inventory

# if $inventory has a hosts file use it, otherwise copy over vars etc
# to where vagrant expects dynamic inventory to be.
#if ! File.exist?(File.join(File.dirname($inventory), "hosts"))
#  $vagrant_ansible = File.join(File.dirname(__FILE__), ".vagrant",
#                       "provisioners", "ansible")
#  FileUtils.mkdir_p($vagrant_ansible) if ! File.exist?($vagrant_ansible)
#  if ! File.exist?(File.join($vagrant_ansible,"inventory"))
#    FileUtils.ln_s($inventory, $vagrant_ansible)
#  end
#end

Vagrant.configure("2") do |config|
  config.ssh.insert_key = true
  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'
  config.vm.box = $box

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  ($num_instances..1).each do |i|
    config.vm.define vm_name = "%s%02d" % [$instance_name_prefix, i] do |config|
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

      ip = "#{$subnet}.#{i+100}"
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
      ENV['CUSTOM_YAML'] = host_vars['node1'].to_yaml()
      config.vm.network :private_network, ip: ip

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
bash /vagrant/utils/packer/debian8.5/scripts/setup.sh
bash /vagrant/utils/packer/debian8.5/scripts/packages.sh
bash /vagrant/utils/jenkins/kargo_deploy.sh
SCRIPT
        config.vm.provision "shell", inline: deploy
      end
    end
  end
end

