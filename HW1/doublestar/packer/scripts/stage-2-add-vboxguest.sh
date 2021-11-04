#!/bin/bash

source scl_source enable devtoolset-10
cd /tmp
wget https://download.virtualbox.org/virtualbox/6.1.28/VBoxGuestAdditions_6.1.28.iso
mount VBoxGuestAdditions_6.1.28.iso /mnt
cd /mnt
./VBoxLinuxAdditions.run
cd /
umount /mnt

rm -rf /usr/src/linux-5.15*
rm -rf /usr/src/kernels

shutdown -r now
