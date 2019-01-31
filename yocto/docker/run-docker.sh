#!/bin/bash
# $1: workspace directory

if [ ! "$1" ]; then
	echo "Wrong usage: provide ws-yocto build directory as parameter"
	exit
fi

docker run \
 -it \
 -e LOCAL_USER_ID=`id -u $USER` \
 -v "$1"/:/opt/ws-yocto/ \
 trustx-builder \
 bash
