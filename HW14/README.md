# Docker, docker image, docker container

- Создадим свой кастомный образ nginx на базе alpine. После запуска nginx будет отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)
- Определим разницу между контейнером и образом. Вывод опишем в домашнем задании.
- Ответим на вопрос: Можно ли в контейнере собрать ядро?
- Собранный образ запушим в docker hub и дадим ссылку на наш репозиторий
- Задание со *

## Создание кастомного образа nginx

- За основу нашего кастомного образа возьмем Dockerfile из https://github.com/nginxinc/docker-nginx/tree/master/stable/alpine

- Создадим кастомную страницу index.html и добавим инструкцию в Dockerfile

```Dockerfile
COPY index.html /usr/share/nginx/html/
```

- Билдим

```bash
docker build -t kovtalex/nginx:v1 .
```

- Запускаем контейнер

```bash
docker run -p 8080:80 --name nginx -d --rm kovtalex/nginx:v1
```

- Проверяем

```bash
docker ps                                                 
CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS          PORTS                  NAMES
ed2b7931f8e5   kovtalex/nginx:v1   "/docker-entrypoint.…"   14 minutes ago   Up 14 minutes   0.0.0.0:8080->80/tcp   nginx


curl localhost:8080                                         
<html>
  <body>
    <h1>Hello world!</h1>
  </body>
</html>
```

> Разница в контейнере и образе заключается в том, что в отличии от RO слоев образа контейнер имеет RW слой для работы приложения  
> Также в контейнере можно собрать ядро. Как пример можно присмотреться к проекту <https://github.com/a13xp0p0v/kernel-build-containers>

- Запушим собранный образ на docker hub

```bash
docker login ...

docker push 
```

> Ссылка на репозиторий с кастомным nginx <https://hub.docker.com/repository/docker/kovtalex/nginx>

## Задание со *

- Создадим кастомные образы nginx и php, объедините их в docker-compose
- После запуска nginx должен показывать php info
- Все собранные образы выгрузим в docker hub

- Для начала дополним наш образ nginx добавив собственную конфигурацию site.conf

```bash
server {
    listen       80;
    index index.php index.html;    
    server_name  localhost;
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /php;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
```

- Подготовим index.php для вывода php info

```bash
<?php phpinfo(); ?>
```

- Дополним Dockerfile

```Dockerfile
COPY site.conf /etc/nginx/conf.d/default.conf
COPY index.php /
```

Дополним docker-entrypoint.sh для того чтобы использовать каталог php как общий volume с контейнером php-fpm

```bash
cp -f /index.php /php/ || true
```

- Собираем nginx

```bash
docker build -t kovtalex/nginx:v2 .
```

- Подготовим Dockerfile для php-fpm

```Dockerfile
FROM alpine:3.14

RUN adduser -S www-data -G www-data && apk add --no-cache php7 php7-fpm && rm -rf /var/cache/apk/*

COPY php-fpm.conf /etc/php7/

ENTRYPOINT ["/usr/sbin/php-fpm7"]
CMD ["-F", "--fpm-config", "/etc/php7/php-fpm.conf"]
```

- Билдим php-fpm

```bash
docker build -t kovtalex/php-fpm:v1 .
```

- Подготовим docker-compose.yaml

```yml
version: '3.9'

services:
  nginx:
    image: kovtalex/nginx:v2
    ports:
      - 8080:80
    volumes:
      - php:/php
    networks:
      - hw14
  php:
    image: kovtalex/php-fpm:v1
    volumes:
      - php:/php    
    networks:
      - hw14

volumes:
  php:

networks:
  hw14:
```

- Запускаем

```bash
docker-compose up -d

docker-compose ps
    Name                  Command               State          Ports        
----------------------------------------------------------------------------
hw14_nginx_1   /docker-entrypoint.sh ngin ...   Up      0.0.0.0:8080->80/tcp
hw14_php_1     docker-php-entrypoint php-fpm    Up      9000/tcp
```

> Также добавим Makefile для удобства сборки и запуска

- Проверяем

```bash
curl http://localhost:8080/

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<style type="text/css">
body {background-color: #fff; color: #222; font-family: sans-serif;}
pre {margin: 0; font-family: monospace;}
a:link {color: #009; text-decoration: none; background-color: #fff;}
a:hover {text-decoration: underline;}
table {border-collapse: collapse; border: 0; width: 934px; box-shadow: 1px 2px 3px #ccc;}
.center {text-align: center;}
.center table {margin: 1em auto; text-align: left;}
.center th {text-align: center !important;}
td, th {border: 1px solid #666; font-size: 75%; vertical-align: baseline; padding: 4px 5px;}
th {position: sticky; top: 0; background: inherit;}
h1 {font-size: 150%;}
h2 {font-size: 125%;}
.p {text-align: left;}
.e {background-color: #ccf; width: 300px; font-weight: bold;}
.h {background-color: #99c; font-weight: bold;}
.v {background-color: #ddd; max-width: 300px; overflow-x: auto; word-wrap: break-word;}
.v i {color: #999;}
img {float: right; border: 0;}
hr {width: 934px; background-color: #ccc; border: 0; height: 1px;}
</style>
<title>PHP 8.1.1 - phpinfo()</title><meta name="ROBOTS" content="NOINDEX,NOFOLLOW,NOARCHIVE" /></head>
<body><div class="center">
<table>
<tr class="h"><td> ... alt="PHP logo" /></a><h1 class="p">PHP Version 8.1.1</h1>
</td></tr>
</table>
<table>
<tr><td class="e">System </td><td class="v">Linux 5d4d50d99e20 5.10.76-linuxkit #1 SMP Mon Nov 8 10:21:19 UTC 2021 x86_64 </td></tr>
<tr><td class="e">Build Date </td><td class="v">Dec 21 2021 19:45:33 </td></tr>
...
```
