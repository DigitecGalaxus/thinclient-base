# Thin Clients

This repository contains files and scripts to build a customized version of the ubuntu-base image, which is designed to be booted via network boot from a diskless device. The customized OS is designed to be a rather simple operating system, where most work is done in browsers.

## Customizations

To make the image a bit more suitable for a stateless operation, there are some customisations which should make the experience better.

### Conky

Conky displays informations about the current status of the thin client, including the build version in order to simplify debugging together with the users. It gives a brief overview over the configured networks, system workloads, hostnames and more on the desktop.

### Hostname

The thin client gets a unique and recognizable hostname from the `hostname-changer.sh` script. The Hostname is set to `tc-{MACAddressCharacters}`.

### Network

The changes in the networks are small and only for aesthetics. When not applying the settings in the configuration, on runtime of the client, we get a message that no network adapter is connected (while it is working and connected).

### Restart

A trigger is implemented for an automatic restart for the thin client. This should ensure, that a clean boot is done after a while and start freshly with an up-to-date system. The default such that the system reboots after one month during the night.

Note: In the terminal you will see periodically, when the system is going to reboot. If you want to check it while on desktop, Conky displays this information too.

### Scrolling

This is an experimental feature. The scrolling with the scroll wheel is not working on all devices. This scripts checks all pointer devices and enables scrolling with the wheel.

### ZRAM-Config

Initializes and configures zram, a block device that trades CPU for potentially more ramdisk storage or memory. It sets up two zram devices, one for swap space and the other as a temporary home directory, each using a certain portion of the total memory.

## Build

### Boot-artifact creation

This basically uses a Docker build process to directly export the artifacts from the corresponding docker image. This way, all three components (initrd, kernel as well as squashfs) are compatible with each other (for instance due to kernel modules being present in the squashfs).

The build.sh script calls this build and exports the artifacts directly to the exported-artifacts directory instead of a docker image.

The scripts and patches inside initrd-patch modify the existing inird to allow booting from an online source. The first script adds 'curl' and 'wget' to the initial file system, along with SSL certificates. The second script allows the system to boot from a URL and the third one automates the installation process.

This is copied / inspired from https://netboot.xyz/docs/community/build-automation/

### Putting it all together

The standard process only generates a Docker image that is subject to further customization by using it as a base image. But if you set exportArtifacts=true, it makes the script produce the three essential artifacts - squashfs, initrd, and kernel. Then you can transfer these artifacts to any netboot server for immediate booting or testing.

## Contribute

No matter how small, we value every contribution! If you wish to contribute,

1. Please create an issue first - this way, we can discuss the feature and flesh out the nitty-gritty details
2. Fork the repository, implement the feature and submit a pull request
3. Your feature will be added once the pull request is merged
