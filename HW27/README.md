# HW27 - Репликация postgres

## Развернем 4 виртуалки и установим postgresql 14

```bash
vagrant up
```

## Создадим публикацию таблицы test1, подписываемся на публикацию таблицы test2 с db2 и публикацию таблицы test2, подписываемся на публикацию таблицы test1 с db1

- на db1 включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

- перезагружаем сервер

```bash
pg_ctlcluster 14 main restart
```

- создаем базу, таблицу и наполняем ее

```sql
\password 
create database test;
\c test;
create table test1 (i int,str varchar(10));
insert into test1 values(1, 'строка1');
insert into test1 values(2, 'строка2');
select * from  test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- на db2 включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

- перезагружаем сервер

```bash
pg_ctlcluster 14 main restart
```

- создаем базу, таблицу и наполняем ее

```sql
\password 
create database test;
\c test;
create table test2 (i int,str varchar(10));
insert into test2 values(1, 'строка1');
insert into test2 values(2, 'строка2');
insert into test2 values(3, 'строка3');
select * from  test2;
 i |   str
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(2 rows)
```

- на db1 создаем публикацию

```sql
CREATE PUBLICATION test1_pub FOR TABLE test1;
```

- просмотр созданной публикации

```sql
\dRp+
                      Publication test1_pub
  Owner   | All tables | Inserts | Updates | Deletes | Truncates 
----------+------------+---------+---------+---------+-----------
 postgres | f          | t       | t       | t       | t
Tables:
    "public.test1"
```

- на db2 создаем публикацию

```sql
CREATE PUBLICATION test2_pub FOR TABLE test2;
```

- просмотр созданной публикации

```sql
\dRp+
                      Publication test2_pub
  Owner   | All tables | Inserts | Updates | Deletes | Truncates 
----------+------------+---------+---------+---------+-----------
 postgres | f          | t       | t       | t       | t
Tables:
    "public.test2"
```

- на db1 создаем подписку

```sql
CREATE TABLE test2 (i int,str varchar(10));
CREATE SUBSCRIPTION test2_sub
 CONNECTION 'host=192.168.56.12 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test2_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
            List of subscriptions
   Name    |  Owner   | Enabled | Publication
-----------+----------+---------+-------------
 test2_sub | postgres | t       | {test1_pub}
(1 row)
```

- сделаем выборку

```sql
select * from test2;
 i |   str   
 ---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)

select * from test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- просмотр состония подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16393
subname               | test2_sub
pid                   | 25256
relid                 | 
received_lsn          | 0/1710AD0
last_msg_send_time    | 2022-04-26 12:23:08.026073+00
last_msg_receipt_time | 2022-04-26 12:23:09.050664+00
latest_end_lsn        | 0/1710AD0
latest_end_time       | 2022-04-26 12:23:08.026073+00
```

> Мы успешно подписались на публикацию таблицы test2 с db2

- на db2 создаем подписку

```sql
CREATE TABLE test1 (i int,str varchar(10));
CREATE SUBSCRIPTION test1_sub
 CONNECTION 'host=192.168.56.11 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test1_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
            List of subscriptions
   Name    |  Owner   | Enabled | Publication 
-----------+----------+---------+-------------
 test1_sub | postgres | t       | {test1_pub}
(1 row)
```

- сделаем выборку

```sql
select * from test2;
 i |   str   
 ---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)

select * from test1;
 i |   str
---+---------
 1 | строка1
 2 | строка2
(2 rows)
```

- просмотр состония подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16393
subname               | test1_sub
pid                   | 25143
relid                 | 
received_lsn          | 0/1713B90
last_msg_send_time    | 2022-04-26 12:24:04.442848+00
last_msg_receipt_time | 2022-04-26 12:24:03.446681+00
latest_end_lsn        | 0/1713B90
latest_end_time       | 2022-04-26 12:24:04.442848+00
```

> Мы успешно подписались на публикацию таблицы test1 с db1

## db3 используем как реплику для чтения и бэкапов (подписываемся на таблицы из db1 и db2)

- на db3  включаем уровень logical

```sql
ALTER SYSTEM SET wal_level = logical;
```

> На уровне logical в журнал записывается та же информация, что и на уровне hot_standby, плюс информация, необходимая для извлечения из журнала наборов логических изменений. Повышение уровня до logical приводит к значительному увеличению объёма WA.

- перезагружаем сервер

```bash
pg_ctlcluster 14 main restart
```

- создаем базу и таблицу

```sql
\password 
create database test;
\c test;

CREATE TABLE test1 (i int,str varchar(10));
CREATE TABLE test2 (i int,str varchar(10));
```

- создаем подписку

```sql
CREATE SUBSCRIPTION test1_sub_db3
 CONNECTION 'host=192.168.56.11 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test1_pub WITH (copy_data = true);
CREATE SUBSCRIPTION test2_sub_db3
 CONNECTION 'host=192.168.56.12 port=5432 user=postgres password=postgres dbname=test'
 PUBLICATION test2_pub WITH (copy_data = true);
```

- просмотр созданной подписки

```sql
\dRs
              List of subscriptions
     Name      |  Owner   | Enabled | Publication 
---------------+----------+---------+-------------
 test1_sub_db3 | postgres | t       | {test1_pub}
 test2_sub_db3 | postgres | t       | {test2_pub}
(2 rows)
```

- просмотр состояния подписки

```sql
select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 16391
subname               | test1_sub_db3
pid                   | 20559
relid                 | 
received_lsn          | 0/1713C00
last_msg_send_time    | 2022-04-26 12:27:10.533847+00
last_msg_receipt_time | 2022-04-26 12:27:10.520474+00
latest_end_lsn        | 0/1713C00
latest_end_time       | 2022-04-26 12:27:10.533847+00
-[ RECORD 2 ]---------+------------------------------
subid                 | 16392
subname               | test2_sub_db3
pid                   | 20561
relid                 | 
received_lsn          | 0/1713BB0
last_msg_send_time    | 2022-04-26 12:27:15.147113+00
last_msg_receipt_time | 2022-04-26 12:27:16.03725+00
latest_end_lsn        | 0/1713BB0
latest_end_time       | 2022-04-26 12:27:15.147113+00
```

- сделаем выборку

```sql

select * from test1;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
(2 rows)

select * from test2;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
(3 rows)
```

> Мы успешно подписались на публикации таблиц test1 с db1 и test2 с db2

- на db1 проверим состояние репликации

```sql
select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 25266
usesysid         | 10
usename          | postgres
application_name | test1_sub
client_addr      | 192.168.56.12
client_hostname  | 
client_port      | 48296
backend_start    | 2022-04-26 12:24:04.399405+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1713C00
write_lsn        | 0/1713C00
flush_lsn        | 0/1713C00
replay_lsn       | 0/1713C00
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2022-04-26 12:27:59.72022+00
-[ RECORD 2 ]----+------------------------------
pid              | 25282
usesysid         | 10
usename          | postgres
application_name | test1_sub_db3
client_addr      | 192.168.56.13
client_hostname  | 
client_port      | 40994
backend_start    | 2022-04-26 12:27:10.485389+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1713C00
write_lsn        | 0/1713C00
flush_lsn        | 0/1713C00
replay_lsn       | 0/1713C00
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2022-04-26 12:28:00.637687+00
```

- на db1 посмотрим информацию о слотах репликации

```sql
select * from pg_replication_slots \gx
-[ RECORD 1 ]-------+--------------
slot_name           | test1_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16384
database            | test
temporary           | f
active              | t
active_pid          | 25266
xmin                | 
catalog_xmin        | 746
restart_lsn         | 0/1713BC8
confirmed_flush_lsn | 0/1713C00
wal_status          | reserved
safe_wal_size       | 
two_phase           | f
-[ RECORD 2 ]-------+--------------
slot_name           | test1_sub_db3
plugin              | pgoutput
slot_type           | logical
datoid              | 16384
database            | test
temporary           | f
active              | t
active_pid          | 25282
xmin                | 
catalog_xmin        | 746
restart_lsn         | 0/1713BC8
confirmed_flush_lsn | 0/1713C00
wal_status          | reserved
safe_wal_size       | 
two_phase           | f
```

- на db2 проверим состояние репликации

```sql
select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 25133
usesysid         | 10
usename          | postgres
application_name | test2_sub
client_addr      | 192.168.56.11
client_hostname  | 
client_port      | 54502
backend_start    | 2022-04-26 12:21:45.940604+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1713BB0
write_lsn        | 0/1713BB0
flush_lsn        | 0/1713BB0
replay_lsn       | 0/1713BB0
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2022-04-26 12:29:06.24142+00
-[ RECORD 2 ]----+------------------------------
pid              | 25182
usesysid         | 10
usename          | postgres
application_name | test2_sub_db3
client_addr      | 192.168.56.13
client_hostname  | 
client_port      | 42246
backend_start    | 2022-04-26 12:27:15.107497+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/1713BB0
write_lsn        | 0/1713BB0
flush_lsn        | 0/1713BB0
replay_lsn       | 0/1713BB0
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2022-04-26 12:29:06.249377+00
```

- на db2 посмотрим информацию о слотах репликации

```sql
select * from pg_replication_slots \gx
-[ RECORD 1 ]-------+--------------
slot_name           | test2_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16384
database            | test
temporary           | f
active              | t
active_pid          | 25133
xmin                | 
catalog_xmin        | 746
restart_lsn         | 0/1713B78
confirmed_flush_lsn | 0/1713BB0
wal_status          | reserved
safe_wal_size       | 
two_phase           | f
-[ RECORD 2 ]-------+--------------
slot_name           | test2_sub_db3
plugin              | pgoutput
slot_type           | logical
datoid              | 16384
database            | test
temporary           | f
active              | t
active_pid          | 25182
xmin                | 
catalog_xmin        | 746
restart_lsn         | 0/1713B78
confirmed_flush_lsn | 0/1713BB0
wal_status          | reserved
safe_wal_size       | 
two_phase           | f
```

## Реализуем горячее реплицирование для высокой доступности на db4. Источником будет выступать db3

- проверим необходимые настройки на db3

```sql
select current_setting('synchronous_commit');
 current_setting 
-----------------
 on
(1 row)

select current_setting('max_wal_senders');
 current_setting 
-----------------
 10
(1 row)

select current_setting('hot_standby');
 current_setting 
-----------------
 on
(1 row)

ALTER SYSTEM SET synchronous_standby_names = '*';
ALTER SYSTEM SET wal_keep_size = 64;

select pg_reload_conf();
```

> synchronous_commit = on - подтверждает, что произошла запись на диск в WAL файл

- перезагружаем сервер

```bash
pg_ctlcluster 14 main restart
```

- настроим db4

```bash
pg_ctlcluster 14 main stop
cd /var/lib/postgresql/14/
rm -rf main

sudo su postgres
cd /var/lib/postgresql/14/
mkdir main
chmod go-rwx main
pg_basebackup -P -R -X stream -c fast -h 192.168.56.13 -U postgres -D ./main

echo "recovery_target_timeline = 'latest'" >> /etc/postgresql/14/main/recovery.conf
```

> Ключ -R создаст заготовку управляющего файла recovery.conf  
> Команда спросит пароль пользователя postgres, который мы меняли при настройке мастера. Используйте -c fast, чтобы синкнуться как можно быстрее, или -c spread, чтобы минимизировать нагрузку. Еще есть флаг -r, позволяющий ограничить скорость передачи данных  
> recovery_target_timeline = 'latest' - когда у нас упадет мастер и мы запромоутим реплику до мастера, этот параметр позволит тянуть данные с него

- стартуем сервер

```bash
pg_ctlcluster 14 main start

pg_lsclusters
Ver Cluster Port Status          Owner    Data directory              Log file
14  main    5432 online,recovery postgres /var/lib/postgresql14main /var/log/postgresql/postgresql-12-main.log
```

- проверим необходимые настройки на db4 (… правим аналогично db3)

```sql
select current_setting('synchronous_commit');
 current_setting 
-----------------
 on
(1 row)

select current_setting('max_wal_senders');
 current_setting 
-----------------
 10
(1 row)

select current_setting('hot_standby');
 current_setting 
-----------------
 on
(1 row)

ALTER SYSTEM SET synchronous_standby_names = '*';
ALTER SYSTEM SET wal_keep_size = 64;

select pg_reload_conf();
```

- рестартуем сервер

```bash
pg_ctlcluster 14 main restart
```

- добавим пару строк в таблицу test2 insert into test2 values(4, 'строка4') на db2 и сделаем выборку на db4, чтобы убедиться, что репликация работает

```sql
select * from test1;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
(2 rows)

select * from test2;
 i |   str   
---+---------
 1 | строка1
 2 | строка2
 3 | строка3
 4 | строка4
 5 | строка5
(5 rows)
```

- на db3 проверим состояние репликации

```sql
test=# select * from pg_stat_replication \gx
-[ RECORD 1 ]----+------------------------------
pid              | 20712
usesysid         | 10
usename          | postgres
application_name | 14/main
client_addr      | 192.168.56.14
client_hostname  | 
client_port      | 37806
backend_start    | 2022-04-26 12:46:31.488377+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/70003A0
write_lsn        | 0/70003A0
flush_lsn        | 0/70003A0
replay_lsn       | 0/70003A0
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 1
sync_state       | sync
reply_time       | 2022-04-26 12:50:26.519449+00
```

```sql
select pg_current_wal_lsn();
 pg_current_wal_lsn 
--------------------
 0/70003A0
(1 row)
```

- на а db4 проверим состояние репликации

```sql
select pg_last_wal_receive_lsn();
 pg_last_wal_receive_lsn 
-------------------------
 0/70003A0
(1 row)
```

```sql
select  pg_last_wal_replay_lsn();
 pg_last_wal_replay_lsn 
------------------------
 0/70003A0
(1 row)
```

```sql
select * from pg_stat_wal_receiver \gx
-[ RECORD 1 ]---------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
pid                   | 27405
status                | streaming
receive_start_lsn     | 0/7000000
receive_start_tli     | 1
written_lsn           | 0/70003A0
flushed_lsn           | 0/70003A0
received_tli          | 1
last_msg_send_time    | 2022-04-26 12:51:16.829706+00
last_msg_receipt_time | 2022-04-26 12:51:16.551211+00
latest_end_lsn        | 0/70003A0
latest_end_time       | 2022-04-26 12:50:16.743796+00
slot_name             | 
sender_host           | 192.168.56.13
sender_port           | 5432
conninfo              | user=postgres password=******** channel_binding=prefer dbname=replication host=192.168.56.13 port=5432 fallback_application_name=14/main sslmode=prefer sslcompression=0 sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any
```

- также на db4 можно смотреть, как давно было последнее обновление данных с db3

```sql
select now()-pg_last_xact_replay_timestamp();
    ?column?     
-----------------
 00:00:41.663767
(1 row)
```
