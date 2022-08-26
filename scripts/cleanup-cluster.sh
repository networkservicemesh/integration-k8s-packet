#!/bin/bash -x

clustername=$1

export KUBECONFIG=$HOME/.kube/config
kubectl delete cluster "${clustername}"
