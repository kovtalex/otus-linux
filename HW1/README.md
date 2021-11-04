# HW1 - Сборка ядра

## Установка ПО

* Vagrant

```bash
brew install vagrant
```

* Packer

```bash
brew install packer
```

## Kernel update

### Клонирование и запуск

Для запуска рабочего виртуального окружения необходимо зайти через браузер в GitHub под своей учетной записью и выполнить fork данного репозитория: <https://github.com/dmitry-lyutenko/manual_kernel_update>

После этого данный репозиторий необходимо склонировать к себе на рабочую машину. Для этого воспользуемся ранее установленным приложением git, при этом в <user_name> будет имя уже нашего репозитрия:

```bash
git clone git@github.com:kovtalex/manual_kernel_update.git
```

В текущей директории появится папка с именем репозитория. В данном случае manual_kernel_update. Ознакомимся с содержимым:

```bashcd manual_kernel_update
ls -1
manual
packer
Vagrantfile
```

Здесь:

* manual - директория с данным руководством
* packer - директория со скриптами для packer'а
* Vagrantfile - файл описывающий виртуальную инфраструктуру для Vagrant

Запустим виртуальную машину и залогинимся:

```bash
vagrant up
vagrant ssh
```

Теперь приступим к обновлению ядра.

### kernel update

Посмотрим на версию ядра.

```bash
uname -sr
Linux 3.10.0-1127.el7.x86_64
```

Подключаем репозиторий, откуда возьмем необходимую версию ядра.

```bash
sudo yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
```

Поскольку мы ставим ядро из репозитория, то установка ядра похожа на установку любого другого пакета, но потребует явного включения репозитория при помощи ключа --enablerepo.

Ставим последнее ядро:

```bash
sudo yum --enablerepo elrepo-kernel install kernel-ml -y

Installed:
  kernel-ml.x86_64 0:5.15-1.el7.elrepo

Complete!
```

### grub update

После успешной установки нам необходимо сказать системе, что при загрузке нужно использовать новое ядро. В случае обновления ядра на рабочих серверах необходимо перезагрузиться с новым ядром, выбрав его при загрузке. И только при успешно прошедшей загрузке нового ядра и тестах сервера переходить к загрузке с новым ядром по-умолчанию. В тестовой среде можно обойти данный этап и сразу назначить новое ядро по-умолчанию.

Обновляем конфигурацию загрузчика:

```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

Generating grub configuration file ...
Found linux image: /boot/vmlinuz-5.15.0-1.el7.elrepo.x86_64
Found initrd image: /boot/initramfs-5.15.0-1.el7.elrepo.x86_64.img
Found linux image: /boot/vmlinuz-3.10.0-1127.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1127.el7.x86_64.img
done
```

Выбираем загрузку с новым ядром по-умолчанию:

```bash
sudo grub2-set-default 0
```

Перезагружаем виртуальную машину:

```bash
sudo reboot

После перезагрузки виртуальной машины (3-4 минуты, зависит от мощности хостовой машины) заходим в нее и выполняем:

```bash
vagrant ssh

uname -sr
Linux 5.15.0-1.el7.elrepo.x86_64
```

## Packer

Теперь необходимо создать свой образ системы, с уже установленым ядром 5й версии. Для это воспользуемся ранее установленной утилитой packer. В директории packer есть все необходимые настройки и скрипты для создания необходимого образа системы.

Создаем переменные (variables) с версией и названием нашего проекта (artifact):

```bash
    "artifact_description": "CentOS 7.9 - 5.15",
    "artifact_version": "7.9.2009",
```

В секции builders задаем исходный образ, для создания своего в виде ссылки и контрольной суммы. Параметры подключения к создаваемой виртуальной машине.

```bash
      "iso_checksum": "sha256:07b94e6b1a0b0260b94c83d6bb76b26bf7a310dc78d7a9c7432809fb9bc6194a",
      "iso_url": "http://mirror.corbina.net/pub/Linux/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso",
```

В секции post-processors указываем имя файла, куда будет сохранен образ, в случае успешной сборки

```bash
      "output": "centos-{{user `artifact_version`}}-kernel-5-x86_64-Minimal.box",
```

В секции provisioners указываем каким образом и какие действия необходимо произвести для настройки виртуальой машины. Именно в этой секции мы и обновим ядро системы, чтобы можно было получить образ с 5й версией ядра. Настройка системы выполняется несколькими скриптами, заданными в секции scripts.

```bash
    "scripts" : 
      [
        "scripts/stage-1-kernel-update.sh",
        "scripts/stage-2-clean.sh"
      ]
```

### packer build

Для создания образа системы достаточно перейти в директорию packer и в ней выполнить команду:

```bash
packer build centos.json 

==> Wait completed after 24 minutes 34 seconds

==> Builds finished. The artifacts of successful builds are:
--> centos-7.9: 'virtualbox' provider box: centos-7.9.2009-kernel-5-x86_64-Minimal.box
```

Если все в порядке, то, согласно файла config.json будет скачан исходный iso-образ CentOS, установлен на виртуальную машину в автоматическом режиме, обновлено ядро и осуществлен экспорт в указанный нами файл. Если не вносилось изменений в предложенные файлы, то в текущей директории мы увидим файл centos-7.9.2009-kernel-5-x86_64-Minimal.box Он и является результатом работы packer.

## vagrant init (тестирование)

Проведем тестирование созданного образа. Выполним его импорт в vagrant:

```bash
vagrant box add --name centos-7-9 centos-7.9.2009-kernel-5-x86_64-Minimal.box
```

Проверим его в списке имеющихся образов:

```bash
vagrant box list
centos-7-9      (virtualbox, 0)
centos/7        (virtualbox, 2004.01)
```

Он будет называться centos-7-9, данное имя мы задали при помощи параметра name при импорте.

Теперь необходимо провести тестирование полученного образа. Для этого создадим новый Vagrantfile.

Запустим виртуальную машину, подключимся к ней и проверим, что у нас в ней новое ядро:

```bash
vagrant up
vagrant ssh

uname -sr
Linux 5.15.0-1.el7.elrepo.x86_64
```

Если все в порядке, то машина будет запущена и загрузится с новым ядром.

Удалим тестовый образ из локального хранилища:

```bash
vagrant destroy
vagrant box remove centos-7-9
```

## Vagrant Cloud

Поделимся полученным образом с сообществом. Для этого зальем его в Vagrant Cloud. Можно залить через web-интерфейс, но так же vagrant позволяет это проделать через CLI. Логинимся в vagrant cloud, указывая e-mail, пароль и описание выданого токена (можно оставить по-умолчанию).

```bash
vagrant cloud auth login
```

Теперь публикуем полученный бокс в [vagrant cloud](https://app.vagrantup.com/kovtalex/boxes/centos-7.9/versions/1.0.0/providers/virtualbox.box):

```bash
vagrant cloud publish --release kovtalex/centos-7.9 1.0.0 virtualbox centos-7.9.2009-kernel-5-x86_64-Minimal.box

Complete! Published kovtalex/centos-7.9
Box:              kovtalex/centos-7.9
Description:      
Private:          yes
Created:          2021-11-04T15:47:02.573Z
Updated:          2021-11-04T15:47:02.573Z
Current Version:  N/A
Versions:         1.0.0
Downloads:        0
```

Здесь:

```bash
cloud publish - загрузить образ в облако;
release - указывает на необходимость публикации образа после загрузки;
<username>/centos-7-9 - username, указаный при публикации и имя образа;
1.0 - версия образа;
virtualbox - провайдер;
centos-7.9.2009-kernel-5-x86_64-Minimal.box - имя файла загружаемого образа;
```

## Задание со * и **

Соберем ядро из исходников и добавим поддержку VirtualBox Shared Folders.

[Каталог](./doublestar) с конфигурацией Vagrant и Packer

Для начала протестируем сборку в vagrant.

Запустим виртуальную машину и залогинимся:

```bash
vagrant up
vagrant ssh

sudo -s
```

Посмотрим на текущую версию ядра:

```bash
uname -sr
Linux 3.10.0-1127.el7.x86_64
```

Так как у нас старая версия gcc, что не подходит для сборки ядра, то используем более новую версию из SCL репозитория.

Подключам SCL Repository:

```bash
yum install centos-release-scl -y
yum clean all
yum install devtoolset-10-* -y
source scl_source enable devtoolset-10
```

Устанавливаем недостающие пакеты и тулзы:

```bash
yum install -y ncurses-devel make bc bison flex elfutils-libelf-devel openssl-devel grub2 wget rsync
```

Скачиваем необходимут версию исходных кодов ядра:

```bash
cd /usr/src/
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar -xvf linux-5.15.tar.xz
cd linux-5.15/
```

Копируем текущую конфигурацию ядра в каталог для сборки:

```bash
cp -v /boot/config-$(uname -r) /usr/src/linux-5.15/.config
```

Собираем и устанавливаем ядро незабыв установить headers (необходимы для компиляции vboxguest)

```bash
yes "" | make oldconfig
make -j $(nproc)

make headers_install
make -j $(nproc) modules_install
make install
```

```bash
cp -v .config /boot/config-5.15
```

Обновляем конфигурацию загрузчика и выбираем загрузку с новым ядром по-умолчанию:

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
```

Перезагружаемся:

```bash
shutdown -r now
```

Проверяем нашу версия ядра:

```bash
uname -sr
Linux 5.15
```

```bash
source scl_source enable devtoolset-10
```

Приступаем к сборке модуля vboxguest

```bash
cd /tmp
wget https://download.virtualbox.org/virtualbox/6.1.28/VBoxGuestAdditions_6.1.28.iso
mount VBoxGuestAdditions_6.1.28.iso /mnt
cd /mnt
./VBoxLinuxAdditions.run
cd
umount /mnt
```

Удаляем наш каталог с исходными кодами ядра:

```bash
rm -rf /usr/src/linux-5.15*
rm -rf /usr/src/kernels
```

Далее правим centos.json конфигурацию для packer, добавляем [скрипт](./doublestar/packer/scripts/stage-2-add-vboxguest.sh) сборки vboxguest и запускаем сборку ядра:

```bash
packer build -timestamp-ui centos.json | tee log.txt

==> Wait completed after 2 hours 10 minutes

==> Builds finished. The artifacts of successful builds are:
--> centos-7.9: 'virtualbox' provider box: centos-7.9.2009-kernel-5-x86_64-Minimal-vboxguest.box
```

Тестируем работу нашего нового образа незабыв включить synced_folder в Vagrantfile:

```bash
vagrant box add --name centos-7-9 centos-7.9.2009-kernel-5-x86_64-Minimal-vboxguest.box

vagrant up
vagrant ssh

uname -sr
Linux 5.15.0
```

Проверяем, что модуль vboxguest успешно загружен:

```bash
lsmod | grep vboxguest
vboxguest             425984  2 vboxsf
```

Публикуем наш образ в [vagrant cloud](https://app.vagrantup.com/kovtalex/boxes/centos-7.9_vboxguest/versions/1.0.0/providers/virtualbox.box):

```bash
vagrant cloud publish --release kovtalex/centos-7.9_vboxguest 1.0.0 virtualbox centos-7.9.2009-kernel-5-x86_64-Minimal-vboxguest.box
```
