# HW13 - PAM

- Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников
- Дадим конкретному пользователю права работать с докером и возможность рестартить докер сервис

## Для выполения первой части ДЗ был

- использован модуль pam_exec.so и написан скрипт [pam_script.sh](./pam_script.sh)
- создан тестовый пользователь test_admin входящий в группу admin

## Для выполения второй части ДЗ была

- использована библиотека PolKit
- созданный тестовый пользователь test_docker входящий в группы docker и admin
- написано [правило](./10-docker.rules), позволяющее только перезагружать только docker сервис

> Для выполнения ДЗ был использован Centos 8, т.к.:  **...buuuuuut with systemd v219 in Centos 7, action does not have access to the unit! This has been added in v226...**

Обходной вариант для Centos 7:

```bash
cat > /etc/sudoers.d/docker << EOF
test_docker ALL= NOPASSWD: /bin/systemctl restart docker.service
EOF
```

## Проверка

- для начала попробуем залогиниться пользователем vagrant

```bash
ssh -o IdentitiesOnly=yes vagrant@127.0.0.1 -p 2222
vagrant@127.0.0.1's password: 
/usr/local/bin/pam_script.sh failed: exit code 1
Connection closed by 127.0.0.1 port 2222
```

> Нас постигнет неудача, т.к. сегодня воскресенье

- теперь попробуем залогиниться пользователем test_admin входящим в группу admin

```bash
ssh -o IdentitiesOnly=yes test_admin@127.0.0.1 -p 2222
test_admin@127.0.0.1's password:
[test_admin@hw13 ~]$
```

> Успех

- попробуем запустить контейнер и перезапустить сервис docker с текущим пользователем

```bash
[test_admin@hw13 ~]$ docker run -d nginx
docker: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/create": dial unix /var/run/docker.sock: connect: permission denied.
See 'docker run --help'.

systemctl restart docker
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ====
Authentication is required to restart 'docker.service'.
Authenticating as: root
Password: 
[test_admin@hw13 ~]$
```

> Неудача, т.к. не хватает прав

- теперь попробуем залогиниться пользователем test_docker входящим в группу docker и admin

```bash
ssh -o IdentitiesOnly=yes test_docker@127.0.0.1 -p 2222
test_docker@127.0.0.1's password: 

[test_docker@hw13 ~]$
[test_docker@hw13 ~]$ docker run -d nginx
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
a2abf6c4d29d: Pull complete 
a9edb18cadd1: Pull complete 
589b7251471a: Pull complete 
186b1aaa4aa6: Pull complete 
b4df32aa5a72: Pull complete 
a0bcbecc962e: Pull complete 
Digest: sha256:0d17b565c37bcbd895e9d92315a05c1c3c9a29f762b011a10c54a66cd53c9b31
Status: Downloaded newer image for nginx:latest
f6900fc740e5bca42c11422c7630ce377c3bac6ebd5ae7423ad7f6e88f1ef297


[test_docker@hw13 ~]$ docker ps -a
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS     NAMES
f6900fc740e5   nginx     "/docker-entrypoint.…"   33 seconds ago   Up 32 seconds   80/tcp    focused_gauss


[test_docker@hw13 ~]$ systemctl restart docker
[test_docker@hw13 ~]$ 
```

> Мы успешно запустили контейнер и перезапустили сервис докер
