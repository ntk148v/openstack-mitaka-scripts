#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Install neutron script
# Version 1.0.0
# 10/03/2017
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f /etc/openstack-control-script-config/main-config.rc ]
then
	source /etc/openstack-control-script-config/main-config.rc
else
	echo "### Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/neutron-installed ]
then
	echo ""
	echo "### This module was already completed. Exiting !"
	echo ""
	exit 0
fi

create_database()
{
	MYSQL_COMMAND="mysql --port=$MYSQLDB_PORT --password=$MYSQLDB_PASSWORD --user=$MYSQLDB_ADMIN --host=controller"
	echo "### 1. Creating neutron database"
	echo "CREATE DATABASE $NEUTRON_DBNAME;"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NEUTRON_DBNAME.* TO '$NEUTRON_DBUSER'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NEUTRON_DBNAME.* TO '$NEUTRON_DBUSER'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';"|$MYSQL_COMMAND
	echo "FLUSH PRIVILEGES;"|$MYSQL_COMMAND
	sync
	sleep 5
	sync
}

create_neutron_identity()
{
	source $ADMIN_RC_FILE
	echo "### 2. Create neutron user, service and endpoint"
	if [ -f date > /etc/openstack-control-script-config/keystone-extra-idents-neutron ]
	then
		echo ""
		echo "### Neutron Identity was Done. Pass!"
		echo ""
	else
		echo "- Neutron User"
		openstack user create $NEUTRON_USER --domain default \
			--password $NEUTRON_PASS
		openstack role add --project service --user $NEUTRON_USER admin
		echo "- Neutron Service"
		openstack service create --name $NEUTRON_SERVICE \
			--description "OpenStack Network" network
		echo "- Neutron Endpoints"
		openstack endpoint create --region RegionOne \
			network public http://controller:9696
		openstack endpoint create --region RegionOne \
			network internal http://controller:9696
		openstack endpoint create --region RegionOne \
			network admin http://controller:9696
	 	date > /etc/openstack-control-script-config/keystone-extra-idents-neutron
	 	echo ""
		echo "### Neutron Identity is Done"
		echo ""
		sync
		sleep 5
		sync
	fi
}

install_configure_neutron()
{
	echo ""
	echo "### 3. Install Neutron Packages and Configure Neutron configs"
	echo ""
	yum install -y openstack-neutron \
		openstack-neutron-openvswitch \
		openstack-neutron-ml2 \
		python-neutron \
		python-neutronclient \
		ebtables

	cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.tcp_keepalive_time = 6
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF
sysctl -p

}