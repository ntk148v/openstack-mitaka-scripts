#!/bin/bash
# 
# Unattended installer for Openstack
# Kien Nguyen
# 
# Main Installer Script
# Version 1.0.0
# 01/03/2017
# 

# Sanitize language settings to avoid commands bailing out
# with "unsupported locale setting" errors.
unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL

# Make sure umask is sane
umask 022

# Keep track of the openstack-newton-scripts directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Not all distros have sbin in PATH for regular users.
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

enable_private_repos()
{
    if [[ $USE_PRIVATE_REPOS == "yes" ]]
    then
        # Backup repository configs.
        cd /etc/yum.repos.d
        for i in $(ls *.repo); do mv $i $i.orig; done
        cd $TOP_DIR
        echo ""
        echo "### ERROR: Use Your Private Repos"
        echo ""
        cp /etc/openstack-control-script-config/private.repo /etc/yum.repos.d/
        yum clean all -y
        yum update
        yum info subversion
    fi
}

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

    enable_private_repos

    sync
    sleep 5
    sync

    #
    # Check supper user
    #
    
    if [[ $(id -u) -ne 0 ]]
    then
        clear
        echo "### ERROR: User is not permission. Please use root."
        exit 1
    fi

    #
    # Check main-config.rc file
    # 
    
    if [[ -f $TOP_DIR/etc/main-config.rc ]]
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
        echo "### ERROR:I can't access my own configuration"
        echo "### Please check you are executing the installer in its correct directory"
        echo "### Aborting !!!!."
        echo ""
        exit 1
    fi

    NODE_TYPE=$1

    case $NODE_TYPE in
    controller*|Controller*|CONTROLLER*)
        if [[ -z $CONTROLLER_NODES_IP ]]
        then
            echo ""
            echo "### ERROR: Please config your controller nodes's ip address"
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
            # Install requirement ENVIRONMENTs
            # - NTP serivce
            # - SQL database
            # - Memcached
            # 
            $TOP_DIR/scripts/controller/environment.sh
            if [[ -f /etc/openstack-control-script-config/environment-installed ]]
            then
                echo ""
                echo "### OPENSTACK ENVIRONMENT INSTALLED"
                echo ""
            else
                echo ""
                echo "###  ERROR:OPENSTACK ENVIRONMENT INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
            # 
            # Install Keystone service
            # 
            
            if [[ $INSTALL_KEYSTONE == "yes" ]]
            then
                $TOP_DIR/scripts/controller/install_keystone.sh
                if [[ -f /etc/openstack-control-script-config/keystone-installed ]]
                then
                    echo ""
                    echo "### OPENSTACK KEYSTONE INSTALLED"
                    echo ""
                else
                    echo ""
                    echo "### ERROR: OPENSTACK KEYSTONE INSTALLATION FAILED. ABORTING !!"
                    echo ""
                    exit 0
                fi
            fi
            
            #
            # Install Glance service
            #
            
            if [[ $INSTALL_GLANCE == "yes" ]]
            then
                $TOP_DIR/scripts/controller/install_glance.sh
                if [[ -f /etc/openstack-control-script-config/glance-installed ]]
                then
                    echo ""
                    echo "### OPENSTACK GLANCE INSTALLED"
                    echo ""
                else
                    echo ""
                    echo "### ERROR: OPENSTACK GLANCE INSTALLATION FAILED. ABORTING !!"
                    echo ""
                    exit 0
                fi
            fi
            
            #
            # Install Nova service
            # 
            

            if [[ $INSTALL_NOVA == "yes" ]]
            then
                $TOP_DIR/scripts/controller/install_nova.sh
                if [[ -f /etc/openstack-control-script-config/nova-installed ]]
                then
                    echo ""
                    echo "### OPENSTACK NOVA INSTALLED"
                    echo ""
                else
                    echo ""
                    echo "### ERROR: OPENSTACK NOVA INSTALLATION FAILED. ABORTING !!"
                    echo ""
                    exit 0
                fi
            fi

            #
            # Install Neutron service
            # 
            
            if [[ $INSTALL_NEUTRON == "yes" ]]
            then
                case $ML2_PLUGIN in
                openvswitch)
                    #
                    # Install Neutron service with OpenVSwitch
                    #
                    $TOP_DIR/scripts/controller/install_neutron_openvswitch.sh

                    if [[ -f /etc/openstack-control-script-config/neutron-openvswitch-installed ]]
                    then
                        echo ""
                        echo "### OPENSTACK NEUTRON INSTALLED"
                        echo ""
                    else
                        echo ""
                        echo "### ERROR: OPENSTACK NEUTRON INSTALLATION FAILED. ABORTING !!"
                        echo ""
                        exit 0
                    fi
                    ;;
                linuxbridge)
                    #
                    # Install Neutron service with LinuxBridge
                    #
                    $TOP_DIR/scripts/controller/install_neutron_linuxbridge.sh
                    if [[ -f /etc/openstack-control-script-config/neutron-linuxbridge-installed ]]
                    then
                        echo ""
                        echo "### OPENSTACK NEUTRON INSTALLED"
                        echo ""
                    else
                        echo ""
                        echo "### ERROR: OPENSTACK NEUTRON INSTALLATION FAILED. ABORTING !!"
                        echo ""
                        exit 0
                    fi
                    ;;
                *)
                    echo ""
                    echo "###  ERROR:Wrong ML2_PLUGIN variable, config this variable with 'openvswitch'"
                    echo "### or 'linuxbridge'"
                    echo ""
                    exit 1
                    ;;
                esac

                sync
                sleep 5
                sync
            fi

            #
            # Install Horizon service
            #
            
            if [[ $INSTALL_HORIZON == "yes" ]]
            then
                $TOP_DIR/scripts/controller/install_horizon.sh
                if [[ -f /etc/openstack-control-script-config/horizon-installed ]]
                then
                    echo ""
                    echo "### OPENSTACK HORIZON INSTALLED"
                    echo ""
                else
                    echo ""
                    echo "### ERROR: OPENSTACK HORIZON INSTALLATION FAILED. ABORTING !!"
                    echo ""
                    exit 0
                fi
            fi

            #
            # Install Cinder service
            #
            
            if [[ $INSTALL_CINDER == "yes" ]]
            then
                $TOP_DIR/scripts/controller/install_cinder.sh
                if [[ -f /etc/openstack-control-script-config/cinder-installed ]]
                then
                    echo ""
                    echo "### OPENSTACK CINDER INSTALLED"
                    echo ""
                else
                    echo ""
                    echo "### ERROR: OPENSTACK CINDER INSTALLATION FAILED. ABORTING !!"
                    echo ""
                    exit 0
                fi
            fi
        fi
        ;;

    compute*|Compute*|COMPUTE*)
        
        #
        # Install Compute Nodes
        #
         
        if [[ -z $COMPUTE_NODES_IP ]] && [[$COMPUTE_NODES == *$NODE_TYPE* ]]
        then
            echo ""
            echo "### You don't setup any compute nodes."
            echo "### It'll be All-in-one architecture."
            echo ""
        else
            echo ""
            echo "### INSTALL COMPUTE NODES - $NODE_TYPE"
            echo ""
            sync
            sleep 5
            sync

            #
            # Install requirement environments.
            # - NTP service.
            #
            
            $TOP_DIR/scripts/compute/environment.sh
            if [[  -f /etc/openstack-control-script-config/environment-compute-installed  ]]
            then
                echo ""
                echo "### OPENSTACK ENVIRONMENT COMPUTE $NODE_TYPE INSTALLED"
                echo ""
            else
                echo ""
                echo "### ERROR: OPENSTACK ENVIRONMENT COMPUTE $NODE_TYPE INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi

            #
            # Install Nova service
            # 
            
            $TOP_DIR/scripts/compute/install_nova.sh $NODE_TYPE
            if [[ -f /etc/openstack-control-script-config/nova-$NODE_TYPE-installed ]]
            then
                echo ""
                echo "### OPENSTACK NOVA COMPUTE $NODE_TYPE INSTALLED"
                echo ""
            else
                echo ""
                echo "### ERROR: OPENSTACK NOVA COMPUTE $NODE_TYPE INSTALLATION FAILED. ABORTING !!"
                echo ""
                exit 0
            fi
            
            #
            # Install Neutron service
            # 
            
            if [[ $INSTALL_NEUTRON == "yes" ]]
            then
                case $ML2_PLUGIN in
                openvswitch)
                    #
                    # Install Neutron service with OpenVSwitch
                    #
                    $TOP_DIR/scripts/compute/install_neutron_openvswitch.sh $NODE_TYPE

                    if [[ -f /etc/openstack-control-script-config/neutron-openvswitch-$NODE_TYPE-installed ]]
                    then
                        echo ""
                        echo "### OPENSTACK NEUTRON $NODE_TYPE INSTALLED"
                        echo ""
                    else
                        echo ""
                        echo "### ERROR: OPENSTACK NEUTRON $NODE_TYPE INSTALLATION FAILED. ABORTING !!"
                        echo ""
                        exit 0
                    fi
                    ;;
                linuxbridge)
                    #
                    # Install Neutron service with LinuxBridge
                    #
                    $TOP_DIR/scripts/compute/install_neutron_linuxbridge.sh $NODE_TYPE
                    if [[ -f /etc/openstack-control-script-config/neutron-linuxbridge-$NODE_TYPE-installed ]]
                    then
                        echo ""
                        echo "### OPENSTACK NEUTRON $NODE_TYPE INSTALLED"
                        echo ""
                    else
                        echo ""
                        echo "### ERROR: OPENSTACK NEUTRON $NODE_TYPE INSTALLATION FAILED. ABORTING !!"
                        echo ""
                        exit 0
                    fi
                    ;;
                *)
                    echo ""
                    echo "###  ERROR:Wrong ML2_PLUGIN variable, config this variable with 'openvswitch'"
                    echo "### or 'linuxbridge'"
                    echo ""
                    exit 1
                    ;;
                esac

                sync
                sleep 5
                sync
            fi
        fi
        ;;
    *)
        echo ""
        echo "### Usage: ./main-installer.sh controller|compute1|compute2... "
        echo ""
        exit 0
        ;;
    esac

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

main $1
