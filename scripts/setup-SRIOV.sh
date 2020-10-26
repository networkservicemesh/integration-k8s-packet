#!/bin/bash -x

sed -i '/GRUB_CMDLINE_LINUX=/ s/$/ intel_iommu=on/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

nohup bash -c 'sleep 5; reboot' >/dev/null 2>&1 &
