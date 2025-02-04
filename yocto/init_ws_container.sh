#!/bin/bash
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2020 Fraunhofer AISEC
# Fraunhofer-Gesellschaft zur Förderung der angewandten Forschung e.V.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2 (GPL 2), as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GPL 2 license for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>
#
# The full GNU General Public License is included in this distribution in
# the file called "COPYING".
#
# Contact Information:
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

SRC_DIR=$(pwd)
BUILD_DIR=${SRC_DIR}/$1
ARCH=$2


if [ -z ${ARCH} ]; then
	echo "\${ARCH} not set, falling back to \"x86\""
	ARCH="x86"
fi

METAS="$(cat "${SRC_DIR}/gyroidos/build/yocto/${ARCH}/metas" | tr '\n' ' ')"

echo "METAS: ${METAS}"

SKIP_CONFIG=0
if [ -d ${BUILD_DIR}/conf ]; then
	SKIP_CONFIG=1
fi

source ${SRC_DIR}/poky/oe-init-build-env ${BUILD_DIR}
# will change to build dir


if [ ${SKIP_CONFIG} != 1 ]; then
	bitbake-layers add-layer ${SRC_DIR}/meta-openembedded/meta-oe
	bitbake-layers add-layer ${SRC_DIR}/meta-openembedded/meta-python
	bitbake-layers add-layer ${SRC_DIR}/meta-openembedded/meta-networking
	bitbake-layers add-layer ${SRC_DIR}/meta-openembedded/meta-filesystems
	bitbake-layers add-layer ${SRC_DIR}/meta-virtualization
	bitbake-layers add-layer ${SRC_DIR}/meta-selinux
	bitbake-layers add-layer ${SRC_DIR}/meta-gyroidos

	echo 'FETCHCMD_wget = "/usr/bin/env wget -t 2 -T 30 --passive-ftp --no-check-certificate"' >> ${BUILD_DIR}/conf/local.conf
	mkdir -p ${BUILD_DIR}/conf/multiconfig
	find ${SRC_DIR}/gyroidos/build/yocto/${ARCH}/multiconfig -type f -exec cp '{}' ${BUILD_DIR}/conf/multiconfig/ \;

	echo 'GYROIDOS_FSTYPES ??= "ext4"' >> ${BUILD_DIR}/conf/local.conf
	echo 'PACKAGE_CLASSES = "package_ipk"'  >> ${BUILD_DIR}/conf/local.conf
	echo 'BBMULTICONFIG = "container installer"' >> ${BUILD_DIR}/conf/local.conf
	echo 'PREFERRED_PROVIDER_virtual/kernel ?= "linux-dummy"' >> ${BUILD_DIR}/conf/local.conf
	echo 'PREFERRED_PROVIDER_virtual/kernel_poky-tiny ?= "linux-dummy"' >> ${BUILD_DIR}/conf/local.conf

fi
