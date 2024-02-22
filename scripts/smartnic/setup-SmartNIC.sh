#!/bin/bash -x
# shellcheck disable=SC2086

set -e

master_ip="$1"
worker_ip="$2"
SSH_OPTS="$3"
snic="$4"

function wait_pids() {
  pids="$1"
  message="$2"
  for pid in ${pids}; do
    echo "waiting for PID ${pid}"
    wait ${pid}
    code=$?
    if test $code -ne 0; then
      echo "${message}: process exited with code $code, aborting..."
      return 1
    fi
  done
  return 0
}

SMARTNIC_DIR=$(dirname "$0")

# Create SmartNIC scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir smartnic
ssh ${SSH_OPTS} root@${worker_ip} mkdir smartnic


# Configure SmartNIC on the nodes
scp ${SSH_OPTS} ${SMARTNIC_DIR}/enable-SmartNIC.sh root@${master_ip}:smartnic/enable-SmartNIC.sh || exit 1
scp ${SSH_OPTS} ${SMARTNIC_DIR}/enable-SmartNIC.sh root@${worker_ip}:smartnic/enable-SmartNIC.sh || exit 2

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./smartnic/enable-SmartNIC.sh $snic &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./smartnic/enable-SmartNIC.sh $snic &
pids+=" $!"
wait_pids "${pids}" "SmartNIC setup failed" || exit 3

sleep 5

# Copy SRIOV config as SmartNIC config
ssh ${SSH_OPTS} root@${master_ip} cp /var/lib/networkservicemesh/sriov.config /var/lib/networkservicemesh/smartnic.config
ssh ${SSH_OPTS} root@${worker_ip} cp /var/lib/networkservicemesh/sriov.config /var/lib/networkservicemesh/smartnic.config