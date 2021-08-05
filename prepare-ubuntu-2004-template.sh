#!/bin/bash
################################################################################
# Prepare Ubuntu 20.04 Template                                                #
#                                                                              #
# Script used for cleaning and configuring an Ubuntu 20.04 virtual machine for #
# use as a VMware VM Template. Adapted from  jcppkkk/prepare-ubuntu-server and #
# jimangel/ubuntu-18.04-scripts                                                #
#                                                                              #
################################################################################

trap 'echo "Error: Script ${BASH_SOURCE[0]} Line $LINENO"' ERR
set -o errtrace # If set, the ERR trap is inherited by shell functions.
set -e

# Verify running as root
if [[ $(id -u) != 0 ]]; then
    echo "Requires root privilege"
    exit 1
fi

set -v

# Update packages
apt update -y
apt upgrade -y

# Add VMware package keys
apt install -y open-vm-tools

# Clear audit logs
service rsyslog stop
if [ -f /var/log/audit/audit.log ]; then
    cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
    cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    cat /dev/null > /var/log/lastlog
fi

# Cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm /etc/udev/rules.d/70-persistent-net.rules
fi

# Cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

# Cleanup current ssh keys
service ssh stop
rm -f /etc/ssh/ssh_host_*

# Check for ssh keys on reboot...regenerate if neccessary
cat <<EOL | sudo tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL
chmod u+x /etc/rc.local

# Reset hostname
sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
truncate -s0 /etc/hostname
hostnamectl set-hostname localhost

# Cleanup apt
apt clean

# Set DHCP by MAC Address
sed -i 's/optional: true/dhcp-identifier: mac/g' /etc/netplan/00-installer-config.yaml

# Cleanup cloud-init
cloud-init clean --logs

# Cleanup shell history
at /dev/null > ~/.bash_history && history -c
history -w

# Shutdown
shutdown -h now