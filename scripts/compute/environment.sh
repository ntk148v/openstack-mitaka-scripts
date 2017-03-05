#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Environments config
# Version 1.0.0
# 01/03/2017
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f /etc/openstack-control-script-config/main-config.rc ]
then
	source /etc/openstack-control-script-config/main-config.rc
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

configure_name_resolution()
{
	echo "### 1. Hostname config"
	echo "$CONTROLLER_NODES 	controller" >> /etc/hosts
	count=1
	for COMPUTE_NODE in $COMPUTE_NODES
	do
		echo "$COMPUTE_NODE 	compute$count" >> /etc/hosts
		count=$((count+1))
	done
	echo "### Configure name resolution is Done!"
}


install_configure_ntp()
{
	echo "### 2. Install ntp-chrony"
	yum install chrony wget -y
	if [ $? -eq 0 ]
	then
		sed -i '/server/d' /etc/chrony.conf
		echo "server controller iburst" >> /etc/chrony.conf
		systemctl enable chronyd.service
		systemctl start chronyd.service
		chronyc sources
	else
		clear
		echo '### Error: install chrony'
	fi
}

install_openstack_packages()
{

	echo "### 3. Enable the OpenStack repository¶"
	yum -y install centos-release-openstack-mitaka
	yum -y update
	yum -y upgrade
	yum -y install python-openstackclient openstack-selinux crudini
}

main(){
	configure_name_resolution
	install_configure_ntp
	install_openstack_packages
}

main