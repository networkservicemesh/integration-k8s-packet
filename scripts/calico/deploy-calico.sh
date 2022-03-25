#!/bin/bash

function on_error() {
  kubectl describe pods --all-namespaces
  exit 1
}
trap 'on_error' ERR

kubectl apply -f https://projectcalico.docs.tigera.io/v3.22/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/vpp-dataplane/master/yaml/calico/installation-default.yaml
kubectl apply -k scripts/calico

kubectl rollout status -n calico-vpp-dataplane ds/calico-vpp-node --timeout=10m
