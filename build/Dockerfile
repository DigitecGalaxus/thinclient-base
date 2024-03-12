# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
FROM ubuntu:23.04

# Set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# Unminimize is needed such that the languages work properly within KDE. Doing this early is faster.
RUN yes | unminimize > /dev/null 2>&1

COPY ./apt/sources.list /etc/apt/sources.list

# curl and jq are prerequisites for the install-kernel-package.sh script
RUN apt-get update -qq > /dev/null 2>&1 && apt-get -qq -y full-upgrade > /dev/null 2>&1 && apt-get install -y -qq jq curl > /dev/null 2>&1

# Used to determine the latest kernel version in the script
ARG NETBOOT_IP
COPY kernel/install-kernel-packages.sh install-kernel-packages.sh
RUN ./install-kernel-packages.sh $NETBOOT_IP

# Install bluetooth drivers for some devices only. The linux-firmware package is huge, so we only take some files we know we need.
# At the moment, the only bluetooth business requirement is the warehouse Odilia, where ProGloves are connected directly via Bluetooth instead of the USB-Dock. In Odilia, we therefore use only Intel NUCs, which need the "ibt-19-0-4*" files and the "Captiva Power Starter I73-688", which need the ibt-0041-0041* files.
# "iwlfiwi-*" files are not needed for bluetooth anymore but also include Intel Killer Wifi Drivers, which are nice to have.
# For additional devices, run the bluetooth software on the device itself and check the kernel messages with `dmesg`. This should show a message similar to "[19.479715] Bluetooth: hci0: Failed to load Intel firmware file intel/ibt-0041-0041.sfi (-2)", which shows the file name that is missing. Check `lspci` if you need to find out what chip you've connected.
RUN bash -c 'apt-get download linux-firmware && \
    dpkg -x *.deb /tmp/linux-firmware/ && \
    cp -r /tmp/linux-firmware/lib/firmware/iwlwifi-* /lib/firmware/ && \
    mkdir /lib/firmware/intel/ && \ 
    cp /tmp/linux-firmware/lib/firmware/intel/ibt-0041-0041* /lib/firmware/intel/ && \
    cp /tmp/linux-firmware/lib/firmware/intel/ibt-19-0-4* /lib/firmware/intel/ && \
    cp -r /tmp/linux-firmware/usr/share/doc/linux-firmware /usr/share/doc/ && \
    rm -rfv /tmp/linux-firmware > /dev/null 2>&1 && rm -fv *.deb' > /dev/null 2>&1

RUN apt-get -qq update && apt-get -qq install -y software-properties-common gnupg2 apt-utils wget ntp sudo vim syslog-ng earlyoom iputils-ping dnsutils traceroute ca-certificates conky openssh-server libxss1 zram-config > /dev/null 2>&1

# Setup default login
RUN echo ubuntu:ubuntu | chpasswd

# Configure Userdir Creation + Initialise logout-old-user script.
RUN echo "session optional pam_mkhomedir.so umask=0077" >> /etc/pam.d/common-session
# RUN echo "session optional pam_exec.so log=/var/log/pam-logout.log /usr/local/share/scripts/logout-old-user.sh" >> /etc/pam.d/common-session
# COPY ./authentication/logout-old-user.sh /usr/local/share/scripts/logout-old-user.sh

# Conky - program to display stats on desktop
COPY ./conky/conky.conf /etc/conky/conky.conf
COPY ./conky/conky.desktop /etc/xdg/autostart/conky.desktop

# Add automatic Shutdown Trigger after a specified time defined in the restart.service file.
COPY ./restart/restart.service /etc/systemd/system/restart.service
RUN ln -s /etc/systemd/system/restart.service /etc/systemd/system/multi-user.target.wants/restart.service

# Add auto-enable of middle-mouse-clicks for generic devices.
COPY ./scrolling/mouse_scrolling.desktop /etc/skel/.config/autostart/mouse_scrolling.desktop
COPY ./scrolling/middle_click_to_scroll.sh /usr/local/share/scripts/middle_click_to_scroll.sh

# Add hostname renaming service including systemd configuration.
COPY ./hostname/hostname-changer.sh /usr/local/share/scripts/hostname-changer.sh
COPY ./hostname/hostname-changer.service /etc/systemd/system/hostname-changer.service
RUN mkdir -p /etc/systemd/system/network.target.wants/ && \
    ln -s /etc/systemd/system/hostname-changer.service /etc/systemd/system/network.target.wants/hostname-changer.service

# Set sddm as display manager and install Plasma / Wayland as desktop environment & Disable x11 in sddm, use wayland instead
RUN /bin/bash -c "debconf-set-selections <<< 'sddm shared/default-x-display-manager select sddm'" && apt-get -qq update && apt-get -qq install -y kde-plasma-desktop plasma-workspace-wayland plasma-nm dolphin print-manager libglib2.0-dev locales kde-spectacle kcalc > /dev/null 2>&1 && \
    rm -f /usr/share/xsessions/plasma.desktop

# Install superimportant emojis & Uninstall packages we don't need
RUN apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq fonts-noto-color-emoji > /dev/null 2>&1 && \
    apt-get -qq --purge remove -y kdeconnect partitionmanager xiterm+thai kaddressbook khelpcenter kmail kopete kwalletmanager korganizer okular sweeper dragonplayer juk pim-sieve-editor kwalletmanager gwenview imagemagick akregator konqueror plasma-discover gnome-shell gdm3 gnupg2 apt-utils cracklib-runtime > /dev/null 2>&1

# Prevent wallet / Key manager popups
RUN rm -f /usr/share/dbus-1/services/org.kde.kwalletd5.service

# Set the environment variable OS_RELEASE to identify the exact squashfs file booted. Can be visualized in Conky.
ARG OS_RELEASE
RUN echo "export dg_os_release=$OS_RELEASE" >> /etc/profile

# Initialise Network Manager
COPY ./network/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf
# This seems to be necessary for the network manager to recognize the default connection properly
RUN mkdir -p /etc/NetworkManager/conf.d/ && touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Configure init-zram-swapping
COPY --chown=root:root --chmod=755 ./zram-config/init-zram-swapping /usr/bin/init-zram-swapping
COPY --chown=root:root --chmod=644 ./zram-config/zram-config.service /lib/systemd/system/zram-config.service

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV XDG_CONFIG_HOME="/config/xdg"

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

# This cleanup works, as we'll be copying the complete filesystem later, therefore omitting any files that would still exist in an underlying layer.
# delete obsolete packages and any temporary state
RUN apt-get -qq autoremove -y > /dev/null 2>&1 && apt-get -qq clean > /dev/null 2>&1  && \
    rm -rf \
    /tmp/* \
    /var/backups/* \
    /var/log/* \
    /var/run/* \
    /var/crash/* \
    /var/lib/apt/lists/* \
    /usr/share/keyrings/* \
    ~/.bash_history
