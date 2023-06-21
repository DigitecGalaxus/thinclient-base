#!/bin/bash
set -eu -o pipefail

# This script checks if there is a newer kernel available upstream at the public netbootxyz repository. If it is, it downloads it to our netboot server into the kernels folder. It creates a json file which describes the kernel version of the just-downloaded kernel for later comparison. If there was a new kernel, attempt to fetch an initrd from upstream as well.

# Returns whether the kernel version passed is newer than the one we currently have on the netboot server
function isKernelNewer {
    version="$1"
    local netbootIP="$2"
    latestVersionOnNetbootServer=$(curl "http://$netbootIP/kernels/latest-kernel-version.json" | jq -r .version)
    if [[ "$version" != "$latestVersionOnNetbootServer" ]]; then
        # Assume it's newer, if it is different. Probably fine for this usecase.
        echo true
        return
    fi
    echo false
}

# Returns whether the kernel version passed is newer than the one we currently have on the blob storage
function isKernelNewerOnBlobStorage {
    version="$1"
    filename="latest-kernel-version.json"
    rm -f "$filename"

    containerId=$(docker run -d --pull always -v "$(pwd)/:/var/live/" "$dockerImageName" azcopy copy "$imageBlobURL/kernels/$filename?$armSasToken" "/var/live/$filename")
    exitCode=$(docker wait "$containerId")
    if [ "$exitCode" -ne 0 ]; then
        docker logs "$containerId"
        docker rm -f "$containerId"
        echo "azcopy failed with exit code $exitCode"
        exit "$exitCode"
    fi
    docker rm -f "$containerId"

    latestVersionOnBlobStorage=$(jq -r .version <"$filename")
    if [[ "$version" != "$latestVersionOnBlobStorage" ]]; then
        # Assume it's newer, if it is different. Probably fine for this usecase.
        echo true
        return
    fi
    echo false
}

function copyToBlob {
    filename="$1"
    targetFolder="$2"

    containerId=$(docker run -d --pull always -v "$filename:/var/live/$filename" "$dockerImageName" azcopy copy "/var/live/$filename" "$imageBlobURL/$targetFolder/$filename?$armSasToken")
    exitCode=$(docker wait "$containerId")
    docker logs "$containerId"
    docker rm -f "$containerId"
    if [ "$exitCode" -ne 0 ]; then
        echo "azcopy failed with exit code $exitCode"
        exit "$exitCode"
    fi

}

if [[ $# -lt 3 ]]; then
    echo "Error: Less than 3 arguments passed to this script."
    exit 1
fi

# The path to the private key for the netboot server
pemFilePath="$1"
# The netboot IP address
netbootIP="$2"
# The username to ssh to the netboot server
netbootUsername="$3"
# armSasToken is optional
set +u
# The SAS token to access the blob storage
armSasToken="$4"
set -u

imageBlobURL="https://thinclientsimgstore.blob.core.windows.net"
dockerImageName="anymodconrst001dg.azurecr.io/planetexpress/squashfs-tools:latest"

# Get most recent endpoints.yml to parse locations of latest kernels and initRDs.
latestRelease=$(curl -sL "https://api.github.com/repos/netbootxyz/netboot.xyz/releases/latest" | jq -r '.tag_name')
# Remove potential previous endpoints.yml
if [[ -f "./endpoints.yml" ]]; then
    rm -f ./endpoints.yml
fi
wget "https://raw.githubusercontent.com/netbootxyz/netboot.xyz/$latestRelease/endpoints.yml"

# Import YAML-Parser. This yaml parser allows to read a yaml file into variables with the variable prefix passed as second argument.
source "./yaml-parser.sh"

# Parse actual yml into variables. This will create the variables `yamlendpoints_ubuntu_... and many more.
create_variables endpoints.yml yaml
rm -f ./endpoints.yml

curl -L -o vmlinuz "https://github.com/netbootxyz${yamlendpoints_ubuntu_23_04_KDE_squash_path}vmlinuz"
# Determine the kernel version of the just downloaded kernel, e.g. "5.4.0-42-generic"
kernelVersion=$(file -b vmlinuz | grep -o 'version [^ ]*' | cut -d ' ' -f 2)
echo "Newest kernel has version $kernelVersion"

# Maps the filename to the target folder, where it will be copied to
declare -A file_map
file_map["vmlinuz"]="$kernelVersion"
file_map["initrd"]="$kernelVersion"
file_map["latest-kernel-version.json"]="kernels"
kernelIsNew=$(isKernelNewer "$kernelVersion" "$netbootIP")
if $kernelIsNew; then
    echo '{ "version": "'"$kernelVersion"'" }' >latest-kernel-version.json
    assetsPath="/home/$netbootUsername/netboot/assets/"
    ssh -i "$pemFilePath" -o "StrictHostKeyChecking=no" "$netbootUsername@$netbootIP" mkdir -p "$assetsPath/kernels/$kernelVersion"
    # Download initrd
    curl -L -o initrd "https://github.com/netbootxyz${yamlendpoints_ubuntu_23_04_KDE_squash_path}initrd"
    # create map from filename to target folder

    for file in "${!file_map[@]}"; do
        destinationFolder="${file_map[$file]}"
        # Upload kernel into the kernel folder on the netboot server
        scp -i "$pemFilePath" -o "StrictHostKeyChecking=no" "$file" "$netbootUsername@$netbootIP:$assetsPath/$destinationFolder/$file"
    done
else
    echo "Kernel is already up-to-date"
fi

if [[ "$armSasToken" == "" ]]; then
    echo "No SAS token passed. Skipping upload to blob storage."
    exit 0
fi

set -x
kernelIsNew=$(isKernelNewerOnBlobStorage "$kernelVersion")
if $kernelIsNew; then
    echo "Kernel is newer than the one on the blob storage. Copying to blob storage."
    for file in "${!file_map[@]}"; do
        destinationFolder="${file_map[$file]}"
        copyToBlob "$file" "$destinationFolder"
    done
else
    echo "Kernel is already up-to-date"
fi
