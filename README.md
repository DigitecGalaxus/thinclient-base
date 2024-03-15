# Thin Clients

This repository contains files and scripts to build a customized version of the ubuntu-base image, which is designed to be booted via network boot from a diskless device. The customized OS is designed to be a rather simple operating system, where most work is done in Browsers.

## Customizations

To make the image a bit more suitable for a stateless operation, there are some customisations which should make the experience better.

### Authentication

The PAM common-session is adjusted to execute a script, which logs out old users. This ensures that not too many users are logged in and eat up the available Memory. This will be useful, when more than one user is logged in to the thin client.

### Conky

Conky displays informations about the current status of the thin client. It gives a brief overview over the configured networks, system workloads, hostnames and more on the desktop.

### Hostname

The thin client gets a unique and recognizable hostname from the `hostname-changer.sh` script. The Hostname is set to `tc-{MACAddressCharacters}`.

### Network

The changes in the networks are small and only for aesthetics. When not applying the settings in the configuration, on runtime of the client, we get a message that no network adapter is connected (while it is working and connected).

### Restart

A trigger is implemented for an automatic restart for the thin client. This should ensure, that a clean boot is done after a while and start freshly with an up-to-date system. The default such that the system reboots after two weeks during the night.

Note: In the terminal you will see periodically, when the system is going to reboot. If you want to check it while on desktop, Conky displays this information too.

### Scrolling

This is an experimental feature. The scrolling with the scroll wheel is not working on all devices. This scripts checks all pointer devices and enables scrolling with the wheel.

### Build

The standard process only generates a Docker image that is subject to further customization. But if you set exportArtifacts=true, it makes the script produce the three essential artifacts - squashfs, initrd, and kernel. Then you can transfer these artifacts to any netboot server for immediate booting or testing.

## Contribute

No matter how small, we value every contribution! If you wish to contribute,

1. Please create an issue first - this way, we can discuss the feature and flesh out the nitty-gritty details
2. Fork the repository, implement the feature and submit a pull request
3. Your feature will be added once the pull request is merged
