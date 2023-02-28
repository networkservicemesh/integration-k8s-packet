#!/bin/bash -x

set -e

apt-get install -y make gcc

# Update ice and iavf drivers
wget -c https://downloadmirror.intel.com/772530/ice-1.11.14.tar.gz -O - | tar -xz
wget -c https://downloadmirror.intel.com/772532/iavf-4.8.2.tar.gz -O - | tar -xz

cd ice-1.11.14/src
make install

cd ../../iavf-4.8.2/src
make install
