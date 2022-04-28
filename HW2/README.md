# HW2 - Работа с mdadm

## Задание

- добавить в Vagrantfile еще дисков
- собрать R0/R5/R10 на выбор
- прописать собранный рейд в конф, чтобы рейд собирался при загрузке
- сломать/починить raid
- создать GPT раздел и 5 партиøий и смонтировать их на диск

- Доп. задание - Vagrantfile, который сразу собирает систему с подключенным рейдом

## Добавим в Vagrantfile еще дисков

Начальный стенд можно взять отсюда: https://github.com/erlong15/otus-linux. В принципе на нем уже можно собрать любой RAID.

Для каждого следующего диска нужно добавить следующий блок в Vagrantfile

```bash
    :sata5 => {
      :dfile => './sata5.vdi',
      :size => 250, # Megabytes
      :port => 5
    }
```

Обязательно увеличив номер порта и изменив имя файла диска, чтобы исключить дублирование.

Далее подразумеваем, чт мы добавили в Vagrantfile 5-ый диск.

## Собрать RAID0/1/5/10 - на выбор

Далее нужно определиться какого уровня RAID будем собирать. Для это посмотрим какие блочные устройства у нас есть и исходя из их кол-ва, размера и поставленной задачи определимся.

Сделать это можно несколькими способами:

- fdisk -l
- lsblk
- lshw
- lsscsi

```bash
lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
`-sda1   8:1    0   40G  0 part /
sdb      8:16   0  250M  0 disk 
sdc      8:32   0  250M  0 disk 
sdd      8:48   0  250M  0 disk 
sde      8:64   0  250M  0 disk 
sdf      8:80   0  250M  0 disk 
```

```bash
lsscsi
[0:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sda 
[3:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdb 
[4:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdc 
[5:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdd 
[6:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sde 
[7:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdf 
```

```bash
sudo fdisk -l

Disk /dev/sda: 42.9 GB, 42949672960 bytes, 83886080 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x0009ef1a

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048    83886079    41942016   83  Linux

Disk /dev/sdb: 262 MB, 262144000 bytes, 512000 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdc: 262 MB, 262144000 bytes, 512000 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdf: 262 MB, 262144000 bytes, 512000 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 262 MB, 262144000 bytes, 512000 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sde: 262 MB, 262144000 bytes, 512000 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

```bash
sudo lshw -short | grep disk
/0/100/1.1/0.0.0    /dev/sda  disk        42GB VBOX HARDDISK
/0/100/d/0          /dev/sdb  disk        262MB VBOX HARDDISK
/0/100/d/1          /dev/sdc  disk        262MB VBOX HARDDISK
/0/100/d/2          /dev/sdd  disk        262MB VBOX HARDDISK
/0/100/d/3          /dev/sde  disk        262MB VBOX HARDDISK
/0/100/d/0.0.0      /dev/sdf  disk        262MB VBOX HARDDISK
```

- Занулим на всякий случай суперблоки

```bash
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
mdadm: Unrecognised md component device - /dev/sdb
mdadm: Unrecognised md component device - /dev/sdc
mdadm: Unrecognised md component device - /dev/sdd
mdadm: Unrecognised md component device - /dev/sde
mdadm: Unrecognised md component device - /dev/sdf
```

- И можно создавать рейд следующей командой

```bash
mdadm --create --verbose /dev/md0 -l 6 -n 5 /dev/sd{b,c,d,e,f}
mdadm: layout defaults to left-symmetric
mdadm: layout defaults to left-symmetric
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```

> Мы выбрали RAID 6. Опция -l какого уровня RAID создавать  
> Опция - n указывает на кол-во устройств в RAID

- Проверим что RAID собрался нормально

```bash
cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
```

> 512k chunk - размер олного чанка. [UUUUU] - кол-во юнитов в RAID

Полный вывод можно посмотреть тут: https://gist.github.com/lalbrekht/05a750161f63a2f892b5c314a58ff28b

```bash
mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Nov  8 09:33:09 2021
        Raid Level : raid6
        Array Size : 761856 (744.00 MiB 780.14 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Nov  8 09:33:13 2021
             State : clean 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 84e4044b:c1018973:2288ce28:9fbfda23
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       3       8       64        3      active sync   /dev/sde
       4       8       80        4      active sync   /dev/sdf
```

## Создание конфигурационного файла mdadm.conf

Для того, чтобы быть уверенным что ОС запомнила какой RAID массив требуется создать и какие компоненты в него входят создадим файл mdadm.conf

- Сначала убедимся, что информация верна

```bash
mdadm --detail --scan --verbose
ARRAY /dev/md0 level=raid6 num-devices=5 metadata=1.2 name=otuslinux:0 UUID=84e4044b:c1018973:2288ce28:9fbfda23
   devices=/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf
```

- А затем в две команды создадим файл mdadm.conf

```bash
mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```

```bash
cat /etc/mdadm/mdadm.conf
DEVICE partitions
ARRAY /dev/md0 level=raid6 num-devices=5 metadata=1.2 name=otuslinux:0 UUID=84e4044b:c1018973:2288ce28:9fbfda23
```

## Сломать/починить RAID

- Сделать это можно, например, искусственно “зафейлив” одно из блочных устройств командной

```bash
mdadm /dev/md0 --fail /dev/sde
mdadm: set /dev/sde faulty in /dev/md0
```

- Посмотрим как это отразилось на RAID

```bash
cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sdf[4] sde[3](F) sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/4] [UUU_U]
      
unused devices: <none>
```

> [UUU_U] - видим зафейлившийся диск

```bash
mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Nov  8 09:33:09 2021
        Raid Level : raid6
        Array Size : 761856 (744.00 MiB 780.14 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Nov  8 09:39:08 2021
             State : clean, degraded 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 1
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 84e4044b:c1018973:2288ce28:9fbfda23
            Events : 19

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       -       0        0        3      removed
       4       8       80        4      active sync   /dev/sdf

       3       8       64        -      faulty   /dev/sde
```

- Удалим “сломанный” диск из массива

```bash
mdadm /dev/md0 --remove /dev/sde
mdadm: hot removed /dev/sde from /dev/md0
```

- Представим, что мы вставили новый диск в сервер и теперь нам нужно добавить его в RAID. Делается это так

```bash
mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
```

> Диск должен пройти стадию **rebuilding**. Например, если это был RAID 1 (зеркало), то данные должны скопироваться на новый диск.

- Процесс rebuild-а можно увидеть в выводе следующих команд

```bash
cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sde[5] sdf[4] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
```

```bash
mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Nov  8 09:33:09 2021
        Raid Level : raid6
        Array Size : 761856 (744.00 MiB 780.14 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Nov  8 09:40:40 2021
             State : clean 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 84e4044b:c1018973:2288ce28:9fbfda23
            Events : 39

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       5       8       64        3      active sync   /dev/sde
       4       8       80        4      active sync   /dev/sdf
```

> На маленьких объемах занятого пространства можно и пропустить момент перестроения RAID-а - так быстро он проходит.

## Создать GPT раздел, пять партиций и смонтировать их на диск

- Создаем раздел GPT на RAID

```bash
parted -s /dev/md0 mklabel gpt
```

- Создаем партиции

```bash
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
```

- Далее можно создать на этих партициях ФС

```bash
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1536 blocks
37696 inodes, 150528 blocks
7526 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
19 block groups
8192 blocks per group, 8192 fragments per group
1984 inodes per group
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1536 blocks
38152 inodes, 152064 blocks
7603 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
19 block groups
8192 blocks per group, 8192 fragments per group
2008 inodes per group
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1536 blocks
38456 inodes, 153600 blocks
7680 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
19 block groups
8192 blocks per group, 8192 fragments per group
2024 inodes per group
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1536 blocks
38152 inodes, 152064 blocks
7603 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
19 block groups
8192 blocks per group, 8192 fragments per group
2008 inodes per group
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1536 blocks
37696 inodes, 150528 blocks
7526 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33816576
19 block groups
8192 blocks per group, 8192 fragments per group
1984 inodes per group
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

- И смонтировать их по каталогам

```bash
mkdir -p /raid/part{1,2,3,4,5}
```

```bash
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```

```bash
mount | grep md0
/dev/md0p1 on /raid/part1 type ext4 (rw,relatime,seclabel,stripe=1536,data=ordered)
/dev/md0p2 on /raid/part2 type ext4 (rw,relatime,seclabel,stripe=1536,data=ordered)
/dev/md0p3 on /raid/part3 type ext4 (rw,relatime,seclabel,stripe=1536,data=ordered)
/dev/md0p4 on /raid/part4 type ext4 (rw,relatime,seclabel,stripe=1536,data=ordered)
/dev/md0p5 on /raid/part5 type ext4 (rw,relatime,seclabel,stripe=1536,data=ordered)

```bash
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 default 0 0" >> /etc/fstab; done
```

- Теперь доработаем Vagranfile для автоматической сборки системы с подключением рейда и добавим скрипт

```mdadm.sh
#!/bin/bash

yum install -y mdadm smartmontools hdparm gdisk
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
mdadm --create --verbose /dev/md0 -l 6 -n 5 /dev/sd{b,c,d,e,f}
mdadm -D /dev/md0
mkdir /etc/mdadm
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
for i in $(seq 1 5); do mkfs.ext4 /dev/md0p"$i"; done
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount /dev/md0p"$i" /raid/part"$i"; done
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i ext4 defaults 0 0" >> /etc/fstab; done
mount | grep md0
cat /proc/mdstat
```
