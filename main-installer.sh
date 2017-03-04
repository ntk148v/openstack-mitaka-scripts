#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Main Installer Script
# Version 1.0.0
# 10/03/2017
# 

set -o xtrace

# Sanitize language settings to avoid commands bailing out
# with "unsupported locale setting" errors.
unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL

# Make sure umask is sane
umask 022

# Not all distros have sbin in PATH for regular users.
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Set start time
START_TIME=$(date +%s)

mkdir -p /etc/openstack-control-script-config/
cp etc/* /etc/openstack-control-script-config/

#Check supper user
check_root()
{
	if [ $(id -u) -ne 0 ]
	then
		clear
		echo "### User is not permission. Please use root."
		exit 1
	fi
}