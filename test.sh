#!/bin/bash

if [ $(id -u) -ne 0 ]
then
	clear
	echo "### User is not permission. Please use root."
	exit 1
fi
