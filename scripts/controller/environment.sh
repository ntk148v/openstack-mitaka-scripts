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

if [[ -f /etc/openstack-control-script-config/main-config.rc ]]
then
	source /etc/openstack-control-script-config/main-config.rc
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

if [[ -f /etc/openstack-control-script-config/environment-installed ]]
then
	echo "This module was installed. Exiting"
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
	
	if [[ $len_1 != $len_2 ]]
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
		if ! grep -q "${temp_array_2[$i]} 	${temp_array_1[$i]}"  /etc/hosts;
		then
			echo "${temp_array_2[$i]} 	${temp_array_1[$i]}" >> /etc/hosts
		fi
	done
	echo "### Configure name resolution is Done!"
}

install_configure_ntp()
{
	echo "### 2. Install ntp-chrony"
	yum install chrony wget -y
	if [[ $? -eq 0 ]]
	then
		sed -i '/server/d' /etc/chrony.conf
		echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
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
	echo "### 3. Enable the OpenStack repository"
	if [[ $USE_PRIVATE_REPOS == "no" ]]
	then
		yum -y install centos-release-openstack-mitaka
	fi
	yum -y update
	yum -y upgrade
	yum -y install python-openstackclient openstack-selinux crudini
}

install_configure_sql_database()
{
	echo "### 4. Install and configure MariaDB"
	yum -y install mariadb mariadb-server python2-PyMySQL
	if [[ $? -eq 0 ]]
	then
		touch /etc/my.cnf.d/openstack.cnf
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld bind-address $CONTROLLER_NODES_IP
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld default-storage-engine innodb
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld innodb_file_per_table
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld max_connections 4096
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld collation-server utf8_general_ci
		crudini --set /etc/my.cnf.d/openstack.cnf mysqld character-set-server utf8
		systemctl enable mariadb.service
		systemctl start mariadb.service
	 	/usr/bin/mysqladmin -u $MYSQLDB_ADMIN password $MYSQLDB_PASSWORD > /dev/null 2>&1
	 	rm /root/.my.cnf
	 	echo "[client]" > /root/.my.cnf
		echo "user=$MYSQLDB_ADMIN" >> /root/.my.cnf
		echo "password=$MYSQLDB_PASSWORD" >> /root/.my.cnf
		echo "GRANT ALL PRIVILEGES ON *.* TO '$MYSQLDB_ADMIN'@'%' IDENTIFIED BY '$MYSQLDB_PASSWORD' WITH GRANT OPTION;"|mysql
		echo "FLUSH PRIVILEGES;"|mysql
	 	# iptables -A INPUT -p tcp -m multiport --dports $MYSQLDB_PORTL -j ACCEPT
		# service iptables save
	else
		clear
		echo '### Error: install MariaDB'
	fi
}

install_rabbitmq()
{
	echo "### 5. Install and create user with RabbitMQ"
	yum -y install rabbitmq-server
	if [[ $? -eq 0 ]]
	then
		systemctl enable rabbitmq-server.service
		systemctl start rabbitmq-server.service
		rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS
		rabbitmqctl set_permissions openstack ".*" ".*" ".*"
		echo "### Create user $RABBIT_USER with password: $RABBIT_PASS"
	else
		clear
		echo '### Error: install RabbitMQ'
	fi
}

install_memcaced()
{
	echo "### 6. Install and create user with memcached"
	yum -y install memcached python-memcached
	sed -i "s/127.0.0.1/$CONTROLLER_NODES_IP/g" /etc/sysconfig/memcached
	if [[ $? -eq 0 ]]
	then
		systemctl enable memcached.service
		systemctl start memcached.service
	else
		clear
		echo '### Error: install memcached'
	fi
}

main(){
	echo "### Install Environments"
	configure_name_resolution
	install_configure_ntp
	install_openstack_packages
	install_configure_sql_database
	install_rabbitmq
	install_memcaced
	date > /etc/openstack-control-script-config/environment-installed
}

main