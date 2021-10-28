#!/bin/bash

set -e

ip="$1"

ip addr add "${ip}" dev eno2
ip link set up dev eno2
