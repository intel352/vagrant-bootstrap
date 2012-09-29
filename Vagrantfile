# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'erb'

Vagrant::Config.run do |config|
  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.network :hostonly, "192.168.33.100"
  config.vm.network :bridged

  # Use ssh-agent?
  config.ssh.forward_agent = true

  # Allow symlinks that affect the host machine? Might not work in Windows
  #config.vm.customize([
  #  'setextradata',
  #  :id,
  #  'VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root',
  #  '1'
  #])

  # Import Vagrantfile.local, and run provision.sh
  config.vm.provision :shell do |shell|
    load 'Vagrantfile.local.default'
    if File.exists?('Vagrantfile.local')
      load 'Vagrantfile.local'
    end
    script       = 'provision.sh'

    def render file
      ERB.new(File.read("#{@relative}#{file}")).result(binding)
    end

    shell.inline = render script
  end
end