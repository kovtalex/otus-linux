# HW3 - Работа с LVM]

На имеющемся образе centos/7 - 1804.02:

1) Уменьшим том под / до 8G
2) Выделим том под /home
3) Выделим том под /var - сделаем в mirror
4) /home - сделаем том для снапшотов
5) Пропишем монтирование в fstab

Работа со снапшотами:

- сгенерим файлы в /home/
- снимет снапшот
- удалим часть файлов
- восстановимся со снапшота

\* на нашей куче дисков попробуем поставить zfs - с кешем, разметим здесь каталог /opt и поработаем со снапшотами

## Уменьшение тома под / до 8G

- Посмотрим на диски

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```

- Подготовим временный том для / раздела

```bash
pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
```

```bash
vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
```

```bash
lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.
```

- Создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные

```bash
mkfs.xfs /dev/vg_root/lv_root

meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

```bash
mount /dev/vg_root/lv_root /mnt
```

- Этой командой скопируем все данные с / раздела в /mnt

```bash
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt

xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of lvm:/
xfsdump: dump date: Fri Nov 12 07:36:25 2021
xfsdump: session id: c1e56cb1-62f6-4113-817f-13c1a659ba37
xfsdump: session label: ""
xfsrestore: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: ino map phase 1: constructing initial dump list
xfsrestore: searching media for dump
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 795304640 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: examining media file 0
xfsrestore: dump description: 
xfsrestore: hostname: lvm
xfsrestore: mount point: /
xfsrestore: volume: /dev/mapper/VolGroup00-LogVol00
xfsrestore: session time: Fri Nov 12 07:36:25 2021
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: b60e9498-0baa-4d9f-90aa-069048217fee
xfsrestore: session id: c1e56cb1-62f6-4113-817f-13c1a659ba37
xfsrestore: media id: 1d383e81-2093-4228-a8a6-e881cd852f18
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2718 directories and 23634 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: ending media file
xfsdump: media file size 772361184 bytes
xfsdump: dump size (non-dir files) : 759183816 bytes
xfsdump: dump complete: 8 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 9 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```

- Затем переконфигурируем grub для того, чтобы при старте перейти в новый /

Сымитируем текущий **root** -> сделаем в него [chroot](https://wiki.archlinux.org/index.php/Chroot_(%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9)) и обновим **grub**:

```bash
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg

Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
```

- Обновим образ [initrd](https://ru.wikipedia.org/wiki/Initrd)

```bash
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;s/.img//g"` --force; done

*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```

> Ну и для того, чтобы при загрузке был смонтирован нужный root необходимо в файле /boot/grub2/grub.cfg заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root

```bash
sed -i 's/rd\.lvm\.lv=VolGroup00\/LogVol00/rd\.lvm\.lv=vg_root\/lv_root/g' /boot/grub2/grub.cfg
```

- Перезагружаемся успешно с новым рут томом

```bash
shutdown -r now
```

- Убедиться в этом можно посмотрев вывод lsblk:

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  
  └─VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:1    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```

- Теперь нам нужно изменить размер старой VG и вернуть на него рут. Для этого удаляем старый LV размеров в 40G и создаем новый на 8G

```bash
lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed

lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
```

- Проделываем на нем те же операции, что и в первый раз:

```bash
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt

xfsrestore: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of lvm:/
xfsdump: dump date: Fri Nov 12 09:31:18 2021
xfsdump: session id: c8f22727-0dd6-4889-a31c-a460f84452d5
xfsdump: session label: ""
xfsrestore: searching media for dump
xfsdump: ino map phase 1: constructing initial dump list
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 793922112 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: examining media file 0
xfsrestore: dump description: 
xfsrestore: hostname: lvm
xfsrestore: mount point: /
xfsrestore: volume: /dev/mapper/vg_root-lv_root
xfsrestore: session time: Fri Nov 12 09:31:18 2021
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: 413d051c-3641-4177-b22a-b71378e7378b
xfsrestore: session id: c8f22727-0dd6-4889-a31c-a460f84452d5
xfsrestore: media id: 983399d1-2a68-4e4c-af4d-86ad6ddf19d5
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2722 directories and 23640 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: ending media file
xfsdump: media file size 771000640 bytes
xfsdump: dump size (non-dir files) : 757818936 bytes
xfsdump: dump complete: 9 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 9 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```

- Так же как в первый раз переконфигурируем grub, за исключением правки /etc/grub2/grub.cfg

```bash
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg

Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
```

```bash
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;s/.img//g"` --force; done

*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```

> Пока не перезагружаемся и не выходим из под chroot - мы можем заодно перенести /var

## Выделение тома под /var в зеркало

- На свободных дисках создаем зеркало

```bash
pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
```

```bash
vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created
```

```bash
lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
```

- Создаем на нем ФС и перемещаем туда /var

```bash
mkfs.ext4 /dev/vg_var/lv_var

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
60928 inodes, 243712 blocks
12185 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=249561088
8 block groups
32768 blocks per group, 32768 fragments per group
7616 inodes per group
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

```bash
mount /dev/vg_var/lv_var /mnt

cp -aR /var/* /mnt/ # rsync -avHPSAX /var/ /mnt/
```

- На всякий случай сохраняем содержимое старого var (или же можно его просто удалить)

```bash
mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
```

- Ну и монтируем новый var в каталог /var

```bash
umount /mnt
mount /dev/vg_var/lv_var /var
```

- Правим fstab для автоматического монтирования /var

```bash
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

```bash
cat /etc/fstab 

#
# /etc/fstab
# Created by anaconda on Sat May 12 18:50:26 2018
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/VolGroup00-LogVol00 /                       xfs     defaults        0 0
UUID=570897ca-e759-4c81-90cf-389da6eee4cc /boot                   xfs     defaults        0 0
/dev/mapper/VolGroup00-LogVol01 swap                    swap    defaults        0 0
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
#VAGRANT-END
UUID="8771735d-38aa-4524-9c16-4f1f168b6446" /var ext4 defaults 0 0
```

- После чего можно успешно перезагружаться в новый (уменьшенный root) и удалять временную Volume Group

```bash
lvremove /dev/vg_root/lv_root
vgremove /dev/vg_root
pvremove /dev/sdb
```

## Выделение тома под /home

- Выделяем том под /home по тому же принципу что делали для /var

```bash
lvcreate -n LogVol_Home -L 2G /dev/VolGroup00

mkfs.xfs /dev/VolGroup00/LogVol_Home

mount /dev/VolGroup00/LogVol_Home /mnt/
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/VolGroup00/LogVol_Home /home/
```

- Правим fstab длā автоматического монтирования /home

```bash
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```

```bash
cat /etc/fstab 

#
# /etc/fstab
# Created by anaconda on Sat May 12 18:50:26 2018
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/VolGroup00-LogVol00 /                       xfs     defaults        0 0
UUID=570897ca-e759-4c81-90cf-389da6eee4cc /boot                   xfs     defaults        0 0
/dev/mapper/VolGroup00-LogVol01 swap                    swap    defaults        0 0
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
#VAGRANT-END
UUID="afdbe065-e0d5-4f64-88ce-62c0d7bf12fe" /var ext4 defaults 0 0
UUID="f74f69dd-cd49-4221-8d48-8f396a01fdee" /home xfs defaults 0 0
```

## /home - сделаем том для снапшотов

- Сгенерируем файлы в /home/

```bash
touch /home/file{1..20}
```

- Снимем снапшот

```bash
lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
```

- Удалим часть файлов

```bash
rm -f /home/file{11..20}
```

- Процесс восстановления со снапшота

```bash
umount /home
lvconvert --merge /dev/VolGroup00/home_snap
mount /home

ls /home/file* | column -t

/home/file1
/home/file10
/home/file11
/home/file12
/home/file13
/home/file14
/home/file15
/home/file16
/home/file17
/home/file18
/home/file19
/home/file2
/home/file20
/home/file3
/home/file4
/home/file5
/home/file6
/home/file7
/home/file8
/home/file9
```

## Задание со *

### На нашей куче дисков попробуем поставить zfs - с кешем, разметим здесь каталог /opt и поработаем со снапшотами

- Установим ZFS (kABI-tracking kmod)

```bash
yum install -y https://zfsonlinux.org/epel/zfs-release.el7_8.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux

yum-config-manager --disable zfs
yum-config-manager --enable zfs-kmod
yum install -y zfs

modprobe zfs
```

- Посмотрим на наши диски

```bash
lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```

- Создадим пул storage для /opt раздела на sdb, кеш записи на sdc, кеш чтения на sdd, sde

```basg
zpool create storage /dev/sdb log /dev/sdc cache /dev/sd[de]

zpool status 
  pool: storage
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        storage     ONLINE       0     0     0
          sdb       ONLINE       0     0     0
        logs
          sdc       ONLINE       0     0     0
        cache
          sdd       ONLINE       0     0     0
          sde       ONLINE       0     0     0

errors: No known data errors
```

```bash
zpool list
NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
storage  9.50G   110K  9.50G        -         -     0%     0%  1.00x    ONLINE  -
```

- Создадим файловую систему

```bash
zfs create storage/opt
```

- Посмотрим что у нас замонтировано

```bash
zfs list
NAME          USED  AVAIL     REFER  MOUNTPOINT
storage       138K  9.20G     25.5K  /storage
storage/opt    24K  9.20G       24K  /storage/opt
```

- Замонтируем наш opt

```bash
zfs set mountpoint=/opt storage/opt
```

- Проверяем

```bash
zfs list
NAME          USED  AVAIL     REFER  MOUNTPOINT
storage       156K  9.20G       24K  /storage
storage/opt    24K  9.20G       24K  /opt

df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        111M     0  111M   0% /dev
tmpfs           118M     0  118M   0% /dev/shm
tmpfs           118M  4.5M  114M   4% /run
tmpfs           118M     0  118M   0% /sys/fs/cgroup
/dev/sda1        40G  3.1G   37G   8% /
storage         9.3G  128K  9.3G   1% /storage
storage/opt     9.3G  128K  9.3G   1% /opt
tmpfs            24M     0   24M   0% /run/user/1000
```

- Сгенерируем файлы в /opt

```bash
touch /opt/file{1..20}

ls /opt/file* | column -t
/opt/file1
/opt/file10
/opt/file11
/opt/file12
/opt/file13
/opt/file14
/opt/file15
/opt/file16
/opt/file17
/opt/file18
/opt/file19
/opt/file2
/opt/file20
/opt/file3
/opt/file4
/opt/file5
/opt/file6
/opt/file7
/opt/file8
/opt/file9
```

- Снимем снапшот

```bash
zfs snapshot storage/opt@snap001
```

- Проверим снапшот

```bash
zfs list -t  snapshot
NAME                  USED  AVAIL     REFER  MOUNTPOINT
storage/opt@snap001    21K      -       38K  -
```

- Удалим часть файлов

```bash
rm -f /opt/file{11..20}

ls /opt/file* | column -t
/opt/file1
/opt/file10
/opt/file2
/opt/file3
/opt/file4
/opt/file5
/opt/file6
/opt/file7
/opt/file8
/opt/file9
```

- Процесс восстановления со снапшота

```bash
zfs rollback storage/opt@snap001

ls /opt/file* | column -t
/opt/file1
/opt/file10
/opt/file11
/opt/file12
/opt/file13
/opt/file14
/opt/file15
/opt/file16
/opt/file17
/opt/file18
/opt/file19
/opt/file2
/opt/file20
/opt/file3
/opt/file4
/opt/file5
/opt/file6
/opt/file7
/opt/file8
/opt/file9
```
