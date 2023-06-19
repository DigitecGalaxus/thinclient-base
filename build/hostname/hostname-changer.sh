#!/bin/bash
set -e
# Extracting the last 6 digits from the MAC-adress of the first (head -1) (e*)thernet interface.
macEnd=$(cat /sys/class/net/e*/address | sed 's/://g' | head -1)
newHostname=tc-$macEnd
echo "Setting hostname to $newHostname."
sed -i "s/ubuntu/$newHostname/g" /etc/hosts
sed -i "s/ubuntu/$newHostname/g" /etc/hostname
hostnamectl set-hostname $newHostname
