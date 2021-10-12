# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
FROM anymodconrst001dg.azurecr.io/planetexpress/ubuntu-base:21.04

# Set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# Unminimize is needed such that the languages work properly within KDE. Doing this early is faster.
RUN yes | unminimize > /dev/null 2>&1

RUN apt-get -qq -y full-upgrade > /dev/null 2>&1
RUN apt-get -qq update && apt-get -qq install -y curl jq software-properties-common gnupg2 apt-utils wget > /dev/null 2>&1

# Add repository for Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'

# Install packages that we need
ARG NETBOOT_IP
RUN bash -c 'kernelVersion=$(curl -s http://$NETBOOT_IP/kernels/latest-kernel-version.json | jq -r .version); if [[ "$kernelVersion" == "" ]]; then kernelVersion="5.11.0-16-generic"; fi && \
apt-get -qq update && apt-get -qq install -y sudo vim syslog-ng zram-config earlyoom iputils-ping dnsutils traceroute ca-certificates google-chrome-stable firefox conky openssh-server libxss1 linux-modules-extra-$kernelVersion > /dev/null 2>&1'

# Disable pop up on first opening of chrome
RUN sed -i 's,Exec=/usr/bin/google-chrome-stable,Exec=/usr/bin/google-chrome-stable --no-first-run --no-default-browser-check,g' /usr/share/applications/google-chrome.desktop

# Setup default login
RUN useradd ubuntu -s /bin/bash -d /home/ubuntu -m -G sudo && echo ubuntu:ubuntu | chpasswd

RUN echo "session optional pam_mkhomedir.so umask=0077" >> /etc/pam.d/common-session
RUN echo "session optional pam_exec.so log=/var/log/pam-logout.log /usr/local/share/scripts/logout-old-user.sh" >> /etc/pam.d/common-session
#COPY ./authentication/common-session /etc/pam.d/common-session
COPY ./authentication/logout-old-user.sh /usr/local/share/scripts/logout-old-user.sh

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
RUN mkdir -p /etc/systemd/system/network.target.wants/
RUN ln -s /etc/systemd/system/hostname-changer.service /etc/systemd/system/network.target.wants/hostname-changer.service

# Set sddm as display manager and install Plasma as desktop environment
RUN /bin/bash -c "debconf-set-selections <<< 'sddm shared/default-x-display-manager select sddm'" && apt-get -qq update && apt-get -qq install -y kde-plasma-desktop plasma-nm dolphin print-manager libglib2.0-dev locales kde-spectacle > /dev/null 2>&1

# Uninstall packages we don't need
RUN apt-get -qq --purge remove -y kdeconnect partitionmanager xiterm+thai kaddressbook khelpcenter kmail kopete kwalletmanager korganizer okular sweeper dragonplayer juk pim-sieve-editor kwalletmanager gwenview imagemagick akregator konqueror plasma-discover gnome-shell gdm3 gnupg2 apt-utils cracklib-runtime > /dev/null 2>&1

# Prevent wallet / Key manager popups
RUN rm -f /usr/share/dbus-1/services/org.kde.kwalletd5.service

# Set the environment variable OS_RELEASE to identify the exact squashfs file booted. Can be visualized in Conky.
ARG OS_RELEASE
RUN echo "export dg_os_release=$OS_RELEASE" >> /etc/profile

# Initialise Network Manager
COPY ./network/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf
# This seems to be necessary for the network manager to recognize the default connection properly
RUN mkdir -p /etc/NetworkManager/conf.d/ && touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# This cleanup works, as we'll be copying the complete filesystem later, therefore omitting any files that would still exist in an underlying layer.
# delete obsolete packages and any temporary state
RUN apt-get -qq autoremove -y > /dev/null 2>&1 && apt-get -qq clean > /dev/null 2>&1
RUN rm -rf \
    /tmp/* \
    /boot/* \
    /var/backups/* \
    /var/log/* \
    /var/run/* \
    /var/crash/* \
    /var/lib/apt/lists/* \
    /usr/share/keyrings/* \
    ~/.bash_history

RUN mkdir -p /var/log/sssd
