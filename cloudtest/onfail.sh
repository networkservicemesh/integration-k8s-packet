#!/bin/sh

date "+%Y-%m-%d %H:%M:%S"
echo namespaces:
kubectl get ns
echo everything:
kubectl get all --all-namespaces
kubectl get ns --template "{{range .items}}{{.metadata.name}}{{\"\\n\"}}{{end}}"
NAMESPACE=$(kubectl get ns --template "{{range .items}}{{.metadata.name}}{{\"\\n\"}}{{end}}" | grep ns-)
echo found namespace $NAMESPACE
echo pods in $NAMESPACE :
kubectl -n $NAMESPACE get pods
echo pods in $NAMESPACE describe:
kubectl -n $NAMESPACE describe pods
NSE=$(kubectl -n ${NAMESPACE} get pods -l app=nse-vfio --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
echo found nse $NSE
echo nse ps:
kubectl -n $NAMESPACE exec $NSE -- ps
date "+%Y-%m-%d %H:%M:%S"
