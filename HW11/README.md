# HW11 - Первые шаги с Ansible

Подготовим стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible развернем nginx со следующими условиями:

- необходимо использовать модуль yum и официальный репозиторий NGINX
- конфигурационные файлы должны быть взяты из шаблона jinja2 с переменными
- после установки nginx должен быть в режиме enabled в systemd
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible

## Напишем роль nginx

- используем официальный [репозиторий](./nginx/files/nginx.repo) NGINX
- напишем нашу [таску](./nginx/tasks/main.yml)
- используем [шаблон](./nginx/templates/default.conf) конфигурации nginx для параметризации порта сервера
- зададим [переменную](./nginx/defaults/main.yml) по умолчанию для порта nginx
- используем [handler](./nginx/handlers/main.yml) для настройки сервиса nginx и перезагрузки после изменения конфигурации
- [плейбук](./web.yml)
- создадим [Vagrantfile](./Vagrantfile) для нашего стенда и запуска nginx на порту 8080

## Запуск и проверка

- запуск

```bash
vagrant up
```

- проверка

```bash
vagrant port
    22 (guest) => 2222 (host)
  8080 (guest) => 8080 (host)

curl 127.0.0.1:8080
...
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
...
```

## Опционально добавим проверку нашей роли с помощью инструмента Molecule

- установим все необходимые компоненты для тестирования в requirements.txt и установим их

```bash
pip install -r requirements.txt
```

- добавим несколько [тестов](./nginx/molecule/default/tests/test_default.py), используя модули Testinfra для проверки конфигурации, что nginx установлен, запущен, запустится после перезагрузки сервера и отвечает на 8080 порту ([конфигурация](./nginx/molecule/default/molecule.yml))

- проверяем

```bash
cd nginx
molecule test

...
============================= test session starts ==============================
platform darwin -- Python 3.9.9, pytest-6.2.5, py-1.11.0, pluggy-1.0.0
rootdir: /Users/alexey
plugins: testinfra-6.5.0
collected 4 items

molecule/default/tests/test_default.py ....                              [100%]

============================== 4 passed in 3.28s ===============================
INFO     Verifier completed successfully.
...
```
