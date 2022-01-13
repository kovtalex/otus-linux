# HW7 - Работа с загрузчиком

## Задание

1. Попасть в систему без пароля несколькими способами
2. Установить систему с LVM, после чего переименовать VG
3. Добавить модуль в initrd

## Попадем в систему без пароля несколькими способами

Длā получения доступа необходимо открыть **GUI VirtualBox** (или другой системы виртуализации), запустить виртуальную машину и при выборе ядра для загрузки нажать **e** - в данном контексте edit. Попадаем в окно где мы можем изменить параметры загрузки.

### Способ 1. init=/bin/sh

- В конце строки начинающейся с **linux16** добавляем **init=/bin/sh** и нажимаем **сtrl-x** для загрузки в систему
- В целом на этом все, мы попали в систему. Но есть один нюанс. Рутовая файловая система при этом монтируется в режиме **Read-Only**. Если мы хотим перемонтировать ее в режим **Read-Write** можно воспользоваться командой:

```bash
mount -o remount,rw /
```

- После чего можно убедиться, записав данные в любой файл или прочитав вывод команды:

```bash
mount | grep root
```

### Способ 2. rd.break

- В конце строки начинающейся с **linux16** добавляем **rd.break** и нажимаем **сtrl-x** для загрузки в систему
- Попадаем в emergency mode. Наша корневая файловая система смонтирована (опять же в режиме **Read-Only**, но мы не в ней. Далее будет пример как попасть в нее и поменять пароль администратора:

```bash
mount -o remount,rw /sysroot
chroot /sysroot
passwd root
touch /.autorelabel
```

- После чего можно перезагружаться и заходитþ в систему с новым паролем. Полезно когда мы потеряли или вообще не имели пароль администратора.

### Способ 3. rw init=/sysroot/bin/sh

- В строке начинающейся с **linux16** заменяем **ro** на r**w init=/sysroot/bin/sh** и нажимаем **сtrl-x** для загрузки в систему
- В целом то же самое что и в прошлом примере, но файловая система сразу смонтирована в режим Read-Write
- В прошлых примерах тоже можно заменить **ro** на **rw**

## Установим систему с LVM, после чего переименуем VG

- Первым делом посмотрим текущее состояние системы:

```bash
vgs
```

- Нас интересует вторая строка с именем **Volume Group**
- Приступим к переименованию:

```bash
vgrename VolGroup00 OtusRoot
```

- Далее правим [/etc/fstab](https://gist.github.com/lalbrekht/cdf6d745d048009dbe619d9920901bf9), [/etc/default/grub](https://gist.github.com/lalbrekht/ef78c39c236ae223acfb3b5e1970001c), [/boot/grub2/grub.cfg](https://gist.github.com/lalbrekht/1a9cae3cb64ce2dc7bd301e48090bd56). Везде заменяем старое название на новое. По ссылкам можно увидеть примеры получившихся файлов.

- Пересоздаем **initrd image**, чтобы он знал новое название **Volume Group**

```bash
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
```

- После чего можем перезагружаться и если все сделано правильно, успешно грузимся с новым именем **Volume Group** и проверяяем:

```bash
vgs
```

- При желании можно так же заменить название **Logical Volume**

Скрипты модулей хранятся в каталоге **/usr/lib/dracut/modules.d/**. Для того чтобы добавить свой модуль, создаем там папку с именем **01test**:

```bash
mkdir /usr/lib/dracut/modules.d/01test
```

В нее поместим два скрипта:

1. [module-setup.sh](https://gist.github.com/lalbrekht/e51b2580b47bb5a150bd1a002f16ae85) - который устанавливает модуль и вызывает скрипт test.sh
2. [test.sh](https://gist.github.com/lalbrekht/ac45d7a6c6856baea348e64fac43faf0) - собственно сам вызывает скрипт, в нём у нас рисуется пингвинчик

Примеры файлов по ссылкам.

- Пересобираем образ **initrd**

```bash
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
```

или

```bash
dracut -f -v
```

- Можно проверить/посмотреть какие модули загружены в образ:

```bash
lsinitrd -m /boot/initramfs-$(uname -r).img | grep test
```

- После чего можно пойти двумя путями для проверки:
  - Перезагрузитьяся и руками выклюяить опции **rghb** и **quiet** и увидеть вывод
  - Либо отредактировать **grub.cfg** убрав эти опции
- В итоге при загрузке будет пауза на 10 секунд и мы увидим пингвина в выводе терминала

## Задание со * - Сконфигурировать систему без отдельного раздела с /boot, а только с LVM

> Репозиторий с пропатченым grub: <https://yum.rumyantsev.com/centos/7/x86_64/>  
> PV инициализируем с параметром  **--bootloaderareasize 1m**

- посмотрим на наши диски

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
|-sda1                    8:1    0    1M  0 part 
|-sda2                    8:2    0    1G  0 part /boot
`-sda3                    8:3    0   39G  0 part 
  |-VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  `-VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   40G  0 disk
```

- создадим pv

```bash
pvcreate /dev/sdb --bootloaderareasize 1m
  Physical volume "/dev/sdb" successfully created.
```

- создадим vg

```bash
vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
```

- создадим lv

```bash
lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.
```

- создаем ФС

```bash
mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=2621184 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=10484736, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=5119, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

- монтируем

```bash
mount /dev/vg_root/lv_root /mnt
```

- переносим данные с помощью xfsdump

```bash
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
xfsrestore: using file dump (drive_simple) strategy
xfsdump: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of hw7star:/
xfsdump: dump date: Sat Nov 27 12:30:37 2021
xfsdump: session id: ddd4d522-333a-47b4-a59b-c993177eb7a2
xfsdump: session label: ""
xfsrestore: searching media for dump
xfsdump: ino map phase 1: constructing initial dump list
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 3283437440 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: examining media file 0
xfsrestore: dump description: 
xfsrestore: hostname: hw7star
xfsrestore: mount point: /
xfsrestore: volume: /dev/sda1
xfsrestore: session time: Sat Nov 27 12:30:37 2021
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: 1c419d6c-5064-4a2b-953c-05b2c67edb15
xfsrestore: session id: ddd4d522-333a-47b4-a59b-c993177eb7a2
xfsrestore: media id: 4b8f662a-52b2-457f-b5f7-92e47e5adfe1
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2988 directories and 32112 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: ending media file
xfsdump: media file size 3245891752 bytes
xfsdump: dump size (non-dir files) : 3227246032 bytes
xfsdump: dump complete: 16 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 16 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```

```bash
rsync -avx /boot /mnt/root
```

- изменим корень

```bash
for i in /proc/ /sys/ /dev/ /run/; do mount --bind $i /mnt/$i; done
chroot /mnt/
```

- добавим репозиторий с пропатченым grub

```bash
yum-config-manager --add-repo=https://yum.rumyantsev.com/centos/7/x86_64/
```

- и установим его

```bash
yum install grub2 -y --enablerepo=yum.rumyantsev.com_centos_7_x86_64_ --nogpgcheck
```

- проверим

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
|-sda1                    8:1    0    1M  0 part 
|-sda2                    8:2    0    1G  0 part 
`-sda3                    8:3    0   39G  0 part 
  |-VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  
  `-VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   40G  0 disk 
`-vg_root-lv_root       253:2    0   40G  0 lvm  /
```

```bash
blkid
/dev/sda2: UUID="570897ca-e759-4c81-90cf-389da6eee4cc" TYPE="xfs" 
/dev/sda3: UUID="vrrtbx-g480-HcJI-5wLn-4aOf-Olld-rC03AY" TYPE="LVM2_member" 
/dev/mapper/VolGroup00-LogVol00: UUID="b60e9498-0baa-4d9f-90aa-069048217fee" TYPE="xfs" 
/dev/sdb: UUID="Z68YC8-DGaJ-AoHV-U4nf-5q0e-85YT-qaPhje" TYPE="LVM2_member" 
/dev/mapper/VolGroup00-LogVol01: UUID="c39c5bed-f37c-4263-bee8-aeb6a6659d7b" TYPE="swap" 
/dev/mapper/vg_root-lv_root: UUID="cb610a61-cab5-47f9-a777-44b5c7c396c3" TYPE="xfs"
```

- поправим /etc/fstab

- правим /etc/default/grub

```bash
sed -i 's/rd\.lvm\.lv=VolGroup00\/LogVol00/rd\.lvm\.lv=vg_root\/lv_root/g' /etc/default/grub
```

- Обновляем конфигурацию загрузчика

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
```

- обновляем initramfs

```bash
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;s/.img//g"` --force; done
```

- ставим загрузчик на второй диск

```bash
grub2-install /dev/sdb
Installing for i386-pc platform.
Installation finished. No error reported.
```

- выходим, загружаемся с нового диска и проверяем

```bash
shutdown -r now
```

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
`-vg_root-lv_root       253:0    0   40G  0 lvm  /
sdb                       8:16   0   40G  0 disk 
|-sdb2                    8:18   0    1G  0 part 
`-sdb3                    8:19   0   39G  0 part 
  |-VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  `-VolGroup00-LogVol00 253:2    0 37.5G  0 lvm
```
