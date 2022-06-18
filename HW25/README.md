# HW-25 - LDAP

- Написан Ansible [playbook](./ansible/provision.yml) для конфигурации сервера и клиента
- Настроена аутентификация по SSH-ключам
- Firewall включен на сервере и на клиенте

Развертывание:

```bash
vagant up --no-provision
vagrant provision ipaserver
```

Проверка подключения созданного пользователя:

```bash
vagrant ssh ipaclient 
Last login: Sat Jun 18 17:07:03 2022 from 10.0.2.2
[vagrant@ipaclient ~]$ ssh test_user@localhost
Creating home directory for test_user.
[test_user@ipaclient ~]$
```
