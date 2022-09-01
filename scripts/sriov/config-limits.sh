#!/bin/bash -x
# shellcheck disable=SC2064,SC2129

sed -i "/^LimitNOFILE/a \LimitMEMLOCK=infinity" /lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl restart containerd
