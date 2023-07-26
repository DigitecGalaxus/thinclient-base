#!/bin/bash
set -eu -o pipefail

# This script checks if there is a newer kernel available upstream at the public netbootxyz repository. If it is, it downloads it to our netboot server into the kernels folder. It creates a json file which describes the kernel version of the just-downloaded kernel for later comparison. If there was a new kernel, attempt to fetch an initrd from upstream as well.

# Returns whether the kernel version passed is newer than the one we currently have on the blob storage
# 0 = true, 1 = false
function isKernelNewerThanOnBlobStorage {
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
    rm -f "$filename"
    if [[ "$version" != "$latestVersionOnBlobStorage" ]]; then
        # Assume it's newer, if it is different. Probably fine for this usecase.
        return 0
    fi
    return 1
}

function copyToBlob {
    filename="$1"
    targetFolder="$2"

    containerId=$(docker run -d --pull always -v "$(pwd)/$filename:/var/live/$filename" "$dockerImageName" azcopy copy "/var/live/$filename" "$imageBlobURL/$targetFolder/$filename?$armSasToken")
    exitCode=$(docker wait "$containerId")
    docker logs "$containerId"
    docker rm -f "$containerId"
    if [ "$exitCode" -ne 0 ]; then
        echo "azcopy failed with exit code $exitCode"
        exit "$exitCode"
    fi
    rm -f "$(pwd)/$filename"
}

if [[ $# -lt 1 ]]; then
    echo "Error: Less than 1 arguments passed to this script."
    exit 1
fi

# The SAS token to access the blob storage
armSasToken="$4"


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
file_map["vmlinuz"]="kernels/$kernelVersion"
file_map["initrd"]="kernels/$kernelVersion"
file_map["latest-kernel-version.json"]="kernels"

if [[ "$armSasToken" == "" ]]; then
    echo "No SAS token passed. Skipping upload to blob storage."
    exit 1
fi

set -x

if isKernelNewerThanOnBlobStorage "$kernelVersion"; then
    echo '{ "version": "'"$kernelVersion"'" }' >latest-kernel-version.json
    # Download initrd
    curl -L -o initrd "https://github.com/netbootxyz${yamlendpoints_ubuntu_23_04_KDE_squash_path}initrd"
    echo "Kernel is newer than the one on the blob storage. Copying to blob storage."
    for file in "${!file_map[@]}"; do
        destinationFolder="${file_map[$file]}"
        copyToBlob "$file" "$destinationFolder"
    done
else
    echo "Kernel is already up-to-date"
fi
