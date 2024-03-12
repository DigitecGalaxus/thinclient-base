# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
ARG IMAGE_BASE
FROM ${IMAGE_BASE} as bootartifactbuilder

# Set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# curl and jq are prerequisites for the install-kernel-package.sh script
RUN apt-get update -qq > /dev/null 2>&1 && apt-get -qq -y full-upgrade > /dev/null 2>&1 && apt-get install -y -qq linux-image-generic > /dev/null 2>&1

# add files
COPY /initrd-patch /
RUN chmod +x /curl-hook && cp /curl-hook /usr/share/initramfs-tools/hooks/

RUN \
 echo "**** install deps ****" && \
 apt-get update && \
 apt-get install -y \
	casper \
	patch \
    busybox-initramfs \
	rsync && \
 echo "**** patch casper ****" && \
 patch /usr/share/initramfs-tools/scripts/casper < /patch && \
 patch /usr/share/initramfs-tools/scripts/casper-bottom/24preseed < /preseed-patch

RUN update-initramfs -u

FROM scratch as export-stage
COPY --from=bootartifactbuilder /boot/initrd.img .
COPY --from=bootartifactbuilder /boot/vmlinuz .