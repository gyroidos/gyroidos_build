#!/bin/bash
# $1: workspace directory

if [ ! "$1" ]; then
	echo "Wrong usage: provide ws-yocto build directory as parameter"
	exit
fi

EXTRA_ARGS=""

if [ "$2" ];then
	echo "Mapping ssh-agent to container"
	EXTRA_ARGS="--volume $2:/tmp/sshagent --env=SSH_AUTH_SOCK=/tmp/sshagent"
fi

docker run \
 -it \
${EXTRA_ARGS} \
 -e LOCAL_USER_ID=`id -u $USER` \
 -v "$1"/:/opt/ws-yocto/ \
 trustx-builder \
 bash
