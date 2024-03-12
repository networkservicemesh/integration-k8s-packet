#!/bin/bash -x
# shellcheck disable=SC2086,SC2064

set -e

ls /sys/class/net
ip -details link show
lspci | egrep -i 'network|ethernet'