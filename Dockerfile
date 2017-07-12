########################################################
# Dockerfile for Nougat build environment
#
# This docker is a debian 8 with all dependencies
# required to build trustme.
#
# Create image:
# docker build -t trustme-build .
#
# Run:
# $ docker run -ti \
#     -v ./src:/root/workspace \
#     trustme-build
#
# Inside the container, start the build:
# $ cd /root/workspace
# $ make ids-all
########################################################

FROM debian:8

ENV PASSWD_PKI=test1234
ENV PASSWD_USER_TOKEN=test

RUN test -n "$GIT_EMAIL" && test -n "$GIT_NAME"

# Build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential libc6-dev git-core gnupg flex bison gperf libsdl1.2-dev \
    	libesd0-dev libwxgtk3.0-dev squashfs-tools zip curl libncurses5-dev zlib1g-dev \
    	pngcrush schedtool libxml2 libxml2-utils xsltproc g++-multilib lib32z1-dev \
    	lib32ncurses5-dev lib32readline-gplv2-dev gcc-multilib ccache abootimg \
    	qemu-user-static parted qemu-user qemu-system texlive-latex-base re2c python-protobuf \
    	protobuf-compiler protobuf-c-compiler bc lzip qemu-user-static parted wget android-tools-fastboot less software-properties-common unzip \
	&& apt-get install -y openjdk-7-jdk \
	&& rm -rf /var/lib/apt/lists/*

# For nougat (7)
RUN echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install -y -t jessie-backports openjdk-8-jdk-headless openjdk-8-jre-headless

RUN mkdir ~/bin \
	&& wget -P ~/bin https://storage.googleapis.com/git-repo-downloads/repo \
	&& chmod a+x ~/bin/repo \
	&& export PATH=$PATH:~/bin


VOLUME /root/workspace

CMD git config --global user.email $GIT_EMAIL \
&& git config --global user.name $GIT_NAME \
&& cd /root/workspace \
&& echo "export TRUSTME_TEST_PASSWD_PKI=$PASSWD_PKI">/root/workspace/trustme/build/device_provisioning/test_passwd_env.bash \
&& echo "export TRUSTME_TEST_PASSWD_USER_TOKEN=$PASSWD_USER_TOKEN">>/root/workspace/trustme/build/device_provisioning/test_passwd_env.bash
