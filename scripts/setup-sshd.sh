#!/bin/bash -x

set -e

ENVS="$*"

echo "AcceptEnv ${ENVS}" >> /etc/ssh/sshd_config

nohup bash -c "sleep 5; systemctl restart sshd" >/dev/null 2>&1 &