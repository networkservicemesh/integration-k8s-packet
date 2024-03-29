#!/bin/bash -x
# shellcheck disable=SC2064,SC2129

project_id=$1
node_name=$2
vlan=$3
enable8021q=$4

# Get IDs
device_id=$(metal device get -p "${project_id}" -o json --filter hostname="${node_name}" | jq -r '.[0].id')
bond1_id=$(metal device get -i "${device_id}" -o json | jq -r ' .network_ports[] | select(.name=="bond1") | .id')
eth3_id=$(metal device get -i "${device_id}" -o json | jq -r ' .network_ports[] | select(.name=="eth3") | .id')

# Unbond bond1
bonded=$(metal port get -i "${bond1_id}" -o json | jq -r '.data.bonded')
if [[ "$bonded" == "true" ]]; then
  yes | metal port convert -i "${bond1_id}" --layer2 --bonded=false
  echo "bond1 was unbonded"
fi

# Set VLANs for eth3
metal port vlans -i "${eth3_id}" -a "${vlan}"

# We have to set one more, "base" VLAN due to Equinix Metal cluster specifics
# See: https://deploy.equinix.com/developers/docs/metal/layer2-networking/layer2-mode/#attaching-multiple-vlans-unbonded
if [[ "$enable8021q" == "true" ]]; then
  metal port vlans -i "${eth3_id}" -a 10
fi
