import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_nginx_is_installed(host):
    nginx = host.package('nginx')
    assert nginx.is_installed


def test_nginx_is_enabled(host):
    nginx = host.service('nginx')
    assert nginx.is_enabled


def test_nginx_is_running(host):
    nginx = host.service('nginx')
    assert nginx.is_running


def test_nginx_port_is_reachable(host):
    all_variables = host.ansible.get_variables()
    nginx = host.addr("0.0.0.0")
    assert nginx.port(all_variables['listen_port']).is_reachable
