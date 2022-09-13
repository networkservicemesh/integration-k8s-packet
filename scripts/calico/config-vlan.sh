#!/bin/bash -x
# shellcheck disable=SC2064,SC2129

project_id=$1
hostname=$2

# Get IDs
device_id=$(metal device get -p "${project_id}" -o json --filter hostname="${hostname}" | jq -r '.[0].id')
bond1_id=$(metal device get -i "${device_id}" -o json | jq -r ' .network_ports[] | select(.name=="bond1") | .id')
eth1_id=$(metal device get -i "${device_id}" -o json | jq -r ' .network_ports[] | select(.name=="eth1") | .id')

# Unbond bond1
bonded=$(metal port get -i "${bond1_id}" -o json | jq -r '.data.bonded')
if [[ "$bonded" == "true" ]]; then
  yes | metal port convert -i "${bond1_id}" --layer2 --bonded=false
  echo "bond1 was unbonded"
fi
# Set VLAN for eth1
metal port vlans -i "${eth1_id}" -a 3000
