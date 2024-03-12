#!/bin/bash -x
# shellcheck disable=SC2086

master_ip="$1"

worker_ip="$2"

SSH_OPTS="$3"

OVS_DIR=$(dirname "$0")

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh

# Create ovs scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir ovs
ssh ${SSH_OPTS} root@${worker_ip} mkdir ovs

# Enable ovs and wait for scripts to execute
scp ${SSH_OPTS} ${OVS_DIR}/enable-ovs.sh root@${master_ip}:ovs/enable-ovs.sh || exit 1
scp ${SSH_OPTS} ${OVS_DIR}/enable-ovs.sh root@${worker_ip}:ovs/enable-ovs.sh || exit 2

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./ovs/enable-ovs.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./ovs/enable-ovs.sh &
pids+=" $!"
wait_pids "${pids}" "ovs setup failed" || exit 3
