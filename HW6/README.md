# HW6 - Размещение своего RPM в своем репозитории

## Описание

1) Создадимм свой RPM пакет на основе nginx с поддержкой openssl
2) Создадим свой репозиторий и разместим там ранее собранный RPM

- Для данного задания нам понадобятся следующие установленные пакеты

```bash
yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc perl-IPC-Cmd perl-Data-Dumper
```

- Для примера возьмем пакет NGINX и соберем его с поддержкой openssl
- Загрузим SRPM пакет NGINX для дальнейшей работы над ним
- При установке такого пакета в домашней директории создается древо каталогов для сборки

```bash
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.2-1.el7.ngx.src.rpm
rpm -i nginx-1.20.2-1.el7.ngx.src.rpm
```

- Также нужно скачать и разархивировать исходники для openssl - они потребуются при сборке

```bash
wget --no-check-certificate https://www.openssl.org/source/openssl-3.0.0.tar.gz
tar -xvf openssl-3.0.0.tar.gz
```

- Заранее поставим все зависимости чтобы в процессе сборки не было ошибок

```bash
yum-builddep -y rpmbuild/SPECS/nginx.spec
```

- Ну и собственно поправим сам [spec](https://gist.github.com/lalbrekht/6c4a989758fccf903729fc55531d3a50) файл, чтобы NGINX собирался с необходимыми нам опциями: **--with-openssl=/root/openssl-3.0.0**

vi rpmbuild/SPECS/nginx.spec

```bash
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-openssl=/root/openssl-3.0.0 \
    --with-debug
```

> По этой [ссылке](https://nginx.org/ru/docs/configure.html) можно посмотреть все доступные опции для сборки

- Теперь можно приступить к сборке RPM пакета

```bash
rpmbuild -bb rpmbuild/SPECS/nginx.spec

Проверка на неупакованный(е) файл(ы): /usr/lib/rpm/check-files /root/rpmbuild/BUILDROOT/nginx-1.20.2-1.el7.ngx.x86_64
Записан: /root/rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-debuginfo-1.20.2-1.el7.ngx.x86_64.rpm
Выполняется(%clean): /bin/sh -e /var/tmp/rpm-tmp.Dvui8x
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.20.2
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.20.2-1.el7.ngx.x86_64
+ exit 0
```

- Убедимся, что пакеты создались

```bash
ll rpmbuild/RPMS/x86_64/
total 4756
-rw-r--r--. 1 root root 2816348 ноя 22 22:02 nginx-1.20.2-1.el7.ngx.x86_64.rpm
-rw-r--r--. 1 root root 2048056 ноя 22 22:02 nginx-debuginfo-1.20.2-1.el7.ngx.x86_64.rpm
```

- Теперь можно установить наш пакет и убедиться, что nginx работает

```bash
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm

Installed:
  nginx.x86_64 1:1.20.2-1.el7.nginx

Complete!
```

- стартуем

```bash
systemctl enable nginx
systemctl start nginx
systemctl status nginx
● nginx.service - nginx - high performance web server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Пн 2021-11-22 22:04:42 UTC; 8s ago
     Docs: http://nginx.org/en/docs/
  Process: 6005 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)
 Main PID: 6006 (nginx)
   CGroup: /system.slice/nginx.service
           ├─6006 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
           ├─6007 nginx: worker process
           └─6008 nginx: worker process

ноя 22 22:04:42 hw6 systemd[1]: Starting nginx - high performance web server...
ноя 22 22:04:42 hw6 systemd[1]: Started nginx - high performance web server.
```

- Теперь приступим к созданию своего репозитория. Директория для статики у NGINX по умолчанию /usr/share/nginx/html. Создадим там каталог repo

```bash
mkdir /usr/share/nginx/html/repo
```

- Копируем туда наш собранный RPM и, например, RPM для установки репозитория Percona-Server

```bash
cp rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
```

```bash
wget https://downloads.percona.com/downloads/percona-release/percona-release-1.0-9/redhat/percona-release-1.0-9.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm

Сохранение в: «/usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm»

100%[=======================================================================================================================================================>] 16 664      --.-K/s   за 0,1s    

2021-11-22 22:10:15 (121 KB/s) - «/usr/share/nginx/html/repo/percona-release-1.0-9.noarch.rpm» сохранён [16664/16664]
```

- Инициализируем репозиторий командой

```bash
createrepo -v /usr/share/nginx/html/repo

Spawning worker 0 with 1 pkgs
Spawning worker 1 with 1 pkgs
Worker 0: reading nginx-1.20.2-1.el7.ngx.x86_64.rpm
Worker 1: reading percona-release-1.0-9.noarch.rpm
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Starting other db creation: Tue Nov 23 10:25:54 2021
Ending other db creation: Tue Nov 23 10:25:54 2021
Starting filelists db creation: Tue Nov 23 10:25:54 2021
Ending filelists db creation: Tue Nov 23 10:25:54 2021
Starting primary db creation: Tue Nov 23 10:25:54 2021
Ending primary db creation: Tue Nov 23 10:25:54 2021
Sqlite DBs complete
```

- Для прозрачности настроим в NGINX доступ к листингу каталога
- В location / в файле /etc/nginx/conf.d/default.conf добавим директиву autoindex on. В результате location будет выглядеть так

vi /etc/nginx/conf.d/default.conf

```bash
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        autoindex on;
    }
```

- Проверяем синтаксис и перезапускаем NGINX

```bash
nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

nginx -s reload
```

- Теперь ради интереса можно посмотреть в браузере или выполнить curl

```bash
curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          22-Nov-2021 22:13                   -
<a href="nginx-1.20.2-1.el7.ngx.x86_64.rpm">nginx-1.20.2-1.el7.ngx.x86_64.rpm</a>                  22-Nov-2021 22:13             2816348
<a href="percona-release-1.0-9.noarch.rpm">percona-release-1.0-9.noarch.rpm</a>                   11-Nov-2020 21:49               16664
</pre><hr></body>
</html>
```

- Все готово для того, чтобы протестировать репозиторий
- Добавим его в /etc/yum.repos.d

```bash
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
```

- Убедимся, что репозиторий подключился и посмотрим что в нем есть

```bash
yum repolist enabled | grep otus
otus                                otus-linux                                 2
```

```bash
yum list | grep nginx
nginx.x86_64                                1:1.20.2-1.el7.ngx         @/nginx-1.20.2-1.el7.ngx.x86_64
```

- Так как NGINX у нас уже стоит, установим репозиторий percona-release

```bash
yum install percona-release -y

Установлено:
  percona-release.noarch 0:1.0-9                                                                                                                                                                 

Выполнено!
```

- Все прошло успешно. В случае если нам потребуется обновить репозиторий (а это делается при каждом добавлении файлов) снова, то выполним команду **createrepo /usr/share/nginx/html/repo/**

Ссылка на репозиторий: http://185.189.69.126/repo/

## Задание со *

- Создадим [Dockerfile](./Dockerfile) описывающий multi-stage build
- Для компиляции возьмем базовый образ centos:7
- Для финального образа возьмем centos/systemd

```Dockerfile
FROM centos:7 AS builder

WORKDIR /root

RUN yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc perl-IPC-Cmd perl-Data-Dumper

RUN wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.2-1.el7.ngx.src.rpm && rpm -i nginx-1.20.2-1.el7.ngx.src.rpm
RUN wget --no-check-certificate https://www.openssl.org/source/openssl-3.0.0.tar.gz && tar -xvf openssl-3.0.0.tar.gz

RUN yum-builddep -y rpmbuild/SPECS/nginx.spec

RUN sed -i 's/--with-debug/--with-openssl=\/root\/openssl-3.0.0 --with-debug/g' ./rpmbuild/SPECS/nginx.spec
RUN rpmbuild -bb rpmbuild/SPECS/nginx.spec


FROM centos/systemd:latest

EXPOSE 80

COPY --from=builder /root/rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm /tmp
RUN yum localinstall -y /tmp/nginx-1.20.2-1.el7.ngx.x86_64.rpm; systemctl enable nginx

CMD ["/usr/sbin/init"]
```

- Билдим и запускаем

```bash
docker build  --rm  -t kovtalex/nginx-systemd .
docker run --privileged --name nginx -v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 80:80 -d  kovtalex/nginx-systemd
```

- Проверяем

```bash
curl localhost

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
