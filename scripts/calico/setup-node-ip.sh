#!/bin/bash

set -e

ip="$1"

sed -Ei "s/(.*)\"/\1 --node-ip=${ip}\"/g" /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
