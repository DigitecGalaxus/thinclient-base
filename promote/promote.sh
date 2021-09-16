#!/bin/bash
set -eu -o pipefail

# This script uploads the squashfs file and the latest kernel version file to the folder specified

if [[ $# -lt 5 ]]
then
        echo "Error: Less than 5 arguments passed to this script."
        exit 1
fi

pemFilePath="$1"
squashfsFileName="$2"
netbootIP="$3"
netbootUsername="$4"
folderToPromoteTo="$5"

# Assume that the new squashfs uses the latest kernel version
kernelVersion=$(curl "http://$netbootIP/kernels/latest-kernel-version.json" | jq -r .version)

kernelVersionFile="${squashfsFileName%.*}-kernel.json"
echo '{ "version": "'"$kernelVersion"'" }' > "$kernelVersionFile"

scp -i "$pemFilePath" -o StrictHostKeyChecking=no "../build/$squashfsFileName" "$netbootUsername@$netbootIP:/home/master/netboot/assets/$folderToPromoteTo/$squashfsFileName" 
scp -i "$pemFilePath" -o StrictHostKeyChecking=no "$kernelVersionFile" "$netbootUsername@$netbootIP:/home/master/netboot/assets/$folderToPromoteTo/$kernelVersionFile" 
