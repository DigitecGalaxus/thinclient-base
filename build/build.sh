#!/bin/bash
set -e -o pipefail

# This script builds a squashfs containing a customized ubuntu distribution designed to be network booted

function removeFileIfExists {
    fileName="$1"
    if [[ -f "$fileName" ]]; then
        rm -f "$fileName"
    fi
}

# Parsing arguments passed to the build script which should be key=value pairs
for ARGUMENT in "$@"; do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    KEY_LENGTH=${#KEY}
    VALUE="${ARGUMENT:$KEY_LENGTH+1}"
    export "$KEY"="$VALUE"
done

# This argument is required to read the latest kernel version from the netboot server
if [[ "$netbootIP" == "" ]]; then
    echo "Error: No arguments passed. Make sure to pass at least the Netboot IP Address, e.g. netbootIP=10.1.30.7"
    exit 1
fi
if [[ "$netbootUsername" == "" ]]; then
    netbootUsername="master"
    echo "Warning: No netbootUsername passed. Using $netbootUsername as netbootUsername"
fi
if [[ "$netbootSSHPrivateKey" == "" ]]; then
    netbootSSHPrivateKey="$(pwd)/netboot-server-new-arch.pem"
    echo "Warning: No netbootSSHPrivateKey passed. Using $netbootSSHPrivateKey as netbootSSHPrivateKey"
fi
if [[ "$branchName" == "" ]]; then
    # To be consistent with the naming of the azure devops variable Build.SourceBranchName, we remove the prefixes containing slashes
    branchName=$(git symbolic-ref -q --short HEAD | rev | cut -d'/' --fields=1 | rev)
    echo "Warning: No branch name passed. Using $branchName as branch name"
fi
if [[ "$gitCommitShortSha" == "" ]]; then
    gitCommitShortSha="$(git log -1 --pretty=format:%h)"
    echo "Warning: No git commit short sha passed. Using $gitCommitShortSha as git commit short sha"
fi
# In AzureDevOps it's only possible to pass the full commit sha - this is too long for us so we shorten it to 7 characters
gitCommitShortSha="${gitCommitShortSha:0:7}"
if [[ "$useDockerBuildCache" == "" ]]; then
    useDockerBuildCache="true"
    echo "Warning: No useDockerBuildCache passed. Using $useDockerBuildCache as useDockerBuildCache"
fi
if [[ "$buildSquashfsAndPromote" == "" ]]; then
    buildSquashfsAndPromote="false"
    echo "Warning: No buildSquashfsAndPromote passed. Using $buildSquashfsAndPromote as buildSquashfsAndPromote"
fi
if [[ "$useDockerBuildCache" == "true" || "$useDockerBuildCache" == "True" ]]; then
    dockerBuildCacheArgument=""
else
    dockerBuildCacheArgument="--no-cache --pull"
fi
if [[ "$folderToPromoteTo" == "" ]]; then
    folderToPromoteTo="dev"
    echo "Warning: No folderToPromoteTo passed. Using $folderToPromoteTo as folderToPromoteTo"
fi

# Setting this intentionally after the argument parsing for the shell script
set -u

imageName="anymodconrst001dg.azurecr.io/planetexpress/thinclient-base:$branchName"
echo "##vso[task.setvariable variable=branchName;isOutput=true]$branchName"

# Name of the resulting squashfs file, e.g. 21-01-17-master-6d358edc.squashfs
squashfsFilename="base.squashfs"

# --no-cache is useful to apply the latest updates within an apt-get full-upgrade
docker image build --progress=plain --build-arg OS_RELEASE=${squashfsFilename%.*} --build-arg NETBOOT_IP=$netbootIP $dockerBuildCacheArgument -t "$imageName" .

# Build bootartifacts
DOCKER_BUILDKIT=1 docker image build --progress=plain --build-arg IMAGE_BASE=$imageName --file bootartifacts.Dockerfile --output ./ .

# If you want to promote the image directly to the caching server, run ./build.sh buildSquashfsAndPromote="true"
if [[ "$buildSquashfsAndPromote" != "true" ]]; then
    echo "Skipping squashfs build and promotion"
    exit 0
fi

tarFileName="newfilesystem.tar"
removeFileIfExists "$tarFileName"

echo "Starting to tar container filesystem - this will take a while..."
# This needs to be a docker container run to also copy container runtime info such as /etc/resolv.conf
containerID=$(docker run -d "$imageName" tail -f /dev/null)
mv $(pwd)/initrd.img $(pwd)/initrd
# export rootfs
docker cp "$containerID:/" - >"$tarFileName"
docker rm -f "$containerID"

echo "Starting to convert tar file to squashfs file - this will take a while..."

removeFileIfExists "$squashfsFilename"
touch "$squashfsFilename"
squashfsContainerID=$(docker run -d -u $(id -u) \
    -v "$(pwd)/$tarFileName:/var/live/$tarFileName" \
    -v "$(pwd)/$squashfsFilename:/var/live/newfilesystem.squashfs" \
    dgpublicimagesprod.azurecr.io/planetexpress/squashfs-tools:latest /bin/sh -c "tar2sqfs --force --quiet newfilesystem.squashfs < /var/live/$tarFileName")
docker wait "$squashfsContainerID"
docker rm -f "$squashfsContainerID"
rm -f "$(pwd)/$tarFileName"

squashfsAbsolutePath="$(pwd)/$squashfsFilename"
vmlinuzAbsolutePath="$(pwd)/vmlinuz"
initrdAbsolutePath="$(pwd)/initrd"

# If you want to promote the image directly to the caching server on dev or prod, run ./build.sh buildSquashfsAndPromote="true" folderToPromoteTo="dev"
echo "Uploading image to caching server..."
ssh -i "$netbootSSHPrivateKey" -o StrictHostKeyChecking=no "$netbootUsername@$netbootIP" "mkdir -p /home/$netbootUsername/netboot/assets/$folderToPromoteTo/$(date +%y-%m-%d)-$branchName-$gitCommitShortSha/"
scp -i "$netbootSSHPrivateKey" -o StrictHostKeyChecking=no "$squashfsAbsolutePath" "$netbootUsername@$netbootIP:/home/$netbootUsername/netboot/assets/$folderToPromoteTo/$(date +%y-%m-%d)-$branchName-$gitCommitShortSha/$squashfsFilename"
scp -i "$netbootSSHPrivateKey" -o StrictHostKeyChecking=no "$initrdAbsolutePath" "$netbootUsername@$netbootIP:/home/$netbootUsername/netboot/assets/$folderToPromoteTo/$(date +%y-%m-%d)-$branchName-$gitCommitShortSha/initrd"
scp -i "$netbootSSHPrivateKey" -o StrictHostKeyChecking=no "$vmlinuzAbsolutePath" "$netbootUsername@$netbootIP:/home/$netbootUsername/netboot/assets/$folderToPromoteTo/$(date +%y-%m-%d)-$branchName-$gitCommitShortSha/vmlinuz"