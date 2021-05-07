#!/bin/bash

# https://gist.github.com/vielmetti/dafb5128ef7535c218f6d963c5bc624e
apt-get update
apt-get install -y grub2-common
grub-install --bootloader-id=ubuntu

sed -Ei "s/(GRUB_CMDLINE_LINUX=.*)'/\1 intel_iommu=on'/" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

nohup bash -c "sleep 5; reboot" >/dev/null 2>&1 &
