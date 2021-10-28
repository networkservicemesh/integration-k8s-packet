#!/bin/bash -x

set -e

mkdir -p /etc/docker

echo \
'{
    "default-ulimits": {
        "memlock":
        {
            "name": "memlock",
            "soft": 67108864,
            "hard": 67108864
        }
    },
    "exec-opts": ["native.cgroupdriver=systemd"]
}' >/etc/docker/daemon.json
