#!/bin/bash -x
# shellcheck disable=SC2086,SC2064

set -e

ls /sys/class/net
device="/sys/class/net/$1/device"

# modprobe mlx5_core driver
MLX5_CORE_DRIVER_DIR="/sys/bus/pci/drivers/mlx5_core"
ls -l "${MLX5_CORE_DRIVER_DIR}" || modprobe mlx5_core || exit 1

# Don't forget to remove VFs for the link
trap "echo 0 >'${device}/sriov_numvfs'" err exit

# Add 2 Smart VFs for the link
echo 2 > "${device}/sriov_numvfs" || exit 2

# Change PF to appropriate modes
echo legacy > "${device}/compat/devlink/vport_match_mode" || exit 2
echo dmfs > "${device}/compat/devlink/steering_mode" || exit 2
echo switchdev > "${device}/compat/devlink/mode" || exit 2

# Enable mlx5_core driver for the VFs
for i in $(seq 0 2); do pci_id=$(grep "PCI_ID" "${device}/virtfn$i/uevent" | sed -E "s/PCI_ID=(.*):(.*)/\1 \2/g"); test $? -eq 0 || exit 3; echo "${pci_id}" > "${MLX5_CORE_DRIVER_DIR}/new_id" || exit 4; done

# Waiting for the SmartVF devices to be up again
while [ "$(ip link | grep -c smartvf)" != "2" ]; do sleep 1; done

# Assign the representor MAC addresses to the VF MAC adresses
for i in $(seq 0 2); do mac=$(ip l show smartvf0_$i | grep -o "link/ether [^ ]*" | cut -d' ' -f2); echo "vf $i: $mac"; ip l set $1 vf $i mac $mac; done

# Representor devices manually have to be set to "up"
for p in $(ip l | grep -o "ens5f0[^:]*"); do echo $p; ip link set $p up; done