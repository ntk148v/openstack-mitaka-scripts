#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Main Installer Script
# Version 1.0.0
# 01/03/2017
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

main()
{

    echo ""
    echo "######################################################################################"
    echo "OPENSTACK UNATTENDED INSTALLER"
    echo "Flavor: OpenStack NEWTON for Centos 7"
    echo "Made by: Kien Nguyen."
    echo "E-Mail: ntk148v@gmail.com"
    echo "Version 1.0.0 March 1, 2017"
    echo ""
    echo "I'll verify all requiremens"
    echo "If any requirement is not met, I'll stop and inform what's missing"
    echo ""
    echo "Requirements"
    echo "- OS: Centos 7 x86_64 fully updated"
    echo "- This script must be executed by root account (don't use sudo please)"
    echo "- Centos 7 original repositories must be enabled and available"
    echo "- Make sure you already setup etc/main-config.rc file"
    echo ""
    echo "NOTE: You can use the tee command if you want to log all installer actions. Example:"
    echo "./main-installer.sh | tee -a /var/log/my_install_log.log"
    echo "######################################################################################"
    echo ""

    sync
    sleep 5
    sync

    #
    # Check supper user
    #
    
    if [ $(id -u) -ne 0 ]
    then
        clear
        echo "### User is not permission. Please use root."
        exit 1
    fi

    #
    # Check main-config.rc file
    # 
    
    if [ -f etc/main-config.rc ]
    then
        mkdir -p /etc/openstack-control-script-config/
        cp etc/* /etc/openstack-control-script-config/
        source /etc/openstack-control-script-config/main-config.rc
        date > /etc/openstack-control-script-config/install-init-date-and-time
        chown -R root.root *
        find . -name "*" -type f -exec chmod 644 "{}" ";"
        find . -name "*.sh" -type f -exec chmod 755 "{}" ";"
    else
        echo ""
        echo "### I can't access my own configuration"
        echo "### Please check you are executing the installer in its correct directory"
        echo "### Aborting !!!!."
        echo ""
        exit 1
    fi

    if [[ -z $CONTROLLER_NODES ]]
    then
        echo ""
        echo "### Please config your controller nodes's ip address"
        echo ""
        exit 1
    else
        echo ""
        echo "### INSTALL CONTROLLER NODES"
        echo ""
        sync
        sleep 5
        sync

        #
        # Install requirement enviroments
        # - NTP serivce
        # - SQL database
        # - Memcached
        # 
        ./scripts/controller/enviroment.sh
        if [ -f /etc/openstack-control-script-config/enviroment-installed ]
        then
            echo ""
            echo "### OPENSTACK ENVIROMENT INSTALLED"
            echo ""
        else
            echo ""
            echo "### OPENSTACK ENVIROMENT INSTALLATION FAILED. ABORTING !!"
            echo ""
            exit 0
        fi
        # 
        # Install Keystone service
        # 
        
        if [ $INSTALL_KEYSTONE == "yes" ]
        then
            ./scripts/controller/install_keystone.sh
            if [ -f /etc/openstack-control-script-config/keystone-installed ]
            then
                echo ""
                echo "### OPENSTACK KEYSTONE INSTALLED"
                echo ""
            else
                echo ""
                echo "### OPENSTACK KEYSTONE INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
        fi
        
        #
        # Install Glance service
        #
        
        if [ $INSTALL_GLANCE == "yes" ]
        then
            ./scripts/controller/install_glance.sh
            if [ -f /etc/openstack-control-script-config/glance-installed ]
            then
                echo ""
                echo "### OPENSTACK GLANCE INSTALLED"
                echo ""
            else
                echo ""
                echo "### OPENSTACK GLANCE INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
        fi
        
        #
        # Install Nova service
        # 
        

        if [ $INSTALL_NOVA == "yes" ]
        then
            ./scripts/controller/install_nova.sh
            if [ -f /etc/openstack-control-script-config/nova-installed ]
            then
                echo ""
                echo "### OPENSTACK NOVA INSTALLED"
                echo ""
            else
                echo ""
                echo "### OPENSTACK NOVA INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
        fi

        #
        # Install Neutron service
        # 
        
        if [ $INSTALL_NOVA == "yes" ]
        then
            if [ $USE_OPENVSWITCH == "yes "]
            then
                #
                # Install Neutron service with OpenVSwitch
                #
                ./scripts/controller/install_neutron_openvswitch.sh
            else
                #
                # Install Neutron serivce with LinuxBridge
                # (TODO)
                # 
                echo ""
                echo "### Until now, this scripts doesn't support Neutron LinuxBridge."
                echo "### Please use OpenVSwitch instead."
                echo "### Thanks for using scripts. I will update it ASAP"
                echo ""
                sync
                sleep 5
                sync
                exit 0
            fi

            if [ -f /etc/openstack-control-script-config/neutron-installed ]
            then
                echo ""
                echo "### OPENSTACK NEUTRON INSTALLED"
                echo ""
            else
                echo ""
                echo "### OPENSTACK NEUTRON INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
        fi 



        #
        # Install Compute Nodes
        # 
        if [[ -z $COMPUTE_NODES ]]
        then
            echo ""
            echo "### You don't setup any compute nodes."
            echo "### It'll be All-in-one architecture."
            echo ""
        else
            echo ""
            echo "### INSTALL COMPUTE NODES"
            echo ""
            sync
            sleep 5
            sync
            #
            # Install requirement environments.
            # - NTP service.
            # 
            ./scripts/compute/environment.sh
            #
            # Install Nova service
            # 
            ./scripts/compute/install_nova.sh
            #
            # Install Neutron service
            # 
            ./scripts/compute/install_neutron_openvswitch.sh
        fi

        #
        # Install Horizon service
        #
        
        if [ $INSTALL_HORIZON == "yes" ]
        then
            ./scripts/controller/install_horizon.sh
            if [ -f /etc/openstack-control-script-config/horizon-installed ]
            then
                echo ""
                echo "### OPENSTACK HORIZON INSTALLED"
                echo ""
            else
                echo ""
                echo "### OPENSTACK HORIZON INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
        fi
    fi
    sync
    sleep 5
    sync
    echo ""
    echo "###################################################"
    echo "Thanks for using scripts."
    echo "OPENSTACK INSTALLATION FINISHED"
    echo "- Openstack Horizon Link: http://$NOVA_NOVNC_IP"
    echo "- User login Horizon: admin"
    echo "- Password user admin: $ADMIN_PASS"
    echo "- Password $MYSQLDB_ADMIN user Database MariaDB: $MYSQLDB_PASSWORD"
    echo "File Admin Script Openstack: $ADMIN_RC_FILE"
    echo "###################################################"
}

main