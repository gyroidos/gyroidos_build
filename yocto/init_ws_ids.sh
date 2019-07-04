#!/bin/bash
#
# This file is part of trust|me
# Copyright(c) 2013 - 2017 Fraunhofer AISEC
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
# Fraunhofer AISEC <trustme@aisec.fraunhofer.de>
#

SRC_DIR=$(pwd)
BUILD_DIR=${SRC_DIR}/$1
ARCH=$2
DEVICE=$3

do_link_devrepo() {
	branch=$(grep ^BRANCH ${SRC_DIR}/meta-trustx/recipes-trustx/cmld/cmld_git.bb | sed -e 's/BRANCH = //' | sed -e 's/\"//g')
	echo $branch
	echo "SRC_URI = \"git:///${SRC_DIR}/trustme/cml/;protocol=file;branch=\${BRANCH}\"" >  ${BUILD_DIR}/cmld_git.bbappend
	(cd ${SRC_DIR}/trustme/cml && if [ -z "$(git branch --list ${branch})" ]; then git checkout -b ${branch}; fi)
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${SRC_DIR}/meta-trustx/recipes-trustx/cmld/
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${SRC_DIR}/meta-trustx/recipes-trustx/service/service_git.bbappend
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${SRC_DIR}/meta-trustx/recipes-trustx/service/service-static_git.bbappend
}


if [ -z ${ARCH} ]; then
	echo "\${ARCH} not set, falling back to \"x86\""
	ARCH="x86"
fi


if [ -z ${DEVICE} ]; then
	echo "\${DEVICE} not set, falling back to \"trustx-corei7-64\""
	DEVICE="trustx-corei7-64"
fi

METAS="$(cat "${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/metas" | tr '\n' ' ')"

echo "METAS: ${METAS}"

SKIP_CONFIG=0
if [ -d ${BUILD_DIR} ]; then
	SKIP_CONFIG=1
fi

source ${SRC_DIR}/poky/oe-init-build-env ${BUILD_DIR}
# will change to build dir

do_link_devrepo

if [ ${SKIP_CONFIG} != 1 ]; then

	for layer in ${METAS}; do
		echo adding layer ${SRC_DIR}/${layer}
		if [ ${layer} == "meta-virtualization" ]; then
			echo "DISTRO_FEATURES_append = \" virtualization\"" >> ${BUILD_DIR}/conf/local.conf
		fi

		bitbake-layers add-layer ${SRC_DIR}/${layer}
	done

	echo appending local.conf for DEVICE="${DEVICE}"
	cat ${SRC_DIR}/trustme/build/yocto/generic/local.conf >> ${BUILD_DIR}/conf/local.conf
	cat ${SRC_DIR}/trustme/build/yocto/${ARCH}/local.conf >> ${BUILD_DIR}/conf/local.conf
	cat ${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/local.conf >> ${BUILD_DIR}/conf/local.conf
	echo 'FETCHCMD_wget = "/usr/bin/env wget -t 2 -T 30 --passive-ftp --no-check-certificate"' >> ${BUILD_DIR}/conf/local.conf
	echo 'KERNEL_DEPLOYSUBDIR = "cml-kernel"' >> ${BUILD_DIR}/conf/local.conf

	mkdir -p ${BUILD_DIR}/conf/multiconfig
	find ${SRC_DIR}/trustme/build/yocto/${ARCH}/multiconfig -type f -exec cp '{}' ${BUILD_DIR}/conf/multiconfig/ \;
	find ${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/multiconfig -type f -exec cp '{}' ${BUILD_DIR}/conf/multiconfig/ \;

	find "${SRC_DIR}/trustme/build/yocto/generic/fragments" -type f -name '*\.cfg' \
			  -exec recipetool appendsrcfile -wWm ${DEVICE} "${SRC_DIR}/meta-trustx" virtual/kernel "{}" ';'

	find "${SRC_DIR}/trustme/build/yocto/${ARCH}/fragments" -type f -name '*\.cfg' \
			  -exec recipetool appendsrcfile -wWm ${DEVICE} "${SRC_DIR}/meta-trustx" virtual/kernel "{}" ';'

	find "${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/fragments" -type f -name '*\.cfg' \
			  -exec recipetool appendsrcfile -wWm ${DEVICE} "${SRC_DIR}/meta-trustx" virtual/kernel "{}" ';'


	cat "${BUILD_DIR}/conf/local.conf" | grep -v INITRAMFS_IMAGE > "${BUILD_DIR}/conf/multiconfig/installer.conf"
	echo "INITRAMFS_IMAGE=\"trustx-installer-initramfs\"" >> "${BUILD_DIR}/conf/multiconfig/installer.conf"
	echo 'KERNEL_DEPLOYSUBDIR = "installer-kernel"' >> "${BUILD_DIR}/conf/multiconfig/installer.conf"
	echo "BBMULTICONFIG += \"installer\"" >> "${BUILD_DIR}/conf/local.conf"
fi
