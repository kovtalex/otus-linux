# HW12 - Практика с SELinux

## Ввведение

SElinux (Security Enhanced Linux) – система принудительного (мандатного) контроля доступа (MAC). Разрабатывалась АНБ. В 2003 году вошла в состав ядра linux 2.6.x.

SELinux следует модели минимально необходимых привилегий для каждого сервиса пользователя и программы.

Зачем нужен Selinux:

- Гибкое ограничение прав пользователей и процессов на уровне ядра
- Работа совместно с DAC (матричным управлением доступа)
- Снижение риска, возникающего вследствие допущенных ошибок
- Ограничение потенциально опасных или скомпрометированных процессов в правах
- Протоколирование

Обычно в В Selinux большие и сложные политики. Каждый ресурс должен быть описан и сопоставлен с сервисом.

Режимы работы SELinux:

- Enforcing (по-умолчанию) – Активная работа. Всё, что нарушает политику безопасности блокируется. Попытка нарушения фиксируется в журнале
- Permissive — запрещенные действия не блокируются. Все нарушения пишутся в журнал
- Disabled — полное отключение SELinux.

> Важно помнить: классическая система прав Unix применяется первой и управление перейдёт к SELinux только в том случае, если эта первичная проверка будет успешно пройдена

Написать политику SELinux достаточно сложно, но для ключевых приложений и сервисов (например httpd, mysqld, dhcpd и т.д.) определены заранее сконфигурированные политики, которые не позволят получить злоумышленнику доступ к важным данным.  
Те приложения, для которых политика не определена, выполняются в домене unconfined_f и не защищаются SELinux.

## Цели домашнего задания

Диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется.

## Описание домашнего задания

Запустить nginx на нестандартном порту 3-мя разными способами:

- переключатели setsebool
- добавление нестандартного порта в имеющийся тип
- формирование и установка модуля SELinux

Обеспечить работоспособность приложения при включенном selinux.

- развернуть приложенный [стенд](https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems)
- выяснить причину неработоспособности механизма обновления зоны
- предложить решение (или решения) для данной проблемы
- выбрать одно из решений для реализации, предварительно обосновав выбор
- реализовать выбранное решение и продемонстрировать его работоспособность

## Пошаговая инструкция выполнения домашнего задания

### Создаём виртуальную машину

- создаем Vagrantfile и выполняем vagrant up

Результатом выполнения команды vagrant up станет созданная виртуальная машина с установленным nginx, который работает на порту TCP 4881. Порт TCP 4881 уже проброшен до хоста. SELinux включен.

Во время развёртывания стенда попытка запустить nginx завершится с ошибкой:

```bash
    selinux: Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
    selinux: ● nginx.service - The nginx HTTP and reverse proxy server
    selinux:    Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
    selinux:    Active: failed (Result: exit-code) since Wed 2022-01-19 20:47:51 UTC; 11ms ago
    selinux:   Process: 2882 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
    selinux:   Process: 2881 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    selinux: 
    selinux: Jan 19 20:47:51 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
    selinux: Jan 19 20:47:51 selinux nginx[2882]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    selinux: Jan 19 20:47:51 selinux nginx[2882]: nginx: [emerg] bind() to [::]:4881 failed (13: Permission denied)
    selinux: Jan 19 20:47:51 selinux nginx[2882]: nginx: configuration file /etc/nginx/nginx.conf test failed
    selinux: Jan 19 20:47:51 selinux systemd[1]: nginx.service: control process exited, code=exited status=1
    selinux: Jan 19 20:47:51 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
    selinux: Jan 19 20:47:51 selinux systemd[1]: Unit nginx.service entered failed state.
    selinux: Jan 19 20:47:51 selinux systemd[1]: nginx.service failed.
```

> Данная ошибка появляется из-за того, что SELinux блокирует работу nginx на нестандартном порту.

- Заходим на сервер: vagrant ssh

> Дальнейшие действия выполняются от пользователя root. Переходим в root пользователя: sudo -i

## Запуск nginx на нестандартном порту 3-мя разными способами

- Для начала проверим, что в ОС отключен файервол

```bash
systemctl status firewalld

● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:firewalld(1)
```

- Также можно проверить, что конфигурация nginx настроена без ошибок

```bash
nginx -t

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

- Далее проверим режим работы SELinux

```bash
getenforce
Enforcing
```

> Должен отображаться режим Enforcing. Данный режим означает, что SELinux будет блокировать запрещенную активность

### Разрешим в SELinux работу nginx на порту TCP 4881 c помощью переключателей setsebool

- Находим в логах (/var/log/audit/audit.log) информацию о блокировании порта

```bash
cat /var/log/audit/audit.log | grep 4881

type=AVC msg=audit(1642625271.254:819): avc:  denied  { name_bind } for  pid=2882 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```

- Копируем время, в которое был записан этот лог, и, с помощью утилиты audit2why смотрим информации о запрете

```bash
grep 642625271.254:819 /var/log/audit/audit.log | audit2why

type=AVC msg=audit(1642625271.254:819): avc:  denied  { name_bind } for  pid=2882 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly. 
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1
```

> Утилита audit2why покажет почему трафик блокируется. Исходя из вывода утилиты, мы видим, что нам нужно поменять параметр nis_enabled

- Включим параметр nis_enabled и перезапустим nginx

```bash
setsebool -P nis_enabled on
systemctl restart nginx
systemctl status nginx

● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-01-19 20:59:59 UTC; 10s ago
  Process: 3183 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3180 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3179 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3185 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3185 nginx: master process /usr/sbin/nginx
           └─3187 nginx: worker process

Jan 19 20:59:59 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jan 19 20:59:59 selinux nginx[3180]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jan 19 20:59:59 selinux nginx[3180]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jan 19 20:59:59 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```

- Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу <http://127.0.0.1:4881>

- Проверить статус параметра можно с помощью команды

```bash
getsebool -a | grep nis_enabled

nis_enabled --> on
```

- Вернём запрет работы nginx на порту 4881 обратно. Для этого отключим nis_enabled

```bash
setsebool -P nis_enabled off
```

> После отключения nis_enabled служба nginx снова не запустится

### Теперь разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип

- Поиск имеющегося типа, для http трафика

```bash
semanage port -l | grep http

http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

- Добавим порт в тип http_port_t

```bash
semanage port -a -t http_port_t -p tcp 4881

semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

- Теперь перезапустим службу nginx и проверим её работу

```bash
systemctl restart nginx

systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-01-19 21:09:51 UTC; 15s ago
  Process: 3283 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3281 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3280 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3285 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3285 nginx: master process /usr/sbin/nginx
           └─3287 nginx: worker process

Jan 19 21:09:51 selinux systemd[1]: Stopped The nginx HTTP and reverse proxy server.
Jan 19 21:09:51 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jan 19 21:09:51 selinux nginx[3281]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jan 19 21:09:51 selinux nginx[3281]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jan 19 21:09:51 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```

- Также можно проверить работу nginx из браузера. Заходим в любой браузер на хосте и переходим по адресу <http://127.0.0.1:4881>

- Удалить нестандартный порт из имеющегося типа можно с помощью команды

```bash
semanage port -d -t http_port_t -p tcp 4881

semanage port -l | grep http_port_t
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988

systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.

● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: failed (Result: exit-code) since Wed 2022-01-19 21:13:14 UTC; 26s ago
  Process: 3283 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3313 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
  Process: 3311 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3285 (code=exited, status=0/SUCCESS)

Jan 19 21:13:14 selinux systemd[1]: Stopped The nginx HTTP and reverse proxy server.
Jan 19 21:13:14 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jan 19 21:13:14 selinux nginx[3313]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jan 19 21:13:14 selinux nginx[3313]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jan 19 21:13:14 selinux nginx[3313]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jan 19 21:13:14 selinux systemd[1]: nginx.service: control process exited, code=exited status=1
Jan 19 21:13:14 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
Jan 19 21:13:14 selinux systemd[1]: Unit nginx.service entered failed state.
Jan 19 21:13:14 selinux systemd[1]: nginx.service failed.
```

### Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux

- Попробуем снова запустить nginx

```bash
systemctl start nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```

- Nginx не запуститься, так как SELinux продолжает его блокировать. Посмотрим логи SELinux, которые относятся к nginx

```bash
grep nginx /var/log/audit/audit.log

type=SYSCALL msg=audit(1642626927.353:905): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=55c40c14b858 a2=10 a3=7ffe5e98aef0 items=0 ppid=1 pid=3325 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)
type=SERVICE_START msg=audit(1642626927.361:906): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'
```

- Воспользуемся утилитой audit2allow для того, чтобы на основе логов SELinux сделать модуль, разрешающий работу nginx на нестандартном
порту

```bash
grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp
```

- Audit2allow сформировал модуль, и сообщил нам команду, с помощью которой можно применить данный модуль

```bash
semodule -i nginx.pp
```

- Попробуем снова запустить nginx

```bash
systemctl start nginx

systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-01-19 21:19:20 UTC; 5s ago
  Process: 3353 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3351 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3350 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3355 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3355 nginx: master process /usr/sbin/nginx
           └─3356 nginx: worker process

Jan 19 21:19:20 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jan 19 21:19:20 selinux nginx[3351]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jan 19 21:19:20 selinux nginx[3351]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jan 19 21:19:20 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```

> После добавления модуля nginx запустился без ошибок. При использовании модуля изменения сохранятся после перезагрузки.  
> Просмотр всех установленных модулей: semodule -l

Для удаления модуля воспользуемся командой

```bash
semodule -r nginx
libsemanage.semanage_direct_remove_key: Removing last nginx module (no other nginx module exists at another priority).
```

> Результатом выполнения данного задания будет подготовленная документация

## Обеспечение работоспособности приложения при включенном SELinux

- Выполним клонирование репозитория

```bash
git clone https://github.com/mbfx/otus-linux-adm.git
Клонирование в «otus-linux-adm»…
remote: Enumerating objects: 542, done.
remote: Counting objects: 100% (440/440), done.
remote: Compressing objects: 100% (295/295), done.
remote: Total 542 (delta 118), reused 381 (delta 69), pack-reused 102
Получение объектов: 100% (542/542), 1.38 МиБ | 2.94 МиБ/с, готово.
Определение изменений: 100% (133/133), готово.
```

- Перейдём в каталог со стендом: cd otus-linux-adm/selinux_dns_problems
- Развернём 2 ВМ с помощью vagrant: vagrant up
- После того, как стенд развернется, проверим ВМ с помощью команды

```bash
vagrant status

Current machine states:

ns01                      running (virtualbox)
client                    running (virtualbox)
```

- Подключимся к клиенту

```bash
vagrant ssh client
```

- Попробуем внести изменения в зону

```bash
nsupdate -k /etc/named.zonetransfer.key

> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
```

- Изменения внести не получилось. Давайте посмотрим логи SELinux, чтобы понять в чём может быть проблема
- Для этого воспользуемся утилитой audit2why

```bash
sudo -i
cat /var/log/audit/audit.log | audit2why
```

> Тут мы видим, что на клиенте отсутствуют ошибки

- Не закрывая сессию на клиенте, подключимся к серверу ns01 и проверим логи SELinux

```bash
vagrant ssh ns01
sudo -i

cat /var/log/audit/audit.log | audit2why

type=AVC msg=audit(1642628500.431:1914): avc:  denied  { create } for  pid=5163 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.
```

> В логах мы видим, что ошибка в контексте безопасности. Вместо типа named_t используется тип etc_t

- Проверим данную проблему в каталоге /etc/named

```bash
ls -laZ /etc/named

drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
```

> Тут мы также видим, что контекст безопасности неправильный. Проблема заключается в том, что конфигурационные файлы лежат в другом каталоге.

- Посмотреть в каком каталоги должны лежать, файлы, чтобы на них распространялись правильные политики SELinux можно с помощью команды

```bash
sudo semanage fcontext -l | grep named

/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0 
/var/named/chroot/var/named(/.*)?                  all files          system_u:object_r:named_zone_t:s0 
```

- Изменим тип контекста безопасности для каталога /etc/named

```bash
chcon -R -t named_zone_t /etc/named

ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:named_zone_t:s0 .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab
```

- Попробуем снова внести изменения с клиента

```bash
nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit

dig www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12657
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; AUTHORITY SECTION:
ddns.lab.               3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10

;; Query time: 3 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Wed Jan 19 21:53:48 UTC 2022
;; MSG SIZE  rcvd: 96
```

- Видим, что изменения применились. Попробуем перезагрузить хосты и ещё раз сделать запрос с помощью dig

```bash
dig @192.168.50.10 www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.8 <<>> @192.168.50.10 www.ddns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 30151
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; AUTHORITY SECTION:
ddns.lab.               3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Wed Jan 19 21:54:43 UTC 2022
;; MSG SIZE  rcvd: 96
```

> Всё правильно. После перезагрузки настройки сохранились.

- Для того, чтобы вернуть правила обратно, можно ввести команду

```bash
restorecon -v -R /etc/named

restorecon reset /etc/named context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.dns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.dns.lab.view1 context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic context unconfined_u:object_r:named_zone_t:s0->unconfined_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab.view1 context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab.view1.jnl context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.newdns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.50.168.192.rev context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
```

Результатом выполнения данного задания будет:

- README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них
- исправленный стенд или демонстрация работоспособной системы с описанием
