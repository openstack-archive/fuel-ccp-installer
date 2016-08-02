# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'yaml'

Vagrant.require_version ">= 1.8.0"
defaults_cfg = YAML.load_file('vagrant-settings.yaml_defaults')
if File.exist?('vagrant-settings.yaml')
  custom_cfg = YAML.load_file('vagrant-settings.yaml')
  cfg = defaults_cfg.merge(custom_cfg)
else
  cfg = defaults_cfg
end

# Defaults for config options
$num_instances = (cfg['num_instances'] || 3).to_i
$kargo_node_index = (cfg['kargo_node_index'] || 1).to_i
$instance_name_prefix = cfg['instance_name_prefix'] || "node"
$vm_gui = cfg['vm_gui'] || false
$vm_memory = (cfg['vm_memory'] || 2048).to_i
$vm_cpus = (cfg['vm_cpus'] || 1).to_i
$vm_cpu_limit = (cfg['vm_cpu_limit'] || 1).to_i
$vm_linked_clone = cfg['vm_linked_clone'] || true
$forwarded_ports = cfg['forwarded_ports'] || {}
$subnet_prefix = cfg['subnet_prefix'] || "172.17"
$public_subnet = cfg['public_subnet'] || "#{$subnet_prefix}.0"
$private_subnet = cfg['private_subnet'] || "#{$subnet_prefix}.1"
$neutron_subnet = cfg['neutron_subnet'] || "#{$subnet_prefix}.3"
$mgmt_cidr = cfg['mgmt_cidr'] || "#{$subnet_prefix}.2.0/24"
$box = cfg['box']
$sync_type = cfg['sync_type'] || "rsync"

$kube_version = cfg['kube_version']
$kargo_repo = ENV['KARGO_REPO'] || cfg['kargo_repo']
$kargo_commit = ENV['KARGO_COMMIT'] || cfg['kargo_commit']
$cloud_provider = cfg['cloud_provider']
$kube_proxy_mode =  cfg['kube_proxy_mode'] || "iptables"
$kube_network_plugin = cfg['kube_network_plugin'] || "calico"
$etcd_deployment_type = cfg['etcd_deployment_type'] || "host"
$kube_hostpath_dynamic_provisioner = cfg['kube_hostpath_dynamic_provisioner'] || true
$ipip = cfg['ipip'] || false
$hyperkube_image_repo = cfg ['hyperkube_image_repo']
$hyperkube_image_tag = cfg['hyperkube_image_tag']

def with_env(filename, env=[])
  "#{env.join ' '} /bin/bash -x -c #{filename}"
end

Vagrant.configure("2") do |config|
  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'
  config.vm.box = $box

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  node_ips = []
  (1 .. $num_instances).each { |i| node_ips << "#{$private_subnet}.#{i+10}" }

  # Serialize nodes startup order for the virtualbox provider
  $num_instances.downto(1).each do |i|
    config.vm.define vm_name = "%s%d" % [$instance_name_prefix, i] do |config|
      if i != $kargo_node_index
        config.vm.provision "shell", inline: "/bin/true"
      else
        # Only execute once the Ansible provisioner on a kargo node,
        # when all the machines are up and ready.
        ip = "#{$private_subnet}.#{$kargo_node_index+10}"
        templ = {
          "kube_proxy_mode"                   => $kube_proxy_mode,
          "kube_network_plugin"               => $kube_network_plugin,
          "kube_version"                      => $kube_version,
          "kube_hostpath_dynamic_provisioner" => $kube_hostpath_dynamic_provisioner,
          "hyperkube_image_repo"              => $hyperkube_image_repo,
          "hyperkube_image_tag"               => $hyperkube_image_tag,
          "etcd_deployment_type"              => $etcd_deployment_type,
          "ipip"                              => $ipip
        }
        unless $cloud_provider.nil? or $cloud_provider.empty? or $cloud_provider == "none"
          templ.merge({"cloud_provider" => $cloud_provider})
        end
        yaml = templ.to_yaml
        vars = {
          "KARGO_REPO"   => $kargo_repo,
          "KARGO_COMMIT" => $kargo_commit,
          "SLAVE_IPS"    => "\"#{node_ips.join(' ')}\"",
          "ADMIN_IP"     => ip,
          "IMAGE_PATH"   => $box.sub('/','_'),
        }
        env = []
        vars.each { |k, v| env << "#{k}=#{v}" }

        deploy = with_env("/vagrant/utils/jenkins/kargo_deploy.sh",
          [env, "CUSTOM_YAML=\"#{yaml}\""].flatten)
        config.vm.provision "shell", inline: "#{deploy}"
      end
    end
  end

  # Define nodes configuration
  (1 .. $num_instances).each do |i|
    config.vm.define vm_name = "%s%d" % [$instance_name_prefix, i] do |config|
      config.vm.box = $box
      config.vm.hostname = vm_name

      # Networks and interfaces and ports
      ip = "#{$private_subnet}.#{i+10}"
      nets = [{:ip => ip, :name => "private",
               :mode => "none", :dhcp => false, :intnet => true},
              {:ip => "#{$public_subnet}.#{i+10}", :name => "public",
               :mode => "nat", :dhcp => false, :intnet => false},
              {:ip => "#{$neutron_subnet}.#{i+10}", :name => "neutron",
               :mode => "none", :dhcp => false, :intnet => true}]

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = $vm_gui
        vb.memory = $vm_memory
        vb.cpus = $vm_cpus
        vb.linked_clone = $vm_linked_clone
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{$vm_cpu_limit}"]
        vb.check_guest_additions = false
        vb.functional_vboxsf = false
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
        domain.graphics_ip = "0.0.0.0"
      end

      if $sync_type  == 'nfs'
        config.vm.synced_folder ".", "/vagrant", type: "nfs"
      end
      if $sync_type == 'rsync'
        config.vm.synced_folder ".", "/vagrant", type: "rsync",
          rsync__args: ["--verbose", "--archive", "--delete", "-z"],
          rsync__verbose: true, rsync__exclude: [".git/", ".tox/", "output*/",
          "packer_cache/"]
      end

      # This works for all providers
      nets.each do |net|
        config.vm.network :private_network,
          :ip => net[:ip],
          :model_type => "e1000",
          :libvirt__network_name => "#{$instance_name_prefix}-#{net[:name]}",
          :libvirt__dhcp_enabled => net[:dhcp],
          :libvirt__forward_mode => net[:mode],
          :virtualbox__intnet => net[:intnet]
      end
    end
  end

  # Force-plug nat devices to ensure an IP is assigned via DHCP
  config.vm.provider :virtualbox do |vb|
    vb.customize "post-boot",["controlvm", :id, "setlinkstate1", "on"]
  end
end
