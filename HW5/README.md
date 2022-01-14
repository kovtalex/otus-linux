# HW5 - Vagrant стенд для NFS

## Цели домашнего задания

Научиться самостоятельно развернуть сервис NFS и подключить к нему клиента

## Описание домашнего задания

Основная часть:

- `vagrant up` должен поднимать 2 настроенных виртуальных машины (сервер NFS и клиента) без дополнительных ручных действий
- на сервере NFS должна быть подготовлена и экспортирована директория
- в экспортированной директории должна быть поддиректория с именем **upload** с правами на запись в неё
- экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальноймашины (systemd, autofs или fstab - любым способом)
- монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3 по протоколу UDP
- firewall должен быть включен и настроен как на клиенте, так и на сервере

Для самостоятельной реализации:

- настроить аутентификацию через KERBEROS с использованием NFSv4

## Пошаговая инструкция выполнения домашнего задания

### 1. Подготовка

Требуется предварительно установленный и работоспособный [Hashicorp Vagrant](https://www.vagrantup.com/downloads) и [Oracle VirtualBox] (<https://www.virtualbox.org/wiki/Linux_Downloads>). Также имеет смысл предварительно загрузить образ CentOS 7 2004.01 из Vagrant Cloud командой

```bash
vagrant box add centos/7 --provider virtualbox --box-version 2004.01 --clean
```

> т.к. предполагается, что дальнейшие действия будут производиться на таких образах

### 2. Создаём тестовые виртуальные машины

- Для начала, предлагается использовать этот шаблон для создания виртуальных машин

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.box_version = "2004.01"

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 1
  end

  config.vm.define "nfss" do |nfss|
    nfss.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    nfss.vm.hostname = "nfss"
  end

  config.vm.define "nfsc" do |nfsc|
    nfsc.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "net1"
    nfsc.vm.hostname = "nfsc"
  end
end
```

> Результатом выполнения команды `vagrant up` станут 2 виртуальных машины: **nfss** для сервера NFS и **nfsc** для клиента

### 3. Настраиваем сервер NFS

- заходим на сервер

```bash
vagrant ssh nfss
```

Дальнейшие действия выполняются **от имени пользователя имеющего повышенные привилегии**, разрешающие описанные действия.

- сервер NFS уже установлен в CentOS 7 как часть дистрибутива, так что нам нужно лишь доустановить утилиты, которые облегчат отладку

```bash
sudo -i
yum install nfs-utils -y
```

- включаем firewall и проверяем, что он работает (доступ к SSH обычно включен по умолчанию, поэтому здесь мы его не затрагиваем, но имем это ввиду, если настраиваем firewall с нуля)

```bash
systemctl enable firewalld --now
systemctl status firewalld
```

- разрешаем в firewall доступ к сервисам NFS

```bash
firewall-cmd --add-service="nfs3" \
--add-service="rpc-bind" \
--add-service="mountd" \
--permanent
firewall-cmd --reload
```

- включаем сервер NFS (для конфигурации NFSv3 over UDP он не требует дополнительной настройки, однако мы можем ознакомиться с умолчаниями в файле **/etc/nfs.conf**)

```bash
systemctl enable nfs --now
```

- проверяем наличие слушаемых портов 2049/udp, 2049/tcp, 20048/udp, 20048/tcp, 111/udp, 111/tcp (не все они будут использоваться далее, но их наличие сигнализирует о том, что необходимые сервисы готовы принимать внешние подключения)

```bash
ss -tnplu | grep -E '2049|20048|111'

udp    UNCONN     0      0         *:2049                  *:*                  
udp    UNCONN     0      0         *:20048                 *:*                   users:(("rpc.mountd",pid=3590,fd=7))
udp    UNCONN     0      0         *:111                   *:*                   users:(("rpcbind",pid=340,fd=6))
udp    UNCONN     0      0      [::]:2049               [::]:*                  
udp    UNCONN     0      0      [::]:20048              [::]:*                   users:(("rpc.mountd",pid=3590,fd=9))
udp    UNCONN     0      0      [::]:111                [::]:*                   users:(("rpcbind",pid=340,fd=9))
tcp    LISTEN     0      128       *:111                   *:*                   users:(("rpcbind",pid=340,fd=8))
tcp    LISTEN     0      128       *:20048                 *:*                   users:(("rpc.mountd",pid=3590,fd=8))
tcp    LISTEN     0      64        *:2049                  *:*                  
tcp    LISTEN     0      128    [::]:111                [::]:*                   users:(("rpcbind",pid=340,fd=11))
tcp    LISTEN     0      128    [::]:20048              [::]:*                   users:(("rpc.mountd",pid=3590,fd=10))
```

- создаём и настраиваем директорию, которая будет экспортирована в будущем

```bash
mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload
```

- создаём в файле /etc/exports структуру, которая позволит экспортировать ранее созданную директорию

```bash
cat << EOF > /etc/exports
/srv/share 192.168.50.11/32(rw,sync,root_squash)
EOF
```

- экспортируем ранее созданную директорию

```bash
exportfs -r
```

- проверяем экспортированную директорию следующей командой

```bash
exportfs -s

/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

### 4. Настраиваем клиент NFS

- заходим на клиент

```bash
vagrant ssh nfsc
```

> Дальнейшие действия выполняются **от имени пользователя имеющего повышенные привилегии**, разрешающие описанные действия

- доустановим вспомогательные утилиты

```bash
yum install nfs-utils -y
```

- включаем firewall и проверяем, что он работает (доступ к SSH обычно включен по умолчанию, поэтому здесь мы его не затрагиваем, но имеем это ввиду, если настраивам firewall с нуля)

```bash
systemctl enable firewalld --now
systemctl status firewalld
```

- добавляем в /etc/fstab строку

```bash
echo "192.168.50.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
```

- и выполняем

```bash
systemctl daemon-reload
systemctl restart remote-fs.target
```

> Отметим, что в данном случае происходит автоматическая генерация systemd units в каталоге `/run/systemd/generator/`, которые производят монтирование при первом обращении к каталогу `/mnt/`

```bash
cat /run/systemd/generator/mnt.mount 

# Automatically generated by systemd-fstab-generator

[Unit]
SourcePath=/etc/fstab
Documentation=man:fstab(5) man:systemd-fstab-generator(8)

[Mount]
What=192.168.50.10:/srv/share/
Where=/mnt
Type=nfs
Options=vers=3,proto=udp,noauto,xsystemd.automount
```

- заходим в директорию `/mnt/` и проверяем успешность монтирования

```bash
ls /mnt
mount | grep mnt
```

- При успехе вывод должен примерно соответствовать этому

```bash
mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=25,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=20327)
192.168.50.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.50.10)
```

> Обратим внимание на `vers=3` и `proto=udp`, что соответствует NFSv3 over UDP, как того требует задание

### 5. Проверка работоспособности

- заходим на сервер
- заходим в каталог

```bash
cd /srv/share/upload
```

- создаём тестовый файл

```bash
touch check_file
```

- заходим на клиент
- заходим в каталог

```bash
cd /mnt/upload
```

- проверяем наличие ранее созданного файла

```bash
ls
check_file
```

- создаём тестовый файл

```bash
touch client_file
```

- проверяем, что файл успешно создан и доступен на сервере

```bash
ls
check_file  client_file
```

> Если вышеуказанные проверки прошли успешно, это значит, что проблем с правами нет.

Предварительно проверяем клиент:

- перезагружаем клиент
- заходим на клиент
- заходим в каталог

```bash
cd /mnt/upload
```

- проверяем наличие ранее созданных файлов

```bash
ls
check_file  client_file
```

Проверяем сервер:

- заходим на сервер в отдельном окне терминала
- перезагружаем сервер
- заходим на сервер
- проверяем наличие файлов в каталоге

```bash
cd /srv/share/upload/
ls
check_file  client_file
```

- проверяем статус сервера NFS

```bash
systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
   Active: active (exited) since Wed 2021-12-15 22:01:53 UTC; 1h 4min ago
  Process: 3609 ExecStartPost=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
  Process: 3592 ExecStart=/usr/sbin/rpc.nfsd $RPCNFSDARGS (code=exited, status=0/SUCCESS)
  Process: 3591 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
 Main PID: 3592 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

Dec 15 22:01:53 nfss systemd[1]: Starting NFS server ...
Dec 15 22:01:53 nfss systemd[1]: Started NFS server a...
Hint: Some lines were ellipsized, use -l to show in full.
```

- проверяем статус firewall

```bash
systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2021-12-15 22:30:25 UTC; 35min ago
     Docs: man:firewalld(1)
 Main PID: 22479 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─22479 /usr/bin/python2 -Es /usr/sbin/fir...

Dec 15 22:30:25 nfss systemd[1]: Starting firewalld -...
Dec 15 22:30:25 nfss systemd[1]: Started firewalld - ...
Dec 15 22:30:25 nfss firewalld[22479]: WARNING: Allow...
Hint: Some lines were ellipsized, use -l to show in full.
```

- проверяем экспорты

```bash
exportfs -s
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

- проверяем работу RPC

```bash
showmount -a 192.168.50.10

All mount points on 192.168.50.10:
192.168.50.11:/srv/share
```

Проверяем клиент:

- возвращаемся на клиент
- перезагружаем клиент
- заходим на клиент
- проверяем работу RPC

```bash
showmount -a 192.168.50.10
All mount points on 192.168.50.10:
192.168.50.11:/srv/share
```

- заходим в каталог

```bash
cd /mnt/upload
```

- проверяем статус монтирования

```bash
mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=33,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=10916)
192.168.50.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.50.10)
```

- проверяем наличие ранее созданных файлов
- создаём тестовыйфайл

```bash
touch final_check
```

- проверяем, что файл успешно создан

```bash
check_file  client_file  final_check
```

> Если вышеуказанные проверки прошли успешно, это значит, что демонстрационныйстенд работоспособен и готов к работе

### 6. Создание автоматизированного Vagrantfile

- Ранее предложенный Vagrantfile предлагается дополнить до такого

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.box_version = "2004.01"

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
   v.cpus = 1
  end

  config.vm.define "nfss" do |nfss|
    nfss.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "net1"
    nfss.vm.hostname = "nfss"
    nfss.vm.provision "shell", path: "nfss_script.sh"
  end

  config.vm.define "nfsc" do |nfsc|
    nfsc.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "net1"
    nfsc.vm.hostname = "nfsc"
    nfsc.vm.provision "shell", path: "nfsc_script.sh"
  end
end
```

### Далее создадим 2 bash-скрипта, `nfss_script.sh` - для конфигурирования сервера и `nfsc_script.sh` - для конфигурирования клиента, в которых опищем bash-командами ранее выполненные шаги

nfss_script.sh

```bash
#!/bin/bash

yum install nfs-utils -y

systemctl enable firewalld --now
systemctl status firewalld

firewall-cmd --add-service="nfs3" \
--add-service="rpc-bind" \
--add-service="mountd" \
--permanent
firewall-cmd --reload

systemctl enable nfs --now

mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload

cat << EOF > /etc/exports
/srv/share 192.168.50.11/32(rw,sync,root_squash)
EOF

exportfs -r
```

nfsc_script.sh

```bash
yum install nfs-utils -y

systemctl enable firewalld --now
systemctl status firewalld

echo "192.168.50.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab

systemctl daemon-reload
systemctl restart remote-fs.target
```

### Теперь уничтожим тестовый стенд командой `vagrant destory -f`, создадим его заново и выполним все пункты из пункта 5 - проверка работоспособности, убедимся, что всё работает как задумывалось и требуется
