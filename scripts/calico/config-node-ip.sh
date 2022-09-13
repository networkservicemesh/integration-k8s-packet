#!/bin/bash

set -e

ip="$1"

## By the time we reach this step, FILE may not have been created yet (kubernetes is being installed in the background).
# We have to wait until it is created.

FILE=/var/lib/kubelet/kubeadm-flags.env

for i in {1..20}; do
  if test -f "$FILE"; then
    break
  fi
  if [[ ${i} == 20 ]]; then
    echo "error during waiting nodes ready. exit"
    exit 11
  fi
  sleep 10s
done

sed -Ei "s/(.*)\"/\1 --node-ip=${ip}\"/g" "$FILE"
systemctl restart kubelet
