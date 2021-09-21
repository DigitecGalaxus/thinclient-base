# Thin Clients

This repository contains files and scripts to build a customized version of the ubuntu-base image, which is designed to be booted via network boot from a diskless device. The customized OS is designed to be a rather simple operating system, where most work is done in Browsers.

## Customizations

To make the image a bit more suitable for a stateless operation, we have made some customisations which should make the experience better.

### Authentication

The PAM common-session config is adjusted to execute a script, which logs out old users. This ensures that not too many users are logged in and eat up the available Memory. This will be useful, when more than one user is logged in to the thin client.

### Conky

Conky displays informations about the current status of the thinclient. It gives a brief overview over the configured networks, system workloads, hostnames and more.

### Hostname

The thin client gets a unique and recognizable hostname from the `hostname-changer.sh` script. The Hostname is set to `thinclient-{lastSixMACAddressCharacters}`.

### Network

The changes in the networks are small and only for aesthetics. When not applying the settings in the configuration, on runtime of the client, we get a message that no network adapter is connected (while it is working and connected).

### Restart

We have implemented a trigger for an automatic restart for the thinclient. This should ensure, that we have a clean boot after a while and free up the clogged system after a while. Our default is set to two weeks, but this can be adjusted or removed according to your liking. 

Note: In the terminal you will see periodically, when the system is going to reboot. If you want to check it while on desktop, Conky displays this information too.

### Scrolling

This is an experimental feature. We got some notifications, that scrolling with the scroll wheel was not working. This scripts checks all pointer devices and enables scrolling with the wheel.

## Contribute

No matter how small, we value every contribution! If you wish to contribute,

1. Please create an issue first - this way, we can discuss the feature and flesh out the nitty-gritty details
2. Fork the repository, implement the feature and submit a pull request
3. Your feature will be added once the pull request is merged
