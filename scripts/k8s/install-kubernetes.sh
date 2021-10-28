#!/bin/bash -x

set -e

VERSION="${KUBERNETES_VERSION}-00"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y docker.io
apt-get install -qy kubelet="${VERSION}" kubectl="${VERSION}" kubeadm="${VERSION}"

systemctl daemon-reload
systemctl restart kubelet

swapoff --all
