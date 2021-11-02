#!/bin/bash -x
# shellcheck disable=SC2086,SC2029

master_ip=$1
worker_ip=$2
sshkey=$3

SSH_CONFIG="ssh_config"
SSH_OPTS="-F ${SSH_CONFIG} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${sshkey}"

if [[ "$CALICO" == "on" ]]; then # calico
  CALICO_MASTER_IP="10.0.0.$(( GITHUB_RUN_NUMBER % 100 ))"
  CALICO_WORKER_IP="10.0.0.$(( GITHUB_RUN_NUMBER % 100 + 1 ))"
  CALICO_SUBNET_MASK="30"
fi

ENVS="KUBERNETES_VERSION CALICO"

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

# 0. Setup SendEnv on the local side.
cp /etc/ssh/ssh_config ${SSH_CONFIG} || exit 1
echo "Host *
	SendEnv ${ENVS}" >> ${SSH_CONFIG} || exit 2

wait_start ${master_ip} ${worker_ip} || exit 3

# 1. Setup AcceptEnv on the servers sides and wait for sshd to restart.
scp ${SSH_OPTS} scripts/setup-sshd.sh root@${master_ip}:setup-sshd.sh || exit 11
scp ${SSH_OPTS} scripts/setup-sshd.sh root@${worker_ip}:setup-sshd.sh || exit 12

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./setup-sshd.sh "${ENVS}" &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./setup-sshd.sh "${ENVS}" &
pids+=" $!"
wait_pids "${pids}" "sshd config failed" || exit 13

wait_start ${master_ip} ${worker_ip} || exit 14

## 2. Setup SR-IOV.
pids=""
/bin/bash scripts/sriov/setup-SRIOV.sh "${master_ip}" "${worker_ip}" "${SSH_OPTS}" &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 21

if [[ "$CALICO" == "on" ]]; then # calico
  # 3. Create Calico scripts directory on nodes.
  ssh ${SSH_OPTS} root@${master_ip} mkdir calico || exit 31
  ssh ${SSH_OPTS} root@${worker_ip} mkdir calico || exit 32

  # 4. Setup Calico interfaces.
  scp ${SSH_OPTS} scripts/calico/setup-interfaces.sh root@${master_ip}:calico/setup-interfaces.sh || exit 41
  scp ${SSH_OPTS} scripts/calico/setup-interfaces.sh root@${worker_ip}:calico/setup-interfaces.sh || exit 42

  pids=""
  ssh ${SSH_OPTS} root@${master_ip} ./calico/setup-interfaces.sh "${CALICO_MASTER_IP}/${CALICO_SUBNET_MASK}" &
  pids+=" $!"
  ssh ${SSH_OPTS} root@${worker_ip} ./calico/setup-interfaces.sh "${CALICO_WORKER_IP}/${CALICO_SUBNET_MASK}" &
  pids+=" $!"
  wait_pids "${pids}" "setup Calico interfaces failed" || exit 43
fi

# 5. Create k8s scripts directory on nodes.
ssh ${SSH_OPTS} root@${master_ip} mkdir k8s || exit 51
ssh ${SSH_OPTS} root@${worker_ip} mkdir k8s || exit 52

# 6. Config docker.
scp ${SSH_OPTS} scripts/k8s/config-docker.sh root@${master_ip}:k8s/config-docker.sh || exit 61
scp ${SSH_OPTS} scripts/k8s/config-docker.sh root@${worker_ip}:k8s/config-docker.sh || exit 62

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/config-docker.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/config-docker.sh &
pids+=" $!"
wait_pids "${pids}" "docker config failed" || exit 63

# 7. Install kubeadm, kubelet and kubectl.
scp ${SSH_OPTS} scripts/k8s/install-kubernetes.sh root@${master_ip}:k8s/install-kubernetes.sh || exit 71
scp ${SSH_OPTS} scripts/k8s/install-kubernetes.sh root@${worker_ip}:k8s/install-kubernetes.sh || exit 72

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/install-kubernetes.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/install-kubernetes.sh &
pids+=" $!"
wait_pids "${pids}" "kubernetes install failed" || exit 73

# 8.
#    master: start kubernetes and create join script.
#    worker: download kubernetes images.
scp ${SSH_OPTS} scripts/k8s/start-master.sh root@${master_ip}:k8s/start-master.sh || exit 81
scp ${SSH_OPTS} scripts/k8s/download-worker-images.sh root@${worker_ip}:k8s/download-worker-images.sh || exit 82

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./k8s/start-master.sh ${master_ip} ${CALICO_MASTER_IP} &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/download-worker-images.sh &
pids+=" $!"
wait_pids "${pids}" "nodes setup failed" || exit 83

# 9. Download, upload and run worker join script.
mkdir -p /tmp/${master_ip}
scp ${SSH_OPTS} root@${master_ip}:k8s/join-cluster.sh /tmp/${master_ip}/join-cluster.sh || exit 91
chmod +x /tmp/${master_ip}/join-cluster.sh || exit 92

scp ${SSH_OPTS} /tmp/${master_ip}/join-cluster.sh root@${worker_ip}:k8s/join-cluster.sh || exit 93

pids=""
ssh ${SSH_OPTS} root@${worker_ip} ./k8s/join-cluster.sh &
pids+=" $!"
wait_pids "${pids}" "worker join failed" || exit 94

# 10. Save KUBECONFIG to file.
scp ${SSH_OPTS} root@${master_ip}:.kube/config ${KUBECONFIG} || exit 101

if [[ "$CALICO" == "on" ]]; then # calico
  # 11. Setup cluster nodes IPs.
  scp ${SSH_OPTS} scripts/calico/setup-node-ip.sh root@${master_ip}:calico/setup-node-ip.sh || exit 111
  scp ${SSH_OPTS} scripts/calico/setup-node-ip.sh root@${worker_ip}:calico/setup-node-ip.sh || exit 112

  pids=""
  ssh ${SSH_OPTS} root@${master_ip} ./calico/setup-node-ip.sh "${CALICO_MASTER_IP}" &
  pids+=" $!"
  ssh ${SSH_OPTS} root@${worker_ip} ./calico/setup-node-ip.sh "${CALICO_WORKER_IP}" &
  pids+=" $!"
  wait_pids "${pids}" "nodes IPs setup failed" || exit 113

  # 12. Deploy Calico CNI.
  /bin/bash scripts/calico/deploy-calico.sh || exit 121
fi

# Get pods
kubectl get pods --all-namespaces