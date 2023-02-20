#!/bin/bash -x

## Cluster API Packet provides, together with the cluster, always creates an address that must be manually deleted

eip=$(metal ip get -p "${PROJECT_ID}" -o json | jq -r '.[] | select( .tags != null and any(.tags[]; endswith(env.CLUSTER_NAME))) | .id')
metal ip remove -i "$eip"
kubectl delete cluster "${CLUSTER_NAME}"
