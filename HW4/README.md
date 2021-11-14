# HW4 - Практические навыкт работы с ZFS

Определить алгоритм с наилучшим сжатием

**Зачем:**

Отрабатываем навыки работы с созданием томов и установкой параметров.  
Находим наилучшее сжатие.

**Шаги:**

- определить какие алгоритмы сжатия поддерживает zfs (gzip gzip-N, zle lzjb, lz4)
- создать 4 файловых системы на каждой применить свой алгоритм сжатия

Для сжатия использовать либо текстовый файл либо группу файлов:

- скачать файл “Война и мир” и расположить на файловой системе (wget -O War_and_Peace.txt <http://www.gutenberg.org/ebooks/2600.txt.utf-8>)
- либо скачать файл ядра распаковать и расположить на файловой системе

**Результат:**

- список команд которыми получен результат с их выводами
- вывод команды из которой видно какой из алгоритмов лучше

---

Определить настройки pool’a

**Зачем:**

Для переноса дисков между системами используется функция export/import.  
Отрабатываем навыки работы с файловой системой ZFS.

**Шаги:**

- Загрузить архив с файлами локально. (<https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg>)
- Распаковать
- С помощью команды zfs import собрать pool ZFS.
- Командами zfs определить настройки
  - размер хранилища
  - тип pool
  - значение recordsize
  - какое сжатие используется
  - какая контрольная сумма используется

**Результат:**

- список команд которыми восстановили pool. Желательно с Output команд.
- файл с описанием настроек settings

---

Найти сообщение от преподавателей

**Зачем:**

для бэкапа используются технологии snapshot.  
Snapshot можно передавать между хостами и восстанавливать с помощью send/receive.  
Отрабатываем навыки восстановления snapshot и переноса файла.

**Шаги:**

- Скопировать файл из удаленной директории. (<https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing>). Файл был получен командой zfs send otus/storage@task2 > otus_task2.file
- Восстановить его локально. zfs receive
- Найти зашифрованное сообщение в файле c именем secret_message

**Результат:**

- список шагов которыми восстанавливали
- зашифрованное сообщение

## Определяем алгоритм с наилучшим сжатием

- Посмотрим на наши диски

```bash
lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  10G  0 disk 
`-sda1   8:1    0  10G  0 part /
sdb      8:16   0   1G  0 disk 
sdc      8:32   0   1G  0 disk 
sdd      8:48   0   1G  0 disk 
```

- Создадим новый пул storage

```bash
zpool create storage /dev/sd[b-d]
```

- Выведем информацию о его статусе

```bash
zpool status
  pool: storage
 state: ONLINE
config:

        NAME        STATE     READ WRITE CKSUM
        storage     ONLINE       0     0     0
          sdb       ONLINE       0     0     0
          sdc       ONLINE       0     0     0
          sdd       ONLINE       0     0     0

errors: No known data errors
```

- Посмотрим на базовую информации пула

```bash
zpool list
NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
storage  2.81G   110K  2.81G        -         -     0%     0%  1.00x    ONLINE  -
```

- Создадим файловые системы

```bash
zfs create storage/compressed
zfs create storage/compressed/gzip
zfs create storage/compressed/gzip-9
zfs create storage/compressed/zle
zfs create storage/compressed/lzjb
zfs create storage/compressed/lz4
```

> gzip это gzip с уровнем сжатия 6

- Выведем список ФС

```bash
zfs list
NAME                        USED  AVAIL     REFER  MOUNTPOINT
storage                     386K  2.69G     25.5K  /storage
storage/compressed          148K  2.69G       28K  /storage/compressed
storage/compressed/gzip      24K  2.69G       24K  /storage/compressed/gzip
storage/compressed/gzip-9    24K  2.69G       24K  /storage/compressed/gzip-9
storage/compressed/lz4       24K  2.69G       24K  /storage/compressed/lz4
storage/compressed/lzjb      24K  2.69G       24K  /storage/compressed/lzjb
storage/compressed/zle       24K  2.69G       24K  /storage/compressed/zle
```

- Установим вид сжатия для каждой из ФС

```bash
zfs set compression=gzip storage/compressed/gzip
zfs set compression=gzip-9 storage/compressed/gzip-9
zfs set compression=zle storage/compressed/zle
zfs set compression=lzjb storage/compressed/lzjb
zfs set compression=lz4 storage/compressed/lz4
```

- Проверим

```bash
zfs get compression
NAME                       PROPERTY     VALUE           SOURCE
storage                    compression  off             default
storage/compressed         compression  off             default
storage/compressed/gzip    compression  gzip            local
storage/compressed/gzip-9  compression  gzip-9          local
storage/compressed/lz4     compression  lz4             local
storage/compressed/lzjb    compression  lzjb            local
storage/compressed/zle     compression  zle             local
```

- Скачаем и распакуем исходники ядра для проверки степени сжатия

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.2.tar.xz
tar -xvf linux-5.15.2.tar.xz
```

- Скопируем на каждую ФС

```bash
cp -r linux-5.15.2 /storage/compressed/gzip
cp -r linux-5.15.2 /storage/compressed/gzip-9
cp -r linux-5.15.2 /storage/compressed/zle
cp -r linux-5.15.2 /storage/compressed/lzjb
cp -r linux-5.15.2 /storage/compressed/lz4
```

- Реальный размер распакованного архива

```bash
du -sh /root/linux-5.15.2
1.2G    linux-5.15.2
```

- Посмотрим на степень сжатия в каждой из ФС

```bash
zfs get compressratio
NAME                       PROPERTY       VALUE  SOURCE
storage                    compressratio  2.38x  -
storage/compressed         compressratio  2.38x  -
storage/compressed/gzip    compressratio  4.54x  -
storage/compressed/gzip-9  compressratio  4.58x  -
storage/compressed/lz4     compressratio  2.93x  -
storage/compressed/lzjb    compressratio  2.54x  -
storage/compressed/zle     compressratio  1.08x  -
```

- Посмотрим на занимаемый размер нашими исходниками в каждой из ФС

```bash
zfs list
NAME                        USED  AVAIL     REFER  MOUNTPOINT
storage                    2.44G   250M     25.5K  /storage
storage/compressed         2.44G   250M     28.5K  /storage/compressed
storage/compressed/gzip     271M   250M      271M  /storage/compressed/gzip
storage/compressed/gzip-9   269M   250M      269M  /storage/compressed/gzip-9
storage/compressed/lz4      410M   250M      410M  /storage/compressed/lz4
storage/compressed/lzjb     469M   250M      469M  /storage/compressed/lzjb
storage/compressed/zle     1.06G   250M     1.06G  /storage/compressed/zle
```

## Определяем настройки pool’a

- Удалим наш пул storage

```bash
zpool destroy zfs
```

- Загрузим архив с файлами на vagrant vm через shared folder. (<https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg>)

- Распакуем

```bash
tar zxvf zfs_task1.tar.gz
```

- С помощью команды zfs import соберем pool ZFS

```bash
zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE

zpool import -d zpoolexport/ otus
```

- Проапгрейдим pool

```bash
zpool upgrade otus
This system supports ZFS pool feature flags.

Enabled the following features on 'otus':
  redaction_bookmarks
  redacted_datasets
  bookmark_written
  log_spacemap
  livelist
  device_rebuild
  zstd_compress
```

- Посмотрим что получилось

```bash
zpool status
  pool: otus
 state: ONLINE
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```

- Замонтированные файловые системы

```bash
zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus            2.06M   350M       24K  /otus
otus/hometask2  1.88M   350M     1.88M  /otus/hometask2
```

Командами zfs определим настройки:

- размер хранилища

```bash
zpool list
NAME   SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus   480M  2.07M   478M        -         -     0%     0%  1.00x    ONLINE  -
```

> 480M

- тип pool

```bash
zpool status 
  pool: otus
 state: ONLINE
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```

> mirror-0 из двух файлов

- значение recordsize

```bash
zfs get recordsize otus otus/hometask2
NAME            PROPERTY    VALUE    SOURCE
otus            recordsize  128K     local
otus/hometask2  recordsize  128K     inherited from otus
```

> 128K

- какое сжатие используется

```bash
zfs get compression otus otus/hometask2
NAME            PROPERTY     VALUE           SOURCE
otus            compression  zle             local
otus/hometask2  compression  zle             inherited from otus
```

> zle

- какая контрольная сумма используется

```bash
zfs get checksum otus otus/hometask2
NAME            PROPERTY  VALUE      SOURCE
otus            checksum  sha256     local
otus/hometask2  checksum  sha256     inherited from otus
```

> sha256

- [Файл с описанием настроек settings](./settings.txt)

## Найдем сообщение от преподавателей

- Скопируем файл из удаленной директории на vagrant vm через shared folder. (<https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing>). Файл был получен командой zfs send otus/storage@task2 > otus_task2.file

- Восстановим его локально. zfs receive

```bash
zfs receive otus/storage@task2 < otus_task2.file

zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus            4.95M   347M       25K  /otus
otus/hometask2  1.88M   347M     1.88M  /otus/hometask2
otus/storage    2.83M   347M     2.83M  /otus/storage
```

> Видим новую фс - /otus/storage

- Найдем зашифрованное сообщение в файле c именем secret_message

```bash
find /otus/storage/ -name secret_message
/otus/storage/task1/file_mess/secret_message

cat /otus/storage/task1/file_mess/secret_message
https://github.com/sindresorhus/awesome
```

> Текст из файла **secret_message**: <https://github.com/sindresorhus/awesome>
