#!/bin/bash

set -e

cdr2mask ()
{
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ("$1" / 8) )) 255 255 255 255 $(( (255 << (8 - ("$1" % 8))) & 255 )) 0 0 0
   if [[ "$1" -gt 1 ]]
   then
     shift "$1"
   else
     shift
   fi
   echo "${1-0}"."${2-0}"."${3-0}"."${4-0}"
}

iface="$1"
ip="$2"
cidr="$3"
mask=$(cdr2mask "$3")

# Unbond interface and set IP address
cd /etc/network/
awk -v pattern="iface $1 inet" -v ip="$2" -v mask="$mask" '
	$0 ~ pattern {
		printf "%s static\n",pattern;
		printf "    address %s\n",ip;
		printf "    netmask %s\n",mask;
		getline;
		while ($0 != "") {
			if ($1=="bond-master") {
				next;
				break
			};
			print;
			getline
		}
	} 1
' interfaces > interfaces.tmp && mv interfaces.tmp interfaces
cd
ifenslave -d bond0 "${iface}"
ip addr change "${ip}/${cidr}" dev "${iface}"
ip link set up dev "${iface}"
