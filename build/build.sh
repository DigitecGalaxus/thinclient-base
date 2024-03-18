#!/bin/bash
set -e -o pipefail
# This script is used to build all artifacts needed to run netbooted thinclients: Docker images for further usage, kernel, initrd as well as the squashed rootfs

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

# This argument is used in order to trigger the export of the SquashFS into the exported-artifacts directory.
if [[ "$exportSquashFS" == "" ]]; then
    exportSquashFS="false"
    echo "Warning: No exportSquashFS passed. Only building the docker image for further usage."
fi

# This argument is used in order to trigger the export of artifacts as files (kernel, initrd and squashed rootfs)
if [[ "$exportBootArtifacts" == "" ]]; then
    exportBootArtifacts="false"
    echo "Warning: No exportBootArtifacts passed. Only building the docker image for further usage."
fi

# This argument is used to clearly identify the built artifacts and docker images
if [[ "$branchName" == "" ]]; then
    # To be consistent with the naming of the azure devops variable Build.SourceBranchName, we remove the prefixes containing slashes
    branchName=$(git symbolic-ref -q --short HEAD | rev | cut -d'/' --fields=1 | rev)
    echo "Warning: No branch name passed. Using $branchName as branch name."
fi

# This argument is used to force a complete rebuild by ignoring any cached docker layers. Probably handy when Ubuntu packages have to be updated from the repos.
if [[ "$disableDockerCaching" == "true" || "$disableDockerCaching" == "True" ]]; then
    dockerBuildCacheArgument="--no-cache --pull"
else
    echo "Info: Docker Caching is not disabled."
    dockerBuildCacheArgument=""
fi

# Setting this intentionally after the argument parsing for the shell script
set -u

# Setting the target docker image name
imageName="thinclient-base:$branchName"

# Running the base-image docker build.
docker image build --progress=plain $dockerBuildCacheArgument -t "$imageName" ./base-image

# If you want to export the artifacts on this stage, run ./build.sh exportSquashFS="true"
if [[ "$exportBootArtifacts" == "true" ]]; then
    echo "Purging old boot artifacts before starting a new build..."
    rm -r ./exported-artifacts/initrd.img
    rm -r ./exported-artifacts/vmlinuz
    # Running the bootartifacts docker build and exporting them directly.
    DOCKER_BUILDKIT=1 docker image build --progress=plain --build-arg IMAGE_BASE=$imageName --output ./exported-artifacts ./bootartifacts
fi

# If you want to export the squashFS on this stage, run ./build.sh exportSquashFS="true"
if [[ "$exportSquashFS" != "true" ]]; then
    echo "Skipping export of SquashFS; the base docker image is now ready for further processing on this host."
    exit 0
fi

echo "Purging old SquashFS before starting a new build..."
rm -r ./exported-artifacts/base.squashfs

# Name of the resulting squashfs file, e.g. 21-01-17-master-6d358edc.squashfs
squashfsFile="$(pwd)"/exported-artifacts/base.squashfs

tarFile="$(pwd)"/exported-artifacts/base.tar
removeFileIfExists "$tarFile"

echo "Starting to tar container filesystem - this will take a while..."
# This needs to be a docker container run to also copy container runtime info such as /etc/resolv.conf
containerID=$(docker run -d "$imageName" tail -f /dev/null)
docker cp "$containerID:/" - >"$tarFile"
docker rm -f "$containerID"

echo "Starting to convert tar file to squashfs file - this will take a while..."

removeFileIfExists "$squashfsFile"
touch "$squashfsFile"
squashfsContainerID=$(docker run -d -u $(id -u) \
    -v "$tarFile:/var/live/$tarFile" \
    -v "$squashfsFile:/var/live/newfilesystem.squashfs" \
    dgpublicimagesprod.azurecr.io/planetexpress/squashfs-tools:latest /bin/sh -c "tar2sqfs --force --quiet newfilesystem.squashfs < /var/live/$tarFile")
docker wait "$squashfsContainerID"
docker rm -f "$squashfsContainerID"
rm -f "$tarFile"

echo "Exported artifacts are copied to ./exported-artifacts, have fun."