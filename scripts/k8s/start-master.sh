#!/bin/bash -x
# shellcheck disable=SC2086

set -e

public_ip="$1"
calico_ip="$2"

K8S_DIR=$(dirname "$0")

if [[ "$CALICO" != "on" ]]; then # not calico
  ip="${public_ip}"
else
  ip="${calico_ip}"
fi

kubeadm init \
    --kubernetes-version "${KUBERNETES_VERSION}" \
    --pod-network-cidr=192.168.0.0/16 \
    --skip-token-print \
    --apiserver-advertise-address=$ip

mkdir -p ~/.kube
cp -f /etc/kubernetes/admin.conf ~/.kube/config
chown "$(id -u):$(id -g)" ~/.kube/config

if [[ "$CALICO" != "on" ]]; then # not calico
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=192.168.0.0/16"
fi

kubectl taint nodes --all node-role.kubernetes.io/master-

if [[ "$CALICO" == "on" ]]; then # calico
  kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml
  sed -i "/^apiServer:$/a \ \ certSANs:\n    - \"${public_ip}\"\n    - \"${calico_ip}\"" kubeadm.yaml

  rm /etc/kubernetes/pki/apiserver.{crt,key}
  kubeadm init phase certs apiserver --config kubeadm.yaml

  sed -i "s/${calico_ip//./\.}/${public_ip}/g" ~/.kube/config
fi

kubeadm token create --print-join-command > "${K8S_DIR}/join-cluster.sh"
