#!/bin/bash -x
# shellcheck disable=SC2086,SC2029

sshkey=$1

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i ${sshkey}"
export SRIOV_INTERFACE="ens6f3"

if [[ "$CNI" == "calico" ]]; then # calico
  # Use a new 10.0.0.${base_ip}/30 subnet to prevent IP addresses collisions
  # ${base_ip} should be <= 248, because 10.0.0.252/30 subnet is reserved for manual testing
  base_ip=$(( GITHUB_RUN_NUMBER % 63 * 4 ))

  export CALICO_MASTER_IP="10.0.0.$(( base_ip + 1 ))"
  export CALICO_WORKER_IP="10.0.0.$(( base_ip + 2 ))"
  export CALICO_CIDR_PREFIX="30"
  export CALICO_INTERFACE="ens6f1"
fi

# wait_pids pid_1 ... pid_n
source scripts/include/wait-pids.sh
# wait_start ip_1 ... ip_n
source scripts/include/wait-start.sh

## Run clusterctl
clusterctl init --infrastructure packet || exit 1
clusterctl generate cluster ${CLUSTER_NAME}  \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --control-plane-machine-count=1            \
  --worker-machine-count=1                   \
  > packet.yaml || exit 2

# If CNI is Calico, we need to make a few corrections to the generated template
sed -r -i 's/(cloud-provider-equinix-metal\/releases\/download\/v[0-9.]*\/)/cloud-provider-equinix-metal\/releases\/download\/v3.5.0\//g' packet.yaml
if [[ "$CNI" == "calico" ]]; then # calico
  sed -i "/^    initConfiguration:/a \      localAPIEndpoint:\n        advertiseAddress: ${CALICO_MASTER_IP}" packet.yaml
  sed -i "/^    preKubeadmCommands:/a \    - ifenslave -d bond0 ${CALICO_INTERFACE}\n    - ip addr change ${CALICO_MASTER_IP}/${CALICO_CIDR_PREFIX} dev ${CALICO_INTERFACE}\n    - ip link set up dev ${CALICO_INTERFACE}" packet.yaml
  sed -i "/^      preKubeadmCommands:/a \      - ifenslave -d bond0 ${CALICO_INTERFACE}\n      - ip addr change ${CALICO_WORKER_IP}/${CALICO_CIDR_PREFIX} dev ${CALICO_INTERFACE}\n      - ip link set up dev ${CALICO_INTERFACE}" packet.yaml
fi

# To be sure that template was applied, we make several attempts
for i in {1..10}; do
  kubectl apply -f packet.yaml
  result=$?
  if [ $result -eq 0 ]; then
    break
  fi
  if [[ ${i} == 10 ]]; then
    echo "error during applying packet template. exit"
    exit 3
  fi
  sleep 10s
done

# Wait for packet servers to be ready
sleep 30s
kubectl wait --timeout=30m --for=condition=Ready=true packetmachine -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
result=$?
if [ $result -ne 0 ]; then
  clusterctl describe cluster ${CLUSTER_NAME} --echo
  exit 4
fi

## Save kubeconfig
clusterctl get kubeconfig ${CLUSTER_NAME} > $HOME/.kube/config_packet || exit 5
export KUBECONFIG_PACK=$HOME/.kube/config_packet

## Get node names and IPs
master_node=$(kubectl get packetmachine -l cluster.x-k8s.io/control-plane --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') || exit 6
worker_node=$(kubectl get packetmachine -l '!cluster.x-k8s.io/control-plane' --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') || exit 7

mapfile -t cp_ips < <(kubectl get packetmachine "${master_node}" --template '{{range .status.addresses}}{{ if eq .type "ExternalIP" }}{{ index .address }}{{"\n"}}{{end}}{{end}}') || exit 8
master_ip=${cp_ips[0]}
mapfile -t wr_ips < <(kubectl get packetmachine "${worker_node}" --template '{{range .status.addresses}}{{ if eq .type "ExternalIP" }}{{ index .address }}{{"\n"}}{{end}}{{end}}') || exit 9
worker_ip=${wr_ips[0]}

## Do a preset in the case of calico (basically setting up interfaces)
if [[ "$CNI" == "calico" ]]; then
  /bin/bash scripts/calico/setup-calico.sh "${master_node}" "${master_ip}" "${worker_node}" "${worker_ip}" "${SSH_OPTS}" || exit 10
fi

## Waiting for two nodes (control-plane and worker), because the kubernetes installation takes place in the background
for i in {1..20}; do
  nodes_count=$(kubectl --kubeconfig=$KUBECONFIG_PACK get nodes --no-headers | wc -l)
  if [ $nodes_count -eq 2 ]; then
    break
  fi
  if [[ ${i} == 20 ]]; then
    echo "node count timeout exceeded. exit"
    exit 11
  fi
  sleep 10s
done

## Setup SR-IOV
/bin/bash scripts/sriov/setup-SRIOV.sh "${master_node}" "${master_ip}" "${worker_node}" "${worker_ip}" "${SSH_OPTS}" || exit 12

## CNI installation
if [[ "$CNI" == "default" ]]; then # use weave CNI in case of default
  kubectl --kubeconfig=$KUBECONFIG_PACK apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=192.168.0.0/16" || exit 13
elif [[ "$CNI" == "calico" ]]; then # calico-VPP CNI
  export KUBECONFIG=$KUBECONFIG_PACK
  /bin/bash scripts/calico/deploy-calico.sh || exit 14
fi

## Remove master label from the control-plane node to be able to use it as worker node
# For some versions of kubernetes you need to use node-role.kubernetes.io/control-plane-
kubectl --kubeconfig=$KUBECONFIG_PACK taint nodes --selector='node-role.kubernetes.io/master' node-role.kubernetes.io/master- || exit 15
