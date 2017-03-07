#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Install nova script
# Version 1.0.0
# 01/03/2017
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [[ -f /etc/openstack-control-script-config/main-config.rc ]]
then
	source /etc/openstack-control-script-config/main-config.rc
else
	echo "### ERROR: Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

if [[ -f /etc/openstack-control-script-config/nova-installed ]]
then
	echo ""
	echo "### This module was already completed. Exiting !"
	echo ""
	exit 0
fi

create_database()
{
	MYSQL_COMMAND="mysql --port=$MYSQLDB_PORT --password=$MYSQLDB_PASSWORD --user=$MYSQLDB_ADMIN --host=$CONTROLLER_NODES"
	echo "### 1. Creating Nova database"
	echo "CREATE DATABASE $NOVA_DBNAME;"|$MYSQL_COMMAND
	echo "CREATE DATABASE $NOVAAPI_DBNAME;"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NOVAAPI_DBNAME.* TO '$NOVA_DBUSER'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NOVA_DBNAME.* TO '$NOVA_DBUSER'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NOVA_DBNAME.* TO '$NOVA_DBUSER'@'%' IDENTIFIED BY '$NOVA_DBPASS';"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $NOVAAPI_DBNAME.* TO '$NOVA_DBUSER'@'%' IDENTIFIED BY '$NOVA_DBPASS';"|$MYSQL_COMMAND
	echo "FLUSH PRIVILEGES;"|$MYSQL_COMMAND
	sync
	sleep 5
	sync
}

create_nova_identity()
{
	source /etc/openstack-control-script-config/$ADMIN_RC_FILE
	echo "### 2. Create Nova user, service and endpoint"
	if [[ -f /etc/openstack-control-script-config/keystone-extra-idents-nova ]]
	then
		echo ""
		echo "### Nova Identity was Done. Pass!"
		echo ""
	else
		echo "- Nova User"
		openstack user create $NOVA_USER --domain default \
			--password $NOVA_PASS
		openstack role add --project service --user $NOVA_USER admin
		echo "- Nova Service"
		openstack service create --name $NOVA_SERVICE \
			--description "OpenStack Compute" compute
		echo "- Nova Endpoints"
		openstack endpoint create --region RegionOne \
			compute public http://$CONTROLLER_NODES:8774/v2.1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne \
			compute internal http://$CONTROLLER_NODES:8774/v2.1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne \
			compute admin http://$CONTROLLER_NODES:8774/v2.1/%\(tenant_id\)s
	 	date > /etc/openstack-control-script-config/keystone-extra-idents-nova
	 	echo ""
		echo "### Nova Identity is Done"
		echo ""
	fi
}

install_configure_nova()
{
	echo ""
	echo "### 3. Install Nova Packages and Configure Nova configs"
	echo ""
	yum -y install openstack-nova-api openstack-nova-conductor \
		openstack-nova-console openstack-nova-novncproxy \
		openstack-nova-scheduler openstack-nova-compute
	#
	# Using crudini we proceed to configure nova service
	#
	
	#
	# Keystone NOVA Configuration
	#

	crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_NODES:5000
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://$CONTROLLER_NODES:35357
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
	crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
	crudini --set /etc/nova/nova.conf keystone_authtoken username $NOVA_USER
	crudini --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PASS
	crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers $CONTROLLER_NODES:11211

	crudini --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
	crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
	crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
	crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
	crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
	crudini --set /etc/nova/nova.conf DEFAULT my_ip $CONTROLLER_NODES_IP

	#
	# Libvirt Configuration
	# 
	kvm_possible=`egrep -c '(vmx|svm)' /proc/cpuinfo`
	if [[ $kvm_possible == "0" ]]
	then
		echo ""
		echo "### WARNING !. This server does not support KVM"
		echo "### We will have to use QEMU instead of KVM"
		echo "### Performance will be poor"
		echo ""
		source /etc/openstack-control-script-config/$ADMIN_RC_FILE
		crudini --set /etc/nova/nova.conf libvirt virt_type qemu
		setsebool -P virt_use_execmem on
		ln -s -f /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
		service libvirtd restart
	else
		crudini --set /etc/nova/nova.conf libvirt virt_type $VIRT_TYPE
	fi

	crudini --set /etc/nova/nova.conf DEFAULT ram_allocation_ratio $RAM_ALLOCATION_RATIO
	crudini --set /etc/nova/nova.conf DEFAULT cpu_allocation_ratio $CPU_ALLOCATION_RATIO
	crudini --set /etc/nova/nova.conf DEFAULT disk_allocation_ratio $DISK_ALLOCATION_RATIO

	#
	# Database Configuration
	# 
	crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://$NOVA_DBUSER:$NOVA_DBPASS@$CONTROLLER_NODES/$NOVAAPI_DBNAME
	crudini --set /etc/nova/nova.conf database connection mysql+pymysql://$NOVA_DBUSER:$NOVA_DBPASS@$CONTROLLER_NODES/$NOVA_DBNAME

	#
	# Rabbit Configuration
	# 
	crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $CONTROLLER_NODES
	crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
	crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS

	#
	# VNC Configuration
	# 
	crudini --set /etc/nova/nova.conf vnc enabled True
	crudini --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
	crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $my_ip
	crudini --set /etc/nova/nova.conf vnc novncproxy_base_url = http://$CONTROLLER_NODES:6080/vnc_auto.html

	crudini --set /etc/nova/nova.conf glance api_servers http://$CONTROLLER_NODES:9292
	crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

	sync
	sleep 5
	sync

	echo ""
	echo "### 4. Populate the Compute databases"
	echo ""
	su -s /bin/sh -c "nova-manage api_db sync" $NOVA_DBUSER
	if [[ $check -gt 2 ]]
	then
		echo ""
		echo "### Import Database Nova: OK"
		echo ""
	else
		echo ""
		echo "### Error: Import Database Nova API"
		echo ""
	fi
	clear

	su -s /bin/sh -c "nova-manage db sync" $NOVA_DBUSER
	if [[ $check -gt 2 ]]
	then
		echo ""
		echo "### Import Database Nova: OK"
		echo ""
	else
		echo ""
		echo "### Error: Import Database Nova"
		echo ""
	fi
	clear

	sync
	sleep 5
	sync
	systemctl enable openstack-nova-api.service \
  		openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  		openstack-nova-conductor.service openstack-nova-novncproxy.service \
  		libvirtd.service openstack-nova-compute.service
	systemctl start openstack-nova-api.service \
		openstack-nova-consoleauth.service openstack-nova-scheduler.service \
		openstack-nova-conductor.service openstack-nova-novncproxy.service \
		libvirtd.service openstack-nova-compute.service
	echo ""
	echo "### Nova Installed and Configured"
	echo ""
	sync
	sleep 5
	sync
}

verify_nova()
{
	echo ""
	echo "### 5. Verify Nova Installation"
	echo ""
	source /etc/openstack-control-script-config/$ADMIN_RC_FILE
	echo ""
	echo "- List service components to verify successful launch and registration of each process"
	echo ""
	openstack compute service list
}

main()
{
	echo "### INSTALL_NOVA = $INSTALL_NOVA"
	create_database
	create_nova_identity
	install_configure_nova
	verify_nova
	date > /etc/openstack-control-script-config/nova-installed
}

main
