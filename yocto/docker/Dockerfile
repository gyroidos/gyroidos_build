FROM debian:stretch


# Essentials
RUN apt-get update && apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio python python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev xterm

# Image signing
RUN apt-get update && apt-get install -y python-protobuf python3-protobuf

# Qemu
RUN apt-get update && apt-get install -y qemu-kvm ovmf

# Bootable medium
RUN apt-get update && apt-get install -y util-linux btrfs-progs gdisk parted

RUN apt-get update && apt-get install -y screen locales ca-certificates gosu locales
RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

RUN apt-get update && apt-get install -y kmod procps curl

# trusted-connector build dependencies
# for new yarn based build of trusted-connector core compartment
RUN curl -sL https://deb.nodesource.com/setup_11.x | bash - \
	&& apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update \
	&& apt-get install -y vim openjdk-8-jdk-headless openjdk-8-jre-headless yarn

# optee python dependings
RUN apt-get update && apt-get install -y python-crypto python3-crypto

WORKDIR "/opt/ws-yocto/"

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

