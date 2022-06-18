# HW22 - VPN

## Задание

- Между двумя виртуалками поднять vpn в режимах:
  - tun
  - tap

Описать в чём разница, замерить скорость между виртуальными машинами в туннелях, сделаь вывод об отличающихся показателях скорости.

- Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку

## TUN/TAP режимы VPN

### Для выполнения первого пункта необходимо написать Vagrantfile, который будет поднимать 2 виртуальные машины server и client

Типовой Vagrantfile для данной задачи:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
    config.vm.box = "centos/7"    
    config.vm.box_url = 'https://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-2004_01.VirtualBox.box'
    config.vm.box_download_checksum = '7e83943defcb5c4e9bebbe4184cce4585c82805a15e936b01b1e893b63dee2c5'
    config.vm.box_download_checksum_type = 'sha256'

    config.vm.define "server" do |server|
        server.vm.hostname = "server.loc"
        server.vm.network "private_network", ip: "192.168.56.10"
    end
    
    config.vm.define "client" do |client|
        client.vm.hostname = "client.loc"
        client.vm.network "private_network", ip: "192.168.56.11"
    end
end
```

> Можно использовать готовый playbook, который раскатает сервер и клиент OpenVPN дополнив наш Vagrantfile

```bash
    config.vm.provision "ansible" do |ansible|
        ansible.playbook = "playbook.yml"
        ansible.become = true
        ansible.limit = "all"
        ansible.host_key_checking = "false"
    end  
```

### После запуска машин из Vagrantfile выполняем следующие действия на server и client машинах

- устанавливаем epel репозиторий

```bash
yum install -y epel-release
```

- устанавливаем пакет openvpn, easy-rsa и iperf3

```bash
yum install -y openvpn iperf3
```

- Отключаем SELinux (при желании можно написать правило для openvpn)

```bash
setenforce 0
```

> Работает до ребута

### Настройка openvpn сервера

- создаем файл ключ

```bash
openvpn --genkey --secret /etc/openvpn/static.key
```

- создаём конфигурационный файл vpn-сервера

```bash
vi /etc/openvpn/server.conf

dev tap
ifconfig 10.10.10.1 255.255.255.0
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

- Запускаем openvpn сервер и добавлāем в автозагрузку

```bash
systemctl start openvpn@server
systemctl enable openvpn@server
```

### Настройка openvpn клиента

```bash
vi /etc/openvpn/server.conf

dev tap
remote 192.168.56.10
ifconfig 10.10.10.2 255.255.255.0
topology subnet
route 192.168.56.0 255.255.255.0
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

- На сервер клиента в директории /etc/openvpn/ скопируем файл-ключ static.key, который был создан на сервере

- Запускаем openvpn клиент и добавляем в автозагрузку

```bash
systemctl start openvpn@server
systemctl enable openvpn@server
```

### Далее необходимо замерить скорость в туннеле

- на openvpn сервере запускаем iperf3 в режиме сервера

```bash
iperf3 -s &
```

- на openvpn клиенте запускаем iperf3 в режиме клиента и замеряем скорость в туннеле

```bash
iperf3 -c 10.10.10.1 -t 40 -i 5

Connecting to host 10.10.10.1, port 5201
[  4] local 10.10.10.2 port 48054 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-5.00   sec   112 MBytes   188 Mbits/sec   56    626 KBytes       
[  4]   5.00-10.00  sec   115 MBytes   193 Mbits/sec    5    630 KBytes       
[  4]  10.00-15.00  sec   114 MBytes   191 Mbits/sec    0    690 KBytes       
[  4]  15.00-20.00  sec   113 MBytes   189 Mbits/sec    0    801 KBytes       
[  4]  20.00-25.00  sec   111 MBytes   187 Mbits/sec   10    995 KBytes       
[  4]  25.00-30.01  sec   114 MBytes   192 Mbits/sec    0   1.24 MBytes       
[  4]  30.01-35.01  sec   109 MBytes   184 Mbits/sec    1   1.05 MBytes       
[  4]  35.01-40.00  sec   112 MBytes   188 Mbits/sec    0   1.07 MBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-40.00  sec   901 MBytes   189 Mbits/sec   72             sender
[  4]   0.00-40.00  sec   898 MBytes   188 Mbits/sec                  receiver

iperf Done.
```

### Повторяем пункты 1-5 для режима работы tun. Конфигурационные файлы сервера и клиента изменяться только в директиве dev. Делаем выводы о режимах, их достоинствах и недостатках

```bash
Connecting to host 10.10.10.1, port 5201
[  4] local 10.10.10.2 port 48058 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-5.01   sec   113 MBytes   190 Mbits/sec   78    433 KBytes       
[  4]   5.01-10.00  sec   118 MBytes   198 Mbits/sec    0    599 KBytes       
[  4]  10.00-15.00  sec   119 MBytes   199 Mbits/sec  130    445 KBytes       
[  4]  15.00-20.01  sec   117 MBytes   195 Mbits/sec    0    601 KBytes       
[  4]  20.01-25.01  sec   115 MBytes   194 Mbits/sec    1    617 KBytes       
[  4]  25.01-30.01  sec   115 MBytes   193 Mbits/sec  281    469 KBytes       
[  4]  30.01-35.00  sec   116 MBytes   196 Mbits/sec    0    622 KBytes       
[  4]  35.00-40.01  sec   112 MBytes   188 Mbits/sec    3    632 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-40.01  sec   925 MBytes   194 Mbits/sec  493             sender
[  4]   0.00-40.01  sec   924 MBytes   194 Mbits/sec                  receiver

iperf Done.
```

> В tun режиме чуть быстрее при проведение теста на виртуалках, но и много потерь пакетов.

## RAS на базе OpenVPN

Для выполнения данного задания можно восполязоваться Vagrantfile из 1 задания, только убрать 1 ВМ.

### После запуска ВМ отключаем SELinux или создаём правило для него

```bash
setenforce 0
```

### Устанавливаем репозиторий EPEL

```bash
yum install -y epel-release
```

### Устанавливаем необходимые пакеты

```bash
yum install -y openvpn easy-rsa
```

### Переходим в директорию /etc/openvpn/ и инициализируем pki

```bash
cd /etc/openvpn/
/usr/share/easy-rsa/3.0.8/easyrsa init-pki
```

### Сгенерируем необходимые ключи и сертификаты для сервера

```bash
echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa build-ca nopass
echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa gen-req server nopass
echo 'yes' | /usr/share/easy-rsa/3.0.8/easyrsa sign-req server server
/usr/share/easy-rsa/3.0.8/easyrsa gen-dh
openvpn --genkey --secret ta.key
```

### Сгенерируем сертификаты для клиента

```bash
echo 'client' | /usr/share/easy-rsa/3.0.8/easyrsa gen-req client nopass
echo 'yes' | /usr/share/easy-rsa/3.0.8/easyrsa sign-req client client
```

### Создадим конфигурационный файл /etc/openvpn/server.conf

```bash
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.10.10.0 255.255.255.0
#route 192.168.56.0 255.255.255.0
push "route 192.168.56.0 255.255.255.0"
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir /etc/openvpn/client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

### Зададим параметр iroute для клиента

```bash
echo 'iroute 192.168.56.0 255.255.255.0' > /etc/openvpn/client/client
```

### Запускаем openvpn сервер и добавляем в автозагрузку

```bash
systemctl start openvpn@server
systemctl enable openvpn@server
```

### Скопируем следующие файлы сертификатов и ключ для клиента на хостмашину

```bash
/etc/openvpn/pki/ca.crt
/etc/openvpn/pki/issued/client.crt
/etc/openvpn/pki/private/client.key
```

> Файлы рекомендуется расположить в той же директории, что и client.conf

### Создадим конфигурационный файл клиента client.conf на хост-машине

```bash
dev tun
proto udp
remote 192.168.56.10 1207
client
resolv-retry infinite
ca ./ca.crt
cert ./client.crt
key ./client.key
#route 192.168.56.0 255.255.255.0
persist-key
persist-tun
comp-lzo
verb 3
```

В этом конфигурационном файле указано, что файлы сертификатов располагаются в директории, где располагается client.conf. Но при желании можно разместить сертификаты в других директориях и в конфиге скорректировать пути.

### После того, как все готово, подключаемся к openvpn сервер с хост-машины

```bash
openvpn --config client.conf
```

### При успешном подключении проверяем пинг в внутреннему IP адресу сервера в туннеле

```bash
ping -c 4 10.10.10.1

PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.634 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.84 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.857 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=0.639 ms

--- 10.10.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3017ms
rtt min/avg/max/mdev = 0.634/0.994/1.847/0.500 ms
```

### Также проверяем командой ip r (netstat -rn) на хостовой машине, что сеть туннеля импортирована в таблицу маршрутизации

```bash
default via 10.0.2.2 dev eth0 proto dhcp metric 101 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 101 
10.10.10.0/24 via 10.10.10.5 dev tun0 
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
192.168.56.0/24 dev eth1 proto kernel scope link src 192.168.56.11 metric 100 
```
