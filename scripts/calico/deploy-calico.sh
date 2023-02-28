#!/bin/bash

function on_error() {
  kubectl describe pods --all-namespaces
  exit 1
}
trap 'on_error' ERR

kubectl create -f https://projectcalico.docs.tigera.io/archive/v3.24/manifests/tigera-operator.yaml
sleep 5s
kubectl wait --for condition=established --timeout=10s crd/installations.operator.tigera.io
kubectl create -f https://raw.githubusercontent.com/projectcalico/vpp-dataplane/82c88a14e5e0e3cc5d7f70c52cdbc01c999d3a42/yaml/calico/installation-default.yaml
kubectl apply -k scripts/calico

kubectl rollout status -n calico-vpp-dataplane ds/calico-vpp-node --timeout=10m
