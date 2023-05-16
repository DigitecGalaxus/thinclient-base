#!/bin/bash
set -euo pipefail

# Use netbootIP as a variable to retreive latest kernel version from a custom-defined netbootserver
if [[ $# -lt 1 ]]; then
        echo "Error: No arguments passed. Make sure to pass at least the Netboot IP Address"
        exit 1
else
        netbootIP="$1"
fi

kernelVersion=$(curl -s --connect-timeout 2 "http://$netbootIP/kernels/latest-kernel-version.json" | jq -r .version)

if [[ "$kernelVersion" == "" ]]
then
  kernelVersion="6.2.0-20-generic"
  echo "Warning: Using fallback static kernel version $kernelVersion"
fi

apt-get -qq update > /dev/null 2>&1 && apt-get -qq install -y "linux-image-$kernelVersion" "linux-modules-extra-$kernelVersion" > /dev/null 2>&1
