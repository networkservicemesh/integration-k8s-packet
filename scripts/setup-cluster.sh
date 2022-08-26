#!/bin/bash -x
# shellcheck disable=SC2086,SC2029

sshkey=$1

SSH_CONFIG="ssh_config"
SSH_OPTS="-F ${SSH_CONFIG} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${sshkey}"

ENVS="CNI"

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

# Run clusterctl
clusterctl init --infrastructure packet || exit 1
clusterctl generate cluster ${CLUSTER_NAME}  \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --control-plane-machine-count=1            \
  --worker-machine-count=1                   \
  > packet.yaml || exit 2

for i in {1..10}; do
  kubectl apply -f packet.yaml
  result=$?
  if [ $result -eq 0 ]; then
    break
  fi
  if [[ ${i} == 10 ]]; then
    echo "error during applying packet configuration. exit"
    exit 3
  fi
  sleep 10s
done

# Wait for control-plane server to be ready
sleep 30s
kubectl wait --timeout=20m --for=condition=Ready=true kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
result=$?
if [ $result -ne 0 ]; then
  clusterctl describe cluster ${CLUSTER_NAME} --echo
  exit 4
fi

# Save kubeconfigs
clusterctl get kubeconfig ${CLUSTER_NAME} > $HOME/.kube/config_packet || exit 5
KUBECONFIG_KIND=$HOME/.kube/config
KUBECONFIG_PACK=$HOME/.kube/config_packet

# Install CNI
export KUBECONFIG=$KUBECONFIG_PACK
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=192.168.0.0/16" || exit 6
kubectl taint nodes --all node-role.kubernetes.io/master- || exit 7
#kubectl taint nodes --all node-role.kubernetes.io/control-plane- || exit 8

# Wait for worker server to be ready
export KUBECONFIG=$KUBECONFIG_KIND
kubectl wait --timeout=20m --for=condition=Ready=true machinedeployment -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME} || exit 8

# Switch kubeconfig
export KUBECONFIG=$KUBECONFIG_PACK

## 0. Setup SendEnv on the local side.
cp /etc/ssh/ssh_config ${SSH_CONFIG} || exit 1
echo "Host *
	SendEnv ${ENVS}" >> ${SSH_CONFIG} || exit 2

## 1. Setup AcceptEnv on the servers sides and wait for sshd to restart.
#scp ${SSH_OPTS} scripts/setup-sshd.sh root@${master_ip}:setup-sshd.sh || exit 11
#scp ${SSH_OPTS} scripts/setup-sshd.sh root@${worker_ip}:setup-sshd.sh || exit 12
#
#pids=""
#ssh ${SSH_OPTS} root@${master_ip} ./setup-sshd.sh "${ENVS}" &
#pids+=" $!"
#ssh ${SSH_OPTS} root@${worker_ip} ./setup-sshd.sh "${ENVS}" &
#pids+=" $!"
#wait_pids "${pids}" "sshd config failed" || exit 13
#
#wait_start ${master_ip} ${worker_ip} || exit 14

## 2. Setup SR-IOV.
pids=""
/bin/bash scripts/sriov/setup-SRIOV.sh ens6f3 "${PROJECT_ID}" "${SSH_OPTS}" &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 21
