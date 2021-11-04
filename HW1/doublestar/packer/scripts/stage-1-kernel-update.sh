#!/bin/bash

yum install centos-release-scl -y
yum clean all
yum install devtoolset-10-* -y
source scl_source enable devtoolset-10

yum install -y ncurses-devel make bc bison flex elfutils-libelf-devel openssl-devel grub2 wget yum-utils

cd /usr/src/
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar -xvf linux-5.15.tar.xz
cd linux-5.15/

cp -v /boot/config-$(uname -r) /usr/src/linux-5.15/.config

yes "" | make oldconfig

make -j $(nproc)

make headers_install
make -j $(nproc) modules_install
make install

cp -v .config /boot/config-5.15

# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
echo "Grub update done."
# Reboot VM
shutdown -r now
