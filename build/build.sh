#!/bin/bash
set -e -o pipefail

# This script builds a squashfs containing a customized ubuntu distribution designed to be network booted

function removeFileIfExists {
        fileName="$1"
        if [[ -f "$fileName" ]]; then
                rm -f "$fileName"
        fi
}

# If there are less than six arguments passed to the build script (e.g. for local execution), try to set them automatically

if [[ $# -lt 1 ]]; then
        echo "Error: No arguments passed. Make sure to pass at least the Netboot IP Address"
else
        if [[ $# -lt 4 ]]; then
                echo "Warning: Passed less than 4 arguments. Ignoring all passed arguments and determining defaults"
                netbootIP="$1"
                branchName=$(git symbolic-ref -q --short HEAD)
                branchName=${branchName:-HEAD}
                gitCommitShortSha="$(git log -1 --pretty=format:%h)"
                useDockerBuildCache="true"
        else
                netbootIP="$1"
                branchName="$2"
                # In AzureDevOps it's only possible to pass the full commit sha - this is too long for us so we shorten it to 7 characters
                gitCommitShortSha="${3:0:7}"
                useDockerBuildCache="$4"

        fi
fi

if [[ "$useDockerBuildCache" == "true" || "$useDockerBuildCache" == "True" ]]; then
        dockerBuildCacheArgument=""
else
        dockerBuildCacheArgument="--no-cache"
fi

# Setting this intentionally after the argument parsing for the shell script
set -u

imageName="anymodconrst001dg.azurecr.io/planetexpress/thinclient-base:21.04"

# Name of the resulting squashfs file, e.g. 21-01-17-master-6d358edc.squashfs
squashfsFilename="$(date +%y-%m-%d)-$branchName-$gitCommitShortSha.squashfs"

# --no-cache is useful to apply the latest updates within an apt-get full-upgrade
#docker image build --pull $dockerBuildCacheArgument -t "anymodconrst001dg.azurecr.io/planetexpress/thinclient-base:21.04" .
docker image build --build-arg OS_RELEASE=${squashfsFilename%.*} --build-arg NETBOOT_IP=$netbootIP --pull $dockerBuildCacheArgument -t "$imageName" .

tarFileName="newfilesystem.tar"
removeFileIfExists "$tarFileName"

echo "Starting to tar container filesystem - this will take a while..."
#containerID=$(docker container create "$imageName" tail /dev/null)
containerID=$(docker run -d "$imageName" tail -f /dev/null)
docker cp "$containerID:/" - >"$tarFileName"
docker rm -f "$containerID"

echo "Starting to convert tar file to squashfs file - this will take a while..."

removeFileIfExists "$squashfsFilename"
touch "$squashfsFilename"
squashfsContainerID=$(docker run -d -u $(id -u) \
        -v "$(pwd)/$tarFileName:/var/live/$tarFileName" \
        -v "$(pwd)/$squashfsFilename:/var/live/newfilesystem.squashfs" \
        anymodconrst001dg.azurecr.io/planetexpress/squashfs-tools:latest /bin/sh -c "tar2sqfs --force --quiet newfilesystem.squashfs < /var/live/$tarFileName")
docker wait "$squashfsContainerID"
docker rm -f "$squashfsContainerID"
rm -f "$(pwd)/$tarFileName"

squashfsAbsolutePath="$(pwd)/$squashfsFilename"
# AzureDevOps specific way of passing an output variable to subsequent steps in the pipeline
echo "##vso[task.setvariable variable=squashfsAbsolutePath;isOutput=true]$squashfsAbsolutePath"
