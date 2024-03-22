# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
FROM ubuntu:23.10

# Set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# Unminimize is needed such that the languages work properly within KDE. Doing this early is faster.
RUN yes | unminimize > /dev/null 2>&1

# Installing essential packages and fully upgrading the image.
RUN apt-get update -qq > /dev/null 2>&1 && apt-get -qq -y full-upgrade > /dev/null 2>&1 && apt-get install -y -qq jq curl > /dev/null 2>&1

# Resolving the current stable kernel version via the metapackage "linux-image-generic" and installing it. Can be hardcoded if necessary.
RUN apt-get install -y -qq $(apt-cache depends linux-image-generic | grep -P 'Depends:\s+linux-image-\d|Depends:\s+linux-modules-extra-' | cut -d ':' -f2 | tr -d "<> ") > /dev/null 2>&1

# Installing all linux firmware to check image size.
RUN apt-get install -y -qq linux-firmware > /dev/null 2>&1

# Installing necessary packages for our base image.
RUN apt-get install -y -qq software-properties-common gnupg2 apt-utils wget ntp sudo vim syslog-ng earlyoom iputils-ping dnsutils traceroute ca-certificates conky openssh-server libxss1 zram-config > /dev/null 2>&1

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

# Add auto-enable of middle-mouse-clicks for generic devices.
COPY ./scrolling/mouse_scrolling.desktop /etc/skel/.config/autostart/mouse_scrolling.desktop
COPY ./scrolling/middle_click_to_scroll.sh /usr/local/share/scripts/middle_click_to_scroll.sh

# Add hostname renaming service including systemd configuration.
COPY ./hostname/hostname-changer.sh /usr/local/share/scripts/hostname-changer.sh
COPY ./hostname/hostname-changer.service /etc/systemd/system/hostname-changer.service
RUN mkdir -p /etc/systemd/system/network.target.wants/ && \
    ln -s /etc/systemd/system/hostname-changer.service /etc/systemd/system/network.target.wants/hostname-changer.service

# Set sddm as display manager and install Plasma / Wayland as desktop environment & Disable x11 in sddm, use wayland instead
RUN /bin/bash -c "debconf-set-selections <<< 'sddm shared/default-x-display-manager select sddm'" && \
    apt-get -qq install -y kde-plasma-desktop plasma-workspace-wayland plasma-nm dolphin print-manager libglib2.0-dev locales kde-spectacle kcalc > /dev/null 2>&1 && \
    rm -f /usr/share/xsessions/plasma.desktop

# Install superimportant emojis & Uninstall packages we don't need
RUN apt-get update -qq > /dev/null 2>&1 && \
    apt-get install -y -qq fonts-noto-color-emoji > /dev/null 2>&1 && \
    apt-get remove -y -qq --purge kdeconnect partitionmanager xiterm+thai kaddressbook khelpcenter kmail kopete kwalletmanager korganizer okular sweeper dragonplayer juk pim-sieve-editor kwalletmanager gwenview imagemagick akregator konqueror plasma-discover gnome-shell gdm3 gnupg2 apt-utils cracklib-runtime > /dev/null 2>&1

# Prevent wallet / Key manager popups
RUN rm -f /usr/share/dbus-1/services/org.kde.kwalletd5.service

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
    /var/lib/apt/lists/* \
    /usr/share/keyrings/* \
    ~/.bash_history
