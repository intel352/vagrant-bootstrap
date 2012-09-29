vagrant-bootstrap
===========

This is a bootstrap configuration for users wanting to launch a LAMP/LEMP stack in Vagrant as quickly as possible.
This configuration uses Shell provisioning, instead of Chef or Puppet, so that you still have easy provisioning but without having to learn a new process.

SSH-Agent Setup (if using SSH during repo init)
---------------

SSH-Agent is used with Vagrant for some task automation during provisioning.
You don't have to follow this process, but this is how I configured my ssh-agent setup on Mac OSX.

Edit SSH config to allow key forwarding for specific domains: ~/.ssh/config

    Host github.com
      ForwardAgent yes

Add default key, add ssh-agent to system startup, and start ssh-agent now.

    ssh-add -K ~/.ssh/id_rsa
    sudo launchctl load /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist
    sudo launchctl start org.openbsd.ssh-agent

Update /etc/hosts
-----------------

This vagrant image will provide you with multiple repository installations, but you need some way to access the repositories via browser.
Add the following line to your /etc/hosts file:

    192.168.33.100 <your project name>.vagrant

If you dislike the above IP for some reason, change the IP in your /etc/hosts, as well as in the `Vagrantfile` found in this repository.

Install Vagrant & it's dependencies
-----------------------------------

- VirtualBox 4.1 (4.2 is not yet supported): https://www.virtualbox.org/wiki/Downloads
- - VirtualBox 4.1.23 for OSX: http://download.virtualbox.org/virtualbox/4.1.22/VirtualBox-4.1.23-80870-OSX.dmg
- Vagrant: http://downloads.vagrantup.com/tags/v1.0.5
- - Vagrant 1.0.5 for OSX: http://files.vagrantup.com/packages/be0bc66efc0c5919e92d8b79e973d9911f2a511f/Vagrant-1.0.5.dmg

Once you have installed Vagrant, I highly recommend installing the `vagrant-vbguest` gem by running the following command:

    vagrant gem install vagrant-vbguest

The `vagrant-vbguest` gem helps to keep your Vagrant instance compatible with the version of VirtualBox that you're running.

NOTE: As of 9/26/2012, VirtualBox 4.2 is not yet supported by a packaged release of Vagrant.
If you already have/use VirtualBox 4.2, you'll need to install Vagrant from it's Github repository. Follow the instructions provided in the README: https://github.com/mitchellh/vagrant

Customize `Vagrantfile.local` (optional)
----------------------------------

`Vagrantfile.local.default` has been provided as a file allowing variable customizations, for local configurations that shouldn't be propagated to Git.
To do so, copy `Vagrantfile.local.default` to `Vagrantfile.local`, and customize the provided variables as needed.
The file `Vagrantfile.local` is already ignored by Git.

    @relative   = '' # This would contain the relative path to provision.sh, from Vagrantfile. Same directory, so it's empty by default
    @gitUri     = 'git://github.com/yiisoft/'  # Currently configured for the yii example provided in this project

Launch Vagrant:
---------------

Simply run:

    vagrant up

If you need to re-provision the existing image that is already running, you can run:

    vagrant provision

To access your vagrant instance via ssh:

    vagrant ssh

To pause or stop the instance:

    vagrant suspend   #pause
    vagrant halt      #shutdown

You can resume from a `suspend` or `halt` by simply running the `up` command again.
    
To get rid of the instance:

    vagrant destroy
