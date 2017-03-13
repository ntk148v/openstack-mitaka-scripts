#Installation OpenStack Mitaka - CentOS 7

##Introduction

- This installer was made to automate the tasks of creating a virtualization infrastructure based on OpenStack Mitaka release.
- Testing in CentOS 7 only.
- You can use this installer to make a single node All-In-One Openstack or a more complex design with a controller and multi computes.
- Core services:
	+ Keystone
	+ Nova
	+ Glance
	+ Neutron
	+ Swift (in test)
	+ Cinder (controller only)
	+ Horizon

##How to use

1. Read everything you can about **OpenStack** and its installation. [More details.](https://docs.openstack.org/mitaka/install-guide-rdo/)

2. Edit the installer main configuration file in `etc/main-config.rc`. Do step 1 carefully, and you can config this config easily.

3. After updating configuration file, clone this repository:

	```bash
	$ git clone https://github.com/ntk148v/openstack-mitaka-scripts.git
	$ cd openstack-mitaka-scripts/
	```

4. Grant execute permission to `main-installer.sh` file:

	```bash
	$ chmod +x main-installer.sh
	```

5. In controller node, run command with root user:

	```bash
	# ./main-installer.sh controller
	```

6. In compute node `compute1` (It depends on COMPUTE_NODES config in your `main-config.rc`.
   For e.x, COMPUTE_NODES="test-compute1 compute2", run `./main-installer.sh test-compute1`
   in the host that will be the first compute node.), run command with root user:

	```bash
	# ./main-installer.sh compute1
	```

	Repeat it in `compute2`.

