#!/bin/bash -x
# shellcheck disable=SC2064,SC2129

calico_ip=$1

kubectl --kubeconfig="/etc/kubernetes/admin.conf" -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml
sed -i "/^apiServer:$/a \ \ certSANs:\n    - \"${calico_ip}\"" kubeadm.yaml

rm /etc/kubernetes/pki/apiserver.{crt,key}
kubeadm init phase certs apiserver --config kubeadm.yaml
