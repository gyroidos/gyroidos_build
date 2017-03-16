########################################################
# Dockerfile for Nougat build environment
# 
# This docker is a debian 8 with all dependencies 
# required to build trustme.
#
# Create image:
# docker build -t trustme-build .
#
# Run (and start initial build):
# docker run -ti \
#     -v ./src:/root/workspace \
#     -e "GIT_EMAIL=your_github_email@example.com" \
#     -e "GIT_NAME=your_github_account" \
#     -e "PASSWD_PKI=secret" \
#     -e "PASSWD_USER_TOKEN=token" \
#     trustme-build
########################################################

FROM debian:8

ARG GIT_EMAIL="you@example.com"
ARG GIT_NAME="Your Name"
ENV PASSWD_PKI=test1234
ENV PASSWD_USER_TOKEN=test

# Build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
		build-essential libc6-dev git-core gnupg flex bison gperf libsdl1.2-dev \
    	libesd0-dev libwxgtk3.0-dev squashfs-tools zip curl libncurses5-dev zlib1g-dev \
    	pngcrush schedtool libxml2 libxml2-utils xsltproc g++-multilib lib32z1-dev \
    	lib32ncurses5-dev lib32readline-gplv2-dev gcc-multilib ccache abootimg \
    	qemu-user-static parted qemu-user texlive-latex-base re2c python-protobuf \
    	protobuf-compiler protobuf-c-compiler bc lzip qemu-user-static parted wget android-tools-fastboot \
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
	&& /root/bin/repo init -u https://github.com/trustm3/trustme_main -m trustme-hammerhead.xml -b trustme-7.0.0_r6-github \
	&& /root/bin/repo sync \
	&& echo "export TRUSTME_TEST_PASSWD_PKI=$PASSWD_PKI">/root/workspace/trustme/build/device_provisioning/test_passwd_env.bash \
	&& echo "export TRUSTME_TEST_PASSWD_USER_TOKEN=$PASSWD_USER_TOKEN">>/root/workspace/trustme/build/device_provisioning/test_passwd_env.bash \
	&& make