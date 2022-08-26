#!/bin/bash -x
# shellcheck disable=SC2086

iface="$1"
project_id="$2"
SSH_OPTS="$3"

SRIOV_DIR=$(dirname "$0")

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

# Get nodes name
cp_node=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
wr_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')

# Setup target SRIOV interfaces
pids=""
/bin/bash scripts/sriov/setup-interfaces.sh "${project_id}" "${cp_node}" &
pids+=" $!"
/bin/bash scripts/sriov/setup-interfaces.sh "${project_id}" "${wr_node}" &
pids+=" $!"
wait_pids "${pids}" "setup SRIOV interfaces failed" || exit 21

# Get nodes IPs
mapfile -t cp_ips < <(kubectl get node "${cp_node}" --template '{{range .status.addresses}}{{ if eq .type "ExternalIP" }}{{ index .address }}{{"\n"}}{{end}}{{end}}')
master_ip=${cp_ips[0]}
mapfile -t wr_ips < <(kubectl get node "${wr_node}" --template '{{range .status.addresses}}{{ if eq .type "ExternalIP" }}{{ index .address }}{{"\n"}}{{end}}{{end}}')
worker_ip=${wr_ips[0]}

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
ssh ${SSH_OPTS} root@${master_ip} ifenslave -d bond0 ${iface}
ssh ${SSH_OPTS} root@${worker_ip} ifenslave -d bond0 ${iface}

scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${master_ip}:sriov/config-SRIOV.sh || exit 5
scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${worker_ip}:sriov/config-SRIOV.sh || exit 6

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/config-SRIOV.sh ${iface}=worker.domain &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/config-SRIOV.sh ${iface}=master.domain &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 7

# Enable VFIO driver
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${master_ip}:sriov/enable-VFIO.sh || exit 8
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${worker_ip}:sriov/enable-VFIO.sh || exit 9

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/enable-VFIO.sh ${iface} &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/enable-VFIO.sh ${iface} &
pids+=" $!"
wait_pids "${pids}" "VFIO enabling failed" || exit 10
