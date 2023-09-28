#!/bin/bash

function on_error() {
  kubectl describe pods --all-namespaces
  exit 1
}
trap 'on_error' ERR

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
sleep 5s
kubectl wait --for condition=established --timeout=10s crd/installations.operator.tigera.io
kubectl create -f https://raw.githubusercontent.com/projectcalico/vpp-dataplane/v3.26.0/yaml/calico/installation-default.yaml
kubectl apply -k scripts/calico

kubectl rollout status -n calico-vpp-dataplane ds/calico-vpp-node --timeout=5m
kubectl rollout status -n calico-system ds/calico-node --timeout=5m
