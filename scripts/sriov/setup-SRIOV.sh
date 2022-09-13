#!/bin/bash -x
# shellcheck disable=SC2086

master_node="$1"
master_ip="$2"

worker_node="$3"
worker_ip="$4"

SSH_OPTS="$5"

SRIOV_DIR=$(dirname "$0")

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

# Setup target SRIOV VLAN
pids=""
/bin/bash scripts/sriov/config-vlan.sh "${PROJECT_ID}" "${master_node}" &
pids+=" $!"
/bin/bash scripts/sriov/config-vlan.sh "${PROJECT_ID}" "${worker_node}" &
pids+=" $!"
wait_pids "${pids}" "setup SRIOV interfaces failed" || exit 21

# Create SR-IOV scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir sriov
ssh ${SSH_OPTS} root@${worker_ip} mkdir sriov

# Enable SR-IOV and wait for the servers to reboot
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-SRIOV.sh root@${master_ip}:sriov/enable-SRIOV.sh || exit 1
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-SRIOV.sh root@${worker_ip}:sriov/enable-SRIOV.sh || exit 2

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/enable-SRIOV.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/enable-SRIOV.sh &
pids+=" $!"
wait_pids "${pids}" "SR-IOV setup failed" || exit 3

wait_start ${master_ip} ${worker_ip} || exit 4

# Create SR-IOV config
pids=""
ssh ${SSH_OPTS} root@${master_ip} ifenslave -d bond0 ${SRIOV_INTERFACE}
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ifenslave -d bond0 ${SRIOV_INTERFACE}
pids+=" $!"
wait_pids "${pids}" "ifenslave detach error" || exit 5

scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${master_ip}:sriov/config-SRIOV.sh || exit 6
scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${worker_ip}:sriov/config-SRIOV.sh || exit 7

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/config-SRIOV.sh ${SRIOV_INTERFACE}=worker.domain &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/config-SRIOV.sh ${SRIOV_INTERFACE}=master.domain &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 8

# Enable VFIO driver
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${master_ip}:sriov/enable-VFIO.sh || exit 9
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${worker_ip}:sriov/enable-VFIO.sh || exit 10

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/enable-VFIO.sh ${SRIOV_INTERFACE} &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/enable-VFIO.sh ${SRIOV_INTERFACE} &
pids+=" $!"
wait_pids "${pids}" "VFIO enabling failed" || exit 11

# Config Limits
scp ${SSH_OPTS} ${SRIOV_DIR}/config-limits.sh root@${master_ip}:sriov/config-limits.sh || exit 6
scp ${SSH_OPTS} ${SRIOV_DIR}/config-limits.sh root@${worker_ip}:sriov/config-limits.sh || exit 7

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/config-limits.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/config-limits.sh &
pids+=" $!"
wait_pids "${pids}" "Limits config failed" || exit 8
