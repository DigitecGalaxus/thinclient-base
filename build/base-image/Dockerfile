# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
FROM ubuntu:25.10

# Set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# Configure alternative apt mirrors for redundancy
COPY alternative-mirrors.list /etc/apt/sources.list.d/alternative-mirrors.list

# Fully upgrading the image
RUN apt-get update -qq > /dev/null 2>&1 && apt-get -qq -y full-upgrade > /dev/null 2>&1

# Install essential packages
RUN apt-get update -qq > /dev/null 2>&1 && \
    apt-get install -y -qq jq wget curl unminimize software-properties-common > /dev/null 2>&1 && \
    apt-get install -y -qq gnupg2 apt-utils wget sudo vim syslog-ng earlyoom iputils-ping dnsutils traceroute ca-certificates conky-all openssh-server libxss1 zram-config > /dev/null 2>&1

RUN yes | unminimize > /dev/null 2>&1RUN yes | unminimize > /dev/null 2>&1

# Resolving the current stable kernel version via the metapackage "linux-image-generic" and installing it. Can be hardcoded if necessary.
RUN apt-get install -y -qq $(apt-cache depends linux-image-generic | grep -P 'Depends:\s+linux-image-\d|Depends:\s+linux-modules-extra-' | cut -d ':' -f2 | tr -d "<> ") > /dev/null 2>&1

# Installing additional firmware/drivers for Intel and AMD CPUs, GPUs, WiFi, and Bluetooth. Also copy documentation.
RUN bash -c 'apt-get install -y -qq intel-microcode && \
    apt-get install -y -qq amd64-microcode && \
    apt-get download linux-firmware && \
    dpkg -x *.deb /tmp/linux-firmware/ && \
    mkdir /lib/firmware/i915/ && \
    cp /tmp/linux-firmware/usr/lib/firmware/i915/* /lib/firmware/i915/ && \
    cp -r /tmp/linux-firmware/usr/lib/firmware/iwlwifi-* /lib/firmware/ && \
    mkdir /lib/firmware/intel/ && \ 
    cp /tmp/linux-firmware/usr/lib/firmware/intel/ibt-0041-0041* /lib/firmware/intel/ && \
    cp /tmp/linux-firmware/usr/lib/firmware/intel/ibt-19-0-4* /lib/firmware/intel/ && \
    mkdir /lib/firmware/amdgpu/ && \ 
    cp /tmp/linux-firmware/usr/lib/firmware/amdgpu/raven* /lib/firmware/amdgpu/ && \
    cp /tmp/linux-firmware/usr/lib/firmware/amdgpu/polaris* /lib/firmware/amdgpu/ && \
    cp -r /tmp/linux-firmware/usr/share/doc/linux-firmware /usr/share/doc/ && \
    rm -rfv /tmp/linux-firmware > /dev/null 2>&1 && rm -fv *.deb' > /dev/null 2>&1

# Setup default login
RUN echo ubuntu:ubuntu | chpasswd

# Configure Userdir creation.
RUN echo "session optional pam_mkhomedir.so umask=0077" >> /etc/pam.d/common-session

# Conky - program to display stats on desktop
COPY ./conky/conky.conf /etc/conky/conky.conf
COPY ./conky/conky.desktop /etc/xdg/autostart/conky.desktop

# Add automatic Shutdown Trigger after a specified time defined in the restart.service file.
COPY ./restart/restart.service /etc/systemd/system/restart.service
RUN ln -s /etc/systemd/system/restart.service /etc/systemd/system/multi-user.target.wants/restart.service

# Add hostname renaming service including systemd configuration.
COPY ./hostname/hostname-changer.sh /usr/local/share/scripts/hostname-changer.sh
COPY ./hostname/hostname-changer.service /etc/systemd/system/hostname-changer.service
RUN mkdir -p /etc/systemd/system/network.target.wants/ && \
    ln -s /etc/systemd/system/hostname-changer.service /etc/systemd/system/network.target.wants/hostname-changer.service

# Install GNOME as desktop environment
RUN apt-get -qq update && apt-get -qq install -y gnome fonts-noto-color-emoji > /dev/null 2>&1

# Prevent GNOME keyring prompts for auto-login scenarios (optional)
# RUN rm -f /usr/share/dbus-1/services/org.gnome.keyring*.service

# Initialise Network Manager
# COPY ./network/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf
# This seems to be necessary for the network manager to recognize the default connection properly
# RUN mkdir -p /etc/NetworkManager/conf.d/ && touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Configure zram-swapping to save memory.
COPY --chown=root:root --chmod=755 ./zram-config/init-zram-swapping /usr/bin/init-zram-swapping
COPY --chown=root:root --chmod=644 ./zram-config/zram-config.service /lib/systemd/system/zram-config.service

# This cleanup works, as we'll be copying the complete filesystem later, therefore omitting any files that would still exist in an underlying layer.
# delete obsolete packages and any temporary state
RUN apt-get -qq autoremove -y > /dev/null 2>&1 && apt-get -qq clean > /dev/null 2>&1  && \
    rm -rf \
    /tmp/* \
    /var/backups/* \
    /var/log/* \
    /var/run/* \
    /var/crash/* \
    ~/.bash_history
