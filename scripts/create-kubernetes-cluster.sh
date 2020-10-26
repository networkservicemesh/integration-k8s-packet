#!/bin/bash -x
# shellcheck disable=SC2086

master_ip=$1
worker_ip=$2
sshkey=$3

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${sshkey}"

function wait_pids() {
  pids="$1"
  message="$2"
  for pid in ${pids}; do
    echo "waiting for PID ${pid}"
    wait ${pid}
    if test $? -ne 0; then
      echo "${message}: process exited with code $?, aborting.." && return 1
    fi
  done
  return 0
}

# Setup SR-IOV and wait for the servers to reboot
scp ${SSH_OPTS} ./scripts/setup-SRIOV.sh root@${master_ip}:setup-SRIOV.sh || exit 1
scp ${SSH_OPTS} ./scripts/setup-SRIOV.sh root@${worker_ip}:setup-SRIOV.sh || exit 2

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./setup-SRIOV.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./setup-SRIOV.sh &
pids+=" $!"
wait_pids "${pids}" "SR-IOV setup failed" || exit 3

sleep 5

i=0
for ip in ${master_ip} ${worker_ip}; do
  ssh ${SSH_OPTS} root@${ip} -o ConnectTimeout=1 true
  while test $? -ne 0; do
    ((i++))
    # ~10 minutes to start
    if test $i -gt 200; then
      echo "timeout waiting for the ${ip} to start, aborting..." && exit 4
    fi
    sleep 5
    ssh ${SSH_OPTS} root@${ip} -o ConnectTimeout=1 true
  done
done

# Install kubeadm, kubelet and kubectl
scp ${SSH_OPTS} scripts/install-kubernetes.sh root@${master_ip}:install-kubernetes.sh || exit 5
scp ${SSH_OPTS} scripts/install-kubernetes.sh root@${worker_ip}:install-kubernetes.sh || exit 6

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./install-kubernetes.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./install-kubernetes.sh &
pids+=" $!"
wait_pids "${pids}" "kubernetes install failed" || exit 7

# master1: start kubernetes and create join script
# workers: download kubernetes images
scp ${SSH_OPTS} scripts/start-master.sh root@${master_ip}:start-master.sh || exit 8
scp ${SSH_OPTS} scripts/download-worker-images.sh root@${worker_ip}:download-worker-images.sh || exit 9

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./start-master.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./download-worker-images.sh &
pids+=" $!"
wait_pids "${pids}" "node setup failed" || exit 10

# Download worker join script
mkdir -p /tmp/${master_ip}
scp ${SSH_OPTS} root@${master_ip}:join-cluster.sh /tmp/${master_ip}/join-cluster.sh || exit 11
chmod +x /tmp/${master_ip}/join-cluster.sh || exit 12

# Upload and run worker join script
scp ${SSH_OPTS} /tmp/${master_ip}/join-cluster.sh root@${worker_ip}:join-cluster.sh || exit 13

pids=""
ssh ${SSH_OPTS} root@${worker_ip} ./join-cluster.sh &
pids+=" $!"
wait_pids "${pids}" "worker join failed" || exit 14

echo "Save KUBECONFIG to file"
scp ${SSH_OPTS} root@${master_ip}:.kube/config ${KUBECONFIG} || exit 15
