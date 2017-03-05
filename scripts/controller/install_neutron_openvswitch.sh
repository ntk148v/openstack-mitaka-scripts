#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Install neutron script
# Version 1.0.0
# 01/03/2017
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

	crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
	crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
	crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
	
	crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

	#
	# Database configuration
	# 
	
	crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://$NEUTRON_DBUSER:$NEUTRON_DBPASS@controller/$NEUTRON_DBNAME

	#
	# Neutron Keystone Config
	#
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
	crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
	crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
	crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
	crudini --set /etc/neutron/neutron.conf keystone_authtoken username $NEUTRON_USER
	crudini --set /etc/neutron/neutron.conf keystone_authtoken password $NEUTRON_PASS

	crudini --del /etc/neutron/neutron.conf keystone_authtoken identity_uri
	crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name
	crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_user
	crudini --del /etc/neutron/neutron.conf keystone_authtoken admin_password
	
	#
	# Nova
	#

	crudini --set /etc/neutron/neutron.conf nova auth_url http://controller:35357
	crudini --set /etc/neutron/neutron.conf nova auth_type password
	crudini --set /etc/neutron/neutron.conf nova project_domain_name default
	crudini --set /etc/neutron/neutron.conf nova user_domain_name default
	crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
	crudini --set /etc/neutron/neutron.conf nova project_name service
	crudini --set /etc/neutron/neutron.conf nova username $NOVA_USER
	crudini --set /etc/neutron/neutron.conf nova password $NOVA_PASS

	#
	# Olso Messaging Rabbit
	#

	crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller
	crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
	crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS

	#
	# Neutron Nova
	#
	crudini --set /etc/nova/nova.conf neutron url http://controller:9696
	crudini --set /etc/nova/nova.conf neutron auth_url http://controller:35357
	crudini --set /etc/nova/nova.conf neutron auth_type password
	crudini --set /etc/nova/nova.conf neutron project_domain_name default
	crudini --set /etc/nova/nova.conf neutron user_domain_name default
	crudini --set /etc/nova/nova.conf neutron region_name RegionOne
	crudini --set /etc/nova/nova.conf neutron project_name service
	crudini --set /etc/nova/nova.conf neutron username $NEUTRON_USER
	crudini --set /etc/nova/nova.conf neutron password $NEUTRON_PASS
	crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
	crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET

	#
	# metadata agent configuration
	#
	
	crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller
	crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $METADATA_SECRET

	#
	# openvswitch agent configuration
	#

	crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings $BRIDGE_MAPPINGS
	# crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid
	crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver


	#
	# ml2 configuration
	#
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks $FLAT_NETWORKS
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges $NETWORK_VLAN_RANGES


	#
	# dhcp agent configuration
	#

	# crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver openvswitch
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT force_metadata True

	if [ $PROVIDER_NETWORK == "yes" ]
	then
		crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ""
		crudini --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 2

		#
		# ml2 configuration
		#

		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers "flat,vlan"
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types ""
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
		

	fi

	if [ $SELF_SERVICE_NETWORK == "yes" ]
	then
		crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers "local,flat,vlan,gre,vxlan"

		#
		# openvswitch agent configuration
		#

		# crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip OVERLAY_INTERFACE_IP_ADDRESS
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
		crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True

		#
		# l3 agent configuration
		#
		# crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver openvswitch
		crudini --set /etc/neutron/l3_agent.ini DEFAULT  neutron.agent.linux.interface.OVSInterfaceDriver
		crudini --set /etc/neutron/l3_agent.ini DEFAULT  external_network_bridge ""

		#
		# ml2 configuration
		
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 path_mtu 1500
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers "openvswitch,l2population"
		crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges $VNI_RANGES

	fi

	echo ""
	echo "### 4. Populate Neutron database."
	echo ""
	ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
 		--config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
  	if [ $check -gt 2 ]
	then
		echo ""
		echo "### Import Database Neutron: OK"
		echo ""
	else
		echo ""
		echo "### Error: Import Database Neutron"
		echo ""
	fi

	systemctl restart openvswitch

	ovs-vsctl add-br $PROVIDER_BRIDGE
	ovs-vsctl add-port $PROVIDER_BRIDGE $PROVIDER_INTERFACE

	systemctl enable neutron-server.service
	systemctl enable neutron-dhcp-agent.service
	systemctl enable neutron-metadata-agent.service
	systemctl enable neutron-openvswitch-agent.service
	systemctl enable openvswitch
	systemctl restart openstack-nova-api.service
	systemctl restart neutron-server.service
	systemctl restart neutron-dhcp-agent.service
	systemctl restart neutron-metadata-agent.service
	systemctl restart neutron-openvswitch-agent.service
	if [ $SELF_SERVICE_NETWORK == "yes" ]
	then
		systemctl enable neutron-l3-agent.service
		systemctl restart neutron-l3-agent.service
	fi

	cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-$PROVIDER_INTERFACE
OVS_BRIDGE=$PROVIDER_BRIDGE
TYPE="OVSPort"
DEVICETYPE="ovs"
EOF

	cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$PROVIDER_BRIDGE 
DEVICE="$PROVIDER_BRIDGE"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="OVSBridge"
DEVICETYPE="ovs"
EOF

  	sync
  	sleep 5
  	sync
}

verify_neutron()
{
	echo ""
	echo "### 5. Verify Neutron installation"
	echo ""
	source $ADMIN_RC_FILE
	echo "- Network agent list"
	openstack network agent list
	sync
	sleep 5
	sync
}

main()
{
	echo "### INSTALL_NEUTRON = $INSTALL_NEUTRON"
	create_database
	create_neutron_identity
	install_configure_neutron
	verify_neutron
	date > /etc/openstack-control-script-config/neutron-installed
}

main