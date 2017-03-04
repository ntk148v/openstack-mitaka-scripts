#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Install Keystone script
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

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "### This module was already completed. Exiting !"
	echo ""
	exit 0
fi

create_database()
{
	MYSQL_COMMAND="mysql --port=$MYSQLDB_PORT --password=$MYSQLDB_PASSWORD --user=$MYSQLDB_ADMIN --host=controller"
	echo "### 1. Creating Keystone database"
	echo "CREATE DATABASE $KEYSTONE_DBNAME;"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $KEYSTONE_DBNAME.* TO '$KEYSTONE_DBUSER'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';"|$MYSQL_COMMAND
	echo "GRANT ALL PRIVILEGES ON $KEYSTONE_DBNAME.* TO '$KEYSTONE_DBUSER'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';"|$MYSQL_COMMAND
	echo "FLUSH PRIVILEGES;"|$MYSQL_COMMAND
	sync
	sleep 5
	sync
}

install_keystone()
{
	echo "### 2. Install Keystone packages"
	#
	# We proceed to install keystone packages and it's dependencies
	#
	yum -y install openstack-keystone httpd mod_wsgi openstack-utils
	if [ $? -eq 0 ]
	then
		echo "### Install Keystone is Done"
	else
		clear
		echo '### Error: install memcached'
	fi
}

configure_keystone()
{
	echo "### 3. Configure Keystone"
	crudini --set /etc/keystone/keystone.conf DEFAULT admin_token $TOKEN_PASS
	crudini --set /etc/keystone/keystone.conf DEFAULT connection mysql+pymysql://$KEYSTONE_DBUSER:$KEYSTONE_DBPASS@controller/$KEYSTONE_DBNAME
	crudini --set /etc/keystone/keystone.conf token provider fernet
	su -s /bin/sh -c "keystone-manage db_sync" $KEYSTONE_DBNAME
	keystone-manage fernet_setup --keystone-user $KEYSTONE_USER --keystone-group keystone
	echo "### Configure Keystone is Done"
}

configure_http()
{
	echo "### 4. Configure HTTPD Server"
	sed -i -e 's/.*ServerName.*/ServerName controller/g' /etc/httpd/conf/httpd.conf
	rm /etc/httpd/conf.d/wsgi-keystone.conf
	cp /etc/openstack-control-script-config/wsgi-keystone.conf /etc/httpd/conf.d/
	systemctl enable httpd.service
	systemctl start httpd.service
	echo "### Configure HTTPD is Done"
}

create_service_entity_api_enpoints_user_role_domain()
{
	echo "### 5. Create the service entity and API endpoints"
	export OS_TOKEN=$ADMIN_TOKEN
	export OS_URL="http://controller:35357/v3"
	export OS_IDENTITY_VERSION=3
	while true
	do
		openstack service create --name \
			$KEYSTONE_SERVICE --description "OpenStack Identity" identity
		if [ $? -eq 0 ]
		then
			break
		else
			sleep 5
		fi
	done
	# Create endpoint
	echo "- Create Endpoints"
	openstack endpoint create --region RegionOne \
		identity public "http://controller:5000/v3"
	openstack endpoint create --region RegionOne \
		identity internal "http://controller:5000/v3"
	openstack endpoint create --region RegionOne \
		identity admin "http://controller:35357/v3"
	# Create domain
	echo "- Create Domain"
	openstack domain create --description "Default Domain" default
	# Create project, user and role
	echo "- Create Projects, Users"
	openstack project create --domain default \
		--description "Admin Project" admin
	openstack user create admin --domain default \
		--password $ADMIN_PASS
	openstack role create admin
	openstack role add --project admin --user admin admin
	openstack project create --domain default \
		--description "Service Project" service
	openstack project create --domain default \
		--description "Demo Project" demo
	openstack user create demo --domain default \
    	--password $DEMO_PASS
    openstack role create user
    openstack role add --project demo --user demo user
    echo "Create Openstack client env scripts"
    # Create OpenStack client environment scripts
cat > $ADMIN_RC_FILE <<eof
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
eof
	chmod +x $ADMIN_RC_FILE
cat > $DEMO_RC_FILE <<eof
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://$controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
eof
	chmod +x $DEMO_RC_FILE

	unset OS_TOKEN OS_URL OS_IDENTITY_API_VERSION
	source $ADMIN_RC_FILE
	openstack token issue
	source $DEMO_RC_FILE
	openstack token issue
}

verify_keystone()
{
	echo ""
	echo "### Keystone Proccess DONE"
	echo ""
	echo ""
	echo "### 6. Verify Keystone installation"
	echo ""
	echo "Complete list following bellow:"
	echo ""
	echo "- Projects:"
	openstack project list
	sleep 5
	echo "- Users:"
	openstack user list
	sleep 5
	echo "- Services:"
	openstack service list
	sleep 5
	echo "- Roles:"
	openstack role list
	sleep 5
	echo "- Endpoints:"
	openstack endpoint list
	sleep 5
	echo ""
	echo "### Applying IPTABLES rules"
	echo ""
	iptables -A INPUT -p tcp -m multiport --dports 5000,11211,35357 -j ACCEPT
	service iptables save
}

main()
{
	echo "INSTALL_KEYSTONE = $INSTALL_KEYSTONE"
	if [ $INSTALL_KEYSTONE == "yes" ]
	then
		create_database
		install_keystone
		configure_keystone
		configure_http
		create_service_entity_api_enpoints_user_role_domain
		date > /etc/openstack-control-script-config/keystone-installed
		verify_keystone
	else
		exit 0
	fi
}

main