#!/bin/bash

yum install -y yum-utils

source /etc/os-release
dnf install -y https://zfsonlinux.org/epel/zfs-release.el8_4.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux

dnf config-manager --disable zfs
dnf config-manager --enable zfs-kmod
dnf install -y zfs
#modprobe zfs
