#!/bin/bash
# shellcheck disable=SC2086,SC2029

master_node="$1"
master_ip="$2"

worker_node="$3"
worker_ip="$4"

SSH_OPTS="$5"

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

# Config VLAN for Calico
pids=""
/bin/bash scripts/calico/config-vlan.sh "${PROJECT_ID}" "${master_node}" &
pids+=" $!"
/bin/bash scripts/calico/config-vlan.sh "${PROJECT_ID}" "${worker_node}" &
pids+=" $!"
wait_pids "${pids}" "setup Calico interfaces failed" || exit 1

# Create Calico scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir -p calico || exit 2
ssh ${SSH_OPTS} root@${worker_ip} mkdir -p calico || exit 3

# Setup Calico interfaces
scp ${SSH_OPTS} scripts/calico/config-interface.sh root@${master_ip}:calico/config-interface.sh || exit 4
scp ${SSH_OPTS} scripts/calico/config-interface.sh root@${worker_ip}:calico/config-interface.sh || exit 5

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./calico/config-interface.sh "${CALICO_INTERFACE}" "${CALICO_MASTER_IP}" "${CALICO_CIDR_PREFIX}" &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./calico/config-interface.sh "${CALICO_INTERFACE}" "${CALICO_WORKER_IP}" "${CALICO_CIDR_PREFIX}" &
pids+=" $!"
wait_pids "${pids}" "setup Calico interfaces failed" || exit 6

# Kuberenetes apiserver certs reconfiguration
scp ${SSH_OPTS} scripts/calico/config-certs.sh root@${master_ip}:calico/config-certs.sh || exit 7
ssh ${SSH_OPTS} root@${master_ip} ./calico/config-certs.sh ${CALICO_MASTER_IP} || exit 8

## Change Node IPs
scp ${SSH_OPTS} scripts/calico/config-node-ip.sh root@${master_ip}:calico/config-node-ip.sh || exit 9
scp ${SSH_OPTS} scripts/calico/config-node-ip.sh root@${worker_ip}:calico/config-node-ip.sh || exit 10

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./calico/config-node-ip.sh "${CALICO_MASTER_IP}" &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./calico/config-node-ip.sh "${CALICO_WORKER_IP}" &
pids+=" $!"
wait_pids "${pids}" "node IPs setup failed" || exit 11
