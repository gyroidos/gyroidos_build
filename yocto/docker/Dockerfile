FROM debian:bullseye

RUN sed -i 's/main/main contrib/' /etc/apt/sources.list

# Essentials
RUN apt-get update && apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev xterm lsb-release libprotobuf-c1 libprotobuf-c-dev protobuf-compiler protobuf-c-compiler autoconf libtool libtool-bin re2c check zstd liblz4-tool

# HSM communication
RUN apt install libpcsclite1

# CI
RUN apt-get install -y libssl-dev libcap-dev libselinux-dev apt-transport-https
#
# clang toolchain for debian bullseye
RUN echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-17 main" >> /etc/apt/sources.list
RUN echo "deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-17 main" >> /etc/apt/sources.list
RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
RUN apt-get update && apt-get install -y clang-17 clang-tools-17 clang-17-doc libclang-common-17-dev libclang-17-dev libclang1-17 clang-format-17 python3-clang-17 clangd-17 clang-tidy-17 lld-17 lldb-17 libfuzzer-17-dev
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-17 100
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 100
RUN update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-17 100
RUN update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-17 100
#
# protobuf-c-text library
# https://github.com/protobuf-c/protobuf-c-text
RUN cd /opt && git clone https://github.com/gyroidos/external_protobuf-c-text.git && cd /opt/external_protobuf-c-text && ./autogen.sh
RUN cd /opt/external_protobuf-c-text && ./configure && make && make install

# Image signing
RUN apt-get update && apt-get install -y python3-protobuf

# Qemu
RUN apt-get install -y qemu-kvm ovmf

# Bootable medium
RUN apt-get install -y util-linux btrfs-progs gdisk parted

RUN apt-get install -y screen locales ca-certificates gosu locales

RUN apt-get -y install repo

RUN apt-get install -y libssl-dev libtar-dev screen locales ca-certificates gosu locales

RUN dpkg-reconfigure locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

RUN apt-get update && apt-get install -y kmod procps curl

# trusted-connector build dependencies
# for new yarn based build of trusted-connector core compartment
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - \
	&& apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update \
	&& apt-get install -y vim openjdk-17-jdk-headless openjdk-17-jre-headless yarn

# optee python dependings
RUN apt-get update && apt-get install -y python3-cryptography

RUN apt install -y gnutls-bin opensc-pkcs11

RUN mkdir -p /home/builder && echo '[user]\n\
	name = "builder"\n\
	email = "builder@builder.com"\n' > /home/builder/.gitconfig

ARG BUILDUSER=9001
RUN if ! [ -z "${BUILDUSER}" ];then echo "Preparing container home directory for user ${BUILDUSER}" && chown -R ${BUILDUSER}:${BUILDUSER} /home/builder && useradd --shell /bin/bash -u ${BUILDUSER} -o -c "" -m builder ;fi

WORKDIR "/opt/ws-yocto/"
