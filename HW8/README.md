# HW8 - Systemd

## Напишем сервис, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Файл и слово должны задаваться в /etc/sysconfig

- Для начала создаём файл с конфигурацией для сервиса в директории /etc/sysconfig - из неё сервис будет брать необходимые переменные

vi /etc/sysconfig/watchlog

```bash
# Configuration file for my watchlog service
# Place it to /etc/sysconfig
# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```

- Затем создаем /var/log/watchlog.log и пишем туда строки на своё усмотрение, плюс ключевое слово **ALERT**

- Создадим скрипт vi /opt/watchlog.sh

```bash
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
  logger "$DATE: I found word, Master!"
else
  exit 0
fi
```

> Команда logger отправляет лог в системный журнал

- Создадим юнит для сервиса watchlog - vi /etc/systemd/system/watchlog.service

```bash
[Unit]
Description=My watchlog service
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

- Создадим юнит для таймера - vi /etc/systemd/system/watchlog.timer

```bash
[Unit]
Description=Run watchlog script every 30 second
[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service
[Install]
WantedBy=multi-user.target
```

- Затем достаточно тольþко стартануть timer

```bash
systemctl start watchlog.timer
```

- И убедиться в результате

```bash
tail -f /var/log/messages

Dec 14 12:10:59 localhost systemd: Started My watchlog service.
Dec 14 12:12:08 localhost systemd: Starting My watchlog service...
Dec 14 12:12:09 localhost root: Tue Dec 14 12:12:09 UTC 2021: I found word, Master!
Dec 14 12:12:09 localhost systemd: Started My watchlog service.
```

## Из epel установим spawn-fcgi и перепишем init-скрипт на unit-файл. Имя сервиса должно также называться

- Устанавливаем spawn-fcgi и необходимые для него пакеты

```bash
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
```

> /etc/rc.d/init.d/spawn-fcg - cам Init скрипт, который будем переписывать  
> Но перед этим необходимо раскомментировать строки с переменными в /etc/sysconfig/spawn-fcgi

Он должен получится следующего вида:

```bash
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
```

- А сам юнит файл будет следующего вида - vi /etc/systemd/system/spawn-fcgi.service

```bash
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target
[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
[Install]
WantedBy=multi-user.target
```

- Убеждаемся что все успешно работает

```bash
systemctl start spawn-fcgi
systemctl status spawn-fcgi

● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2021-12-14 12:21:17 UTC; 10s ago
 Main PID: 21900 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─21900 /usr/bin/php-cgi
           ├─21901 /usr/bin/php-cgi
           ├─21902 /usr/bin/php-cgi
           ├─21903 /usr/bin/php-cgi
           ├─21904 /usr/bin/php-cgi
           ├─21905 /usr/bin/php-cgi
           ├─21906 /usr/bin/php-cgi
           ├─21907 /usr/bin/php-cgi
           ├─21908 /usr/bin/php-cgi
           ├─21909 /usr/bin/php-cgi
           ├─21910 /usr/bin/php-cgi
           ├─21911 /usr/bin/php-cgi
           ├─21912 /usr/bin/php-cgi
           ├─21913 /usr/bin/php-cgi
           ├─21914 /usr/bin/php-cgi
           ├─21915 /usr/bin/php-cgi
           ├─21916 /usr/bin/php-cgi
           ├─21917 /usr/bin/php-cgi
           ├─21918 /usr/bin/php-cgi
           ├─21919 /usr/bin/php-cgi
           ├─21920 /usr/bin/php-cgi
           ├─21921 /usr/bin/php-cgi
           ├─21922 /usr/bin/php-cgi
           ├─21923 /usr/bin/php-cgi
           ├─21924 /usr/bin/php-cgi
           ├─21925 /usr/bin/php-cgi
           ├─21926 /usr/bin/php-cgi
           ├─21927 /usr/bin/php-cgi
           ├─21928 /usr/bin/php-cgi
           ├─21929 /usr/bin/php-cgi
           ├─21930 /usr/bin/php-cgi
           ├─21931 /usr/bin/php-cgi
           └─21932 /usr/bin/php-cgi

Dec 14 12:21:17 hw8 systemd[1]: Started Spawn-fcgi startup service by Otus.
```

## Дополним юнит-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигами

- Для запуска нескольких экземпляров сервиса будем использовать шаблон в конфигурации файла окружения - vi /etc/systemd/system/httpd@second.service /etc/systemd/system/httpd@first.service

```bash
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true
[Install]
WantedBy=multi-user.target
```

> Добавим параметр %I к EnvironmentFile=/etc/sysconfig/httpd

- В самом файле окружения (которых будет два) задается опция для запуска веб-сервера с необходимым конфигурационным файлом

/etc/sysconfig/httpd-first

```bash
OPTIONS=-f conf/first.conf
```

/etc/sysconfig/httpd-second

```bash
OPTIONS=-f conf/second.conf
```

- Соответственно в директории с конфигами httpd должны лежать два конфига, в нашем случае это будут first.conf и second.conf

```bash
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf                              
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
```

> Для удачного запуска, в конфигурационных файлах должны быть указаны уникальные для каждого экземпляра опции **Listen** и **PidFile**.  

- Конфиги можно скопировать и поправить только второй, в нем должна быть следующие опции

```bash
PidFile /var/run/httpd-second.pid
Listen 8080
```

- Запустим

```bash
systemctl start httpd@first
systemctl start httpd@second
```

- Проверить можно несколькими способами, например посмотреть какие порты слушаются

```bash
ss -tnulp | grep httpd

tcp    LISTEN     0      128    [::]:8080               [::]:*                   users:(("httpd",pid=23502,fd=4),("httpd",pid=23501,fd=4),("httpd",pid=23500,fd=4),("httpd",pid=23499,fd=4),("httpd",pid=23498,fd=4),("httpd",pid=23497,fd=4),("httpd",pid=23496,fd=4))
tcp    LISTEN     0      128    [::]:80                 [::]:*                   users:(("httpd",pid=21992,fd=4),("httpd",pid=21991,fd=4),("httpd",pid=21990,fd=4),("httpd",pid=21989,fd=4),("httpd",pid=21988,fd=4),("httpd",pid=21987,fd=4),("httpd",pid=21986,fd=4))
```

## Задание со * - Скачаем демо-версию Atlassian Jira и перепишем основной скрипт запуска на unit-файл

- Скачиваем и устанавливаем Jira

```bash
wget https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-8.21.0-x64.bin
chmod a+x atlassian-jira-software-8.21.0-x64.bin
sudo ./atlassian-jira-software-8.21.0-x64.bin
```

- Создаем systemd unit

```bash
touch /lib/systemd/system/jira.service
chmod 664 /lib/systemd/system/jira.service
```

- Добавляем следующий контент в /lib/systemd/system/jira.service

```bash
[Unit] 
Description=Atlassian Jira
After=network.target

[Service] 
Type=forking
User=jira
LimitNOFILE=20000
PIDFile=/opt/atlassian/jira/work/catalina.pid
ExecStart=/opt/atlassian/jira/bin/start-jira.sh
ExecStop=/opt/atlassian/jira/bin/stop-jira.sh

[Install] 
WantedBy=multi-user.target
```

- останавливаем текущий сервис

```bash
service jira stop
```

- Запускаем наш новый сервис и проверяем, что все в порядке

```bash
systemctl daemon-reload
systemctl enable jira.service
systemctl start jira.service
systemctl status jira.service
● jira.service - Atlassian Jira
   Loaded: loaded (/usr/lib/systemd/system/jira.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2021-12-15 10:45:25 UTC; 531ms ago
  Process: 2449 ExecStart=/opt/atlassian/jira/bin/start-jira.sh (code=exited, status=0/SUCCESS)
 Main PID: 2484 (java)
   CGroup: /system.slice/jira.service
           └─2484 /opt/atlassian/jira/jre//bin/java -Djava.util.logging.config.file=/opt/atlassian/jira/conf/logging.properties -Djava.util.logging.manag...

Dec 15 10:45:25 hw8 start-jira.sh[2449]: MMMMMM    `UOJ
Dec 15 10:45:25 hw8 start-jira.sh[2449]: MMMMMM
Dec 15 10:45:25 hw8 start-jira.sh[2449]: +MMMMM
Dec 15 10:45:25 hw8 start-jira.sh[2449]: MMMMM
Dec 15 10:45:25 hw8 start-jira.sh[2449]: `UOJ
Dec 15 10:45:25 hw8 start-jira.sh[2449]: Atlassian Jira
Dec 15 10:45:25 hw8 start-jira.sh[2449]: Version : 8.21.0
Dec 15 10:45:25 hw8 start-jira.sh[2449]: If you encounter issues starting or stopping Jira, please see the Troubleshooting guide at https://docs...tallation
Dec 15 10:45:25 hw8 start-jira.sh[2449]: Server startup logs are located in /opt/atlassian/jira/logs/catalina.out
Dec 15 10:45:25 hw8 systemd[1]: Started Atlassian Jira.
Hint: Some lines were ellipsized, use -l to show in full.
```
