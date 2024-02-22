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

# Create SmartNIC config
scp ${SSH_OPTS} ${SMARTNIC_DIR}/config-SmartNIC.sh root@${master_ip}:smartnic/config-SmartNIC.sh || exit 4
scp ${SSH_OPTS} ${SMARTNIC_DIR}/config-SmartNIC.sh root@${worker_ip}:smartnic/config-SmartNIC.sh || exit 5

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./smartnic/config-SmartNIC.sh ${snic}=worker.domain &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./smartnic/config-SmartNIC.sh ${snic}=worker.domain &
pids+=" $!"
wait_pids "${pids}" "NSM SmartNIC config failed" || exit 6