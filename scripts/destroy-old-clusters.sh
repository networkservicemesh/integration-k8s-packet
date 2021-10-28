#!/bin/bash -x

set -e

go run github.com/networkservicemesh/cloudtest/pkg/providers/packet/packet_cleanup -k y -c y
