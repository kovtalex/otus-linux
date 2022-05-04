Vagrant.configure("2") do |config|

  config.vm.synced_folder ".", "/vagrant"   

  config.vm.provision "shell", inline: <<-SHELL
    yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
    yum install -y Percona-Server-server-57
    SHELL


  config.vm.define "master" do |master|
    master.vm.box = "centos/7"
    master.vm.box_url = 'https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-2004_01.VirtualBox.box'
    master.vm.box_download_checksum = '7e83943defcb5c4e9bebbe4184cce4585c82805a15e936b01b1e893b63dee2c5'
    master.vm.box_download_checksum_type = 'sha256'
      
    master.vm.host_name = 'master'  
    master.vm.network :private_network, ip: "192.168.56.11"

    master.vm.provider "virtualbox" do |vbx|
      vbx.memory = "512"
      vbx.cpus = "1"
        vbx.customize ["modifyvm", :id, '--audio', 'none']
    end     
  end

  config.vm.define "slave" do |slave|
    slave.vm.box = "centos/7"
    slave.vm.box_url = 'https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-2004_01.VirtualBox.box'
    slave.vm.box_download_checksum = '7e83943defcb5c4e9bebbe4184cce4585c82805a15e936b01b1e893b63dee2c5'
    slave.vm.box_download_checksum_type = 'sha256'
      
    slave.vm.host_name = 'slave'  
    slave.vm.network :private_network, ip: "192.168.56.12"

    slave.vm.provider "virtualbox" do |vbx|
      vbx.memory = "512"
      vbx.cpus = "1"
      vbx.customize ["modifyvm", :id, '--audio', 'none']
    end     
  end
end
