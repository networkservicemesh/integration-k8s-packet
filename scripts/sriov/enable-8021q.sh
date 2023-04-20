#!/bin/bash -x
# shellcheck disable=SC2002,SC2064

# Enable 8021q for vlan tagging
modprobe 8021q
echo "8021q" >> /etc/modules
