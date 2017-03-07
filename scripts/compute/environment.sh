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
	echo " ERROR:Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

configure_name_resolution()
{
	echo "### 1. Hostname config"
	if ! grep -q "$CONTROLLER_NODES_IP 	$CONTROLLER_NODES"  /etc/hosts;
	then
		echo "$CONTROLLER_NODES_IP 	$CONTROLLER_NODES" >> /etc/hosts
	fi
	#
	# String to array
	# 
	
	temp_array_1=($COMPUTE_NODES)
	temp_array_2=($COMPUTE_NODES_IP)

	len_1=${#temp_array_1[@]}
	len_2=${#temp_array_2[@]}

	#
	# Check config
	# 
	
	if [ $len_1 != $len_2 ]
	then
		echo ""
		echo "### ERROR: Wrong config COMPUTE_NODES and COMPUTE_NODES_IP"
		echo "### Same size"
		echo ""
		exit 1
	fi

	#
	# Append to /etc/hosts, skip if existed
	for i in ${!temp_array_1[@]};
	do
		if ! grep -q "${temp_array_1[$i]} 	${temp_array_2[$i]}"  /etc/hosts;
		then
			echo "${temp_array_1[$i]} 	${temp_array_2[$i]}" >> /etc/hosts
		fi
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
		echo "server $CONTROLLER_NODES iburst" >> /etc/chrony.conf
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
	date > /etc/openstack-control-script-config/enviroment-compute-installed
}

main