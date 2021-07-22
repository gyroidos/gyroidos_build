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
-u "$(id -u $USER)" \
 -v "$1"/:/opt/ws-yocto/ \
 -v /home/$(id -un)/.ssh/known_hosts:/home/builder/.ssh/known_hosts \
 --env=LANG=en_US.UTF-8 \
 --env=LANGUAGE=en_US.UTF-8 \
 trustx-builder \
 bash
