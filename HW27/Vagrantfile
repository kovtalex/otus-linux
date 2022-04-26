Vagrant.configure("2") do |config|

    config.vm.define "db1" do |db1|
        db1.vm.box = 'bento/ubuntu-20.04'
        
        db1.vm.host_name = 'db1'  
        db1.vm.network :private_network, ip: "192.168.56.11"

        db1.vm.provider "virtualbox" do |vbx|
            vbx.memory = "512"
            vbx.cpus = "1"
            vbx.customize ["modifyvm", :id, '--audio', 'none']
        end        
    end

    config.vm.define "db2" do |db2|
        db2.vm.box = 'bento/ubuntu-20.04'
        
        db2.vm.host_name = 'db2'  
        db2.vm.network :private_network, ip: "192.168.56.12"

        db2.vm.provider "virtualbox" do |vbx|
            vbx.memory = "512"
            vbx.cpus = "1"
            vbx.customize ["modifyvm", :id, '--audio', 'none']
        end           
    end

    config.vm.define "db3" do |db3|
        db3.vm.box = 'bento/ubuntu-20.04'
        
        db3.vm.host_name = 'db3'  
        db3.vm.network :private_network, ip: "192.168.56.13"

        db3.vm.provider "virtualbox" do |vbx|
            vbx.memory = "512"
            vbx.cpus = "1"
            vbx.customize ["modifyvm", :id, '--audio', 'none']
        end           
    end

    config.vm.define "db4" do |db4|
        db4.vm.box = 'bento/ubuntu-20.04'
        
        db4.vm.host_name = 'db4'  
        db4.vm.network :private_network, ip: "192.168.56.14"

        db4.vm.provider "virtualbox" do |vbx|
            vbx.memory = "512"
            vbx.cpus = "1"
            vbx.customize ["modifyvm", :id, '--audio', 'none']
        end           
    end

    config.vm.provision "ansible" do |ansible|
        ansible.playbook = "playbook.yml"
        ansible.groups = {
          "db" => [
            "db1",
            "db2",
            "db3",
            "db4"
          ]
        }          
    end
    
end
