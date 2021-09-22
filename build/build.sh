#!/bin/bash
set -e -o pipefail

# This script builds a squashfs containing a customized ubuntu distribution designed to be network booted

function removeFileIfExists {
        fileName="$1"
        if [[ -f "$fileName" ]]
        then
                rm -f "$fileName"
        fi
}

# If there are less than six arguments passed to the build script (e.g. for local execution), try to set them automatically
if [[ $# -lt 3 ]]
then
        echo "Warning: Passed less than 3 arguments. Ignoring all passed arguments and determining defaults"
        branchName=$(git symbolic-ref -q --short HEAD)
        branchName=${branchName:-HEAD}
        gitCommitShortSha="$(git log -1 --pretty=format:%h)"
        useDockerBuildCache="true"
else
        branchName="$1"
        # In AzureDevOps it's only possible to pass the full commit sha - this is too long for us so we shorten it to 7 characters
        gitCommitShortSha="${2:0:7}"
        useDockerBuildCache="$3"
fi

if [[ "$useDockerBuildCache" == "true" || "$useDockerBuildCache" == "True" ]]
then
        dockerBuildCacheArgument=""
else
        dockerBuildCacheArgument="--no-cache"
fi

# Setting this intentionally after the argument parsing for the shell script
set -u

imageName="anymodconrst001dg.azurecr.io/planetexpress/thinclient-base:21.04"

# --no-cache is useful to apply the latest updates within an apt-get full-upgrade
#docker image build --pull $dockerBuildCacheArgument -t "anymodconrst001dg.azurecr.io/planetexpress/thinclient-base:21.04" .
docker image build -t "$imageName" .


tarFileName="newfilesystem.tar"
removeFileIfExists "$tarFileName"

# Name of the resulting squashfs file, e.g. 21-01-17-master-6d358edc.squashfs
squashfsFilename="$(date +%y-%m-%d)-$branchName-$gitCommitShortSha.squashfs"

echo "Starting to tar container filesystem - this will take a while..."
containerID=$(docker container create "$imageName" tail /dev/null)
docker cp "$containerID:/" - > "$tarFileName"
docker rm -f "$containerID"

echo "Starting to convert tar file to squashfs file - this will take a while..."

removeFileIfExists "$squashfsFilename"
touch "$squashfsFilename"
squashfsContainerID=$(docker run -d -u $(id -u)\
        -v "$(pwd)/$tarFileName:/var/live/$tarFileName" \
        -v "$(pwd)/$squashfsFilename:/var/live/newfilesystem.squashfs" \
        anymodconrst001dg.azurecr.io/planetexpress/squashfs-tools:latest /bin/sh -c "tar2sqfs --force --quiet newfilesystem.squashfs < /var/live/$tarFileName")
docker wait "$squashfsContainerID"
docker rm -f "$squashfsContainerID"
rm -f "$(pwd)/$tarFileName"

squashfsAbsolutePath="$(pwd)/$squashfsFilename"
# AzureDevOps specific way of passing an output variable to subsequent steps in the pipeline
echo "##vso[task.setvariable variable=squashfsAbsolutePath;isOutput=true]$squashfsAbsolutePath"
