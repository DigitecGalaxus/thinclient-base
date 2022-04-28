#!/bin/bash
set -eu -o pipefail

# This script checks if there is a newer kernel available upstream at the public netbootxyz repository. If it is, it downloads it to our netboot server into the kernels folder. It creates a json file which describes the kernel version of the just-downloaded kernel for later comparison. If there was a new kernel, attempt to fetch an initrd from upstream as well.

# Returns whether the kernel version passed is newer than the one we currently have on the netboot server
function isKernelNewer {
        version="$1"
        local netbootIP="$2"
        latestVersionOnNetbootServer=$(curl "http://$netbootIP/kernels/latest-kernel-version.json" | jq -r .version)
        if [[ "$version" != "$latestVersionOnNetbootServer" ]]
        then
                # Assume it's newer, if it is different. Probably fine for this usecase.
                echo true
        fi
        echo false
}

if [[ $# -lt 3 ]]
then
        echo "Error: Less than 3 arguments passed to this script."
        exit 1
fi

# The path to the private key for the netboot server
pemFilePath="$1"
# The netboot IP address
netbootIP="$2"
# The username to ssh to the netboot server
netbootUsername="$3"

# Get most recent endpoints.yml to parse locations of latest kernels and initRDs.
latestRelease=$(curl -sL "https://api.github.com/repos/netbootxyz/netboot.xyz/releases/latest" | jq -r '.tag_name')
# Remove potential previous endpoints.yml
if [[ -f "./endpoints.yml" ]]
then
        rm -f ./endpoints.yml
fi
wget "https://raw.githubusercontent.com/netbootxyz/netboot.xyz/$latestRelease/endpoints.yml"

# Import YAML-Parser. This yaml parser allows to read a yaml file into variables with the variable prefix passed as second argument.
source "./yaml-parser.sh"

# Parse actual yml into variables. This will create the variable `yamlendpoints_ubuntu_21_04_default_squash_path and many more. However, we only need the one for ubuntu 22.04 default squashfs 
create_variables endpoints.yml yaml
rm -f ./endpoints.yml

curl -L -o latest-kernel "https://github.com/netbootxyz${yamlendpoints_ubuntu_22_04_default_squash_path}vmlinuz"
# Determine the kernel version of the just downloaded kernel, e.g. "5.4.0-42-generic"
kernelVersion=$(file -b latest-kernel | grep -o 'version [^ ]*' | cut -d ' ' -f 2)
echo "Newest kernel has version $kernelVersion"

kernelIsNew=$(isKernelNewer "$kernelVersion" "$netbootIP")
if $kernelIsNew
then
        echo '{ "version": "'"$kernelVersion"'" }' > latest-kernel-version.json
        # Upload kernel into the kernel folder on the netboot server
        kernelFolder="/home/$netbootUsername/netboot/assets/kernels/$kernelVersion"
        ssh -i "$pemFilePath" -o "StrictHostKeyChecking=no" "$netbootUsername@$netbootIP" mkdir -p "$kernelFolder"
        scp -i "$pemFilePath" -o "StrictHostKeyChecking=no" "latest-kernel" "$netbootUsername@$netbootIP:$kernelFolder/vmlinuz"
        # Update the latest-kernel-version.json in the kernels folder on the netboot server
        scp -i "$pemFilePath" -o "StrictHostKeyChecking=no" "latest-kernel-version.json" "$netbootUsername@$netbootIP:/home/$netbootUsername/netboot/assets/kernels/latest-kernel-version.json"
        # Update initrd
        curl -L -o latest-initrd "https://github.com/netbootxyz${yamlendpoints_ubuntu_22_04_default_squash_path}initrd"
        scp -i "$pemFilePath" -o "StrictHostKeyChecking=no" "latest-initrd" "$netbootUsername@$netbootIP:$kernelFolder/initrd"
else
        echo "Kernel is already up-to-date"
fi
