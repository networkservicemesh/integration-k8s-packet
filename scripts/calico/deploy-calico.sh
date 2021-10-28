#!/bin/bash

function on_error() {
  kubectl describe pods --all-namespaces
  exit 1
}
trap 'on_error' ERR

kubectl apply -k scripts/calico

kubectl -n calico-vpp-dataplane rollout status daemonset/calico-vpp-node --timeout=5m
kubectl -n kube-system rollout status deployment/calico-kube-controllers --timeout=5m
