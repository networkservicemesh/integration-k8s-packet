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
    code=$?
    if test $code -ne 0; then
      echo "${message}: process exited with code $code, aborting..." && return 1
    fi
  done
  return 0
}

# Setup SR-IOV
pids=""
/bin/bash scripts/sriov/setup-SRIOV.sh "${master_ip}" "${worker_ip}" "${SSH_OPTS}" &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 1

# Create ovs scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir ovs
ssh ${SSH_OPTS} root@${worker_ip} mkdir ovs

# Setup ovs scripts
scp ${SSH_OPTS} scripts/ovs/config-ovs.sh root@${master_ip}:ovs/config-ovs.sh || exit 2
scp ${SSH_OPTS} scripts/ovs/config-ovs.sh root@${worker_ip}:ovs/config-ovs.sh || exit 3

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./ovs/config-ovs.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./ovs/config-ovs.sh &
pids+=" $!"
wait_pids "${pids}" "ovs config failed" || exit 4

# Create k8s scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir k8s
ssh ${SSH_OPTS} root@${worker_ip} mkdir k8s

# Setup docker ulimit
scp ${SSH_OPTS} scripts/k8s/docker-ulimit.sh root@${master_ip}:k8s/docker-ulimit.sh || exit 5
scp ${SSH_OPTS} scripts/k8s/docker-ulimit.sh root@${worker_ip}:k8s/docker-ulimit.sh || exit 6

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/docker-ulimit.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/docker-ulimit.sh &
pids+=" $!"
wait_pids "${pids}" "kubernetes install failed" || exit 7

# Install kubeadm, kubelet and kubectl
scp ${SSH_OPTS} scripts/k8s/install-kubernetes.sh root@${master_ip}:k8s/install-kubernetes.sh || exit 8
scp ${SSH_OPTS} scripts/k8s/install-kubernetes.sh root@${worker_ip}:k8s/install-kubernetes.sh || exit 9

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/install-kubernetes.sh ${KUBERNETES_VERSION} &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/install-kubernetes.sh ${KUBERNETES_VERSION} &
pids+=" $!"
wait_pids "${pids}" "kubernetes install failed" || exit 10

# master: start kubernetes and create join script
# worker: download kubernetes images
scp ${SSH_OPTS} scripts/k8s/start-master.sh root@${master_ip}:k8s/start-master.sh || exit 11
scp ${SSH_OPTS} scripts/k8s/download-worker-images.sh root@${worker_ip}:k8s/download-worker-images.sh || exit 12

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/start-master.sh ${KUBERNETES_VERSION} &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/download-worker-images.sh &
pids+=" $!"
wait_pids "${pids}" "node setup failed" || exit 13

# Download worker join script
mkdir -p /tmp/${master_ip}
scp ${SSH_OPTS} root@${master_ip}:k8s/join-cluster.sh /tmp/${master_ip}/join-cluster.sh || exit 14
chmod +x /tmp/${master_ip}/join-cluster.sh || exit 15

# Upload and run worker join script
scp ${SSH_OPTS} /tmp/${master_ip}/join-cluster.sh root@${worker_ip}:k8s/join-cluster.sh || exit 16

pids=""
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/join-cluster.sh &
pids+=" $!"
wait_pids "${pids}" "worker join failed" || exit 17

echo "Save KUBECONFIG to file"
scp ${SSH_OPTS} root@${master_ip}:.kube/config ${KUBECONFIG} || exit 18
