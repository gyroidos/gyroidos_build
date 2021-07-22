#!/bin/bash
#
# This file is part of trust|me
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
	mkdir -p ${BUILD_DIR}/meta-appends/recipes-trustx/cmld/
	mkdir -p ${BUILD_DIR}/meta-appends/recipes-trustx/service/
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${BUILD_DIR}/meta-appends/recipes-trustx/cmld/
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${BUILD_DIR}/meta-appends/recipes-trustx/service/service_git.bbappend
	ln -sf ${BUILD_DIR}/cmld_git.bbappend ${BUILD_DIR}/meta-appends/recipes-trustx/service/service-static_git.bbappend
}


if [ -z ${ARCH} ]; then
	echo "\${ARCH} not set, falling back to \"x86\""
	ARCH="x86"
fi


if [ -z ${DEVICE} ]; then
	echo "\${DEVICE} not set, falling back to \"genericx86-64\""
	DEVICE="genericx86-64"
fi

METAS="$(cat "${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/metas" | tr '\n' ' ')"

echo "METAS: ${METAS}"

SKIP_CONFIG=0
if [ -d ${BUILD_DIR}/conf ]; then
	SKIP_CONFIG=1
else
	mkdir -p ${BUILD_DIR}/conf
	if [ "${DEVELOPMENT_BUILD}" == "n" ]; then
		# create empty conf without debug-tweeks
		echo "#PRODUCTION IMAGE" > ${BUILD_DIR}/conf/local.conf
		echo "DEVELOPMENT_BUILD = \"n\"" >> ${BUILD_DIR}/conf/local.conf
	else
		echo "#DEVELOPMENT IMAGE" > ${BUILD_DIR}/conf/local.conf
		echo "DEVELOPMENT_BUILD = \"y\"" >> ${BUILD_DIR}/conf/local.conf
		echo "EXTRA_IMAGE_FEATURES = \"debug-tweaks\"" >> ${BUILD_DIR}/conf/local.conf
	fi

	if [ "${CC_MODE}" == "y" ]; then
		echo "CC_MODE = \"y\"" >> ${BUILD_DIR}/conf/local.conf
	else
		echo "CC_MODE = \"n\"" >> ${BUILD_DIR}/conf/local.conf
	fi
fi

source ${SRC_DIR}/poky/oe-init-build-env ${BUILD_DIR}
# will change to build dir


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
	cat ${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/local.conf >> ${BUILD_DIR}/conf/local.conf

	echo 'FETCHCMD_wget = "/usr/bin/env wget -t 2 -T 30 --passive-ftp --no-check-certificate"' >> ${BUILD_DIR}/conf/local.conf
	echo 'KERNEL_DEPLOYSUBDIR = "cml-kernel"' >> ${BUILD_DIR}/conf/local.conf

	mkdir -p ${BUILD_DIR}/conf/multiconfig
	find ${SRC_DIR}/trustme/build/yocto/${ARCH}/multiconfig -type f -exec cp '{}' ${BUILD_DIR}/conf/multiconfig/ \;
	find ${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/multiconfig -type f -exec cp '{}' ${BUILD_DIR}/conf/multiconfig/ \;

	if [ -d ${BUILD_DIR}/meta-appends ]; then
		echo cleaning out old meta-appends
		rm -rf ${BUILD_DIR}/meta-appends
	fi

	echo creating temporary layer meta-appends
	bitbake-layers create-layer ${BUILD_DIR}/meta-appends

	(cd ${BUILD_DIR} && bitbake-layers add-layer ./meta-appends)

	find "${SRC_DIR}/trustme/build/yocto/generic/fragments" -type f -and \( -name '*\.cfg' -o -name '*\.patch' \) -print0 | sort -z --human-numeric-sort | xargs -0 -L 1 --no-run-if-empty recipetool appendsrcfile -wW "${BUILD_DIR}/meta-appends" virtual/kernel

	find "${SRC_DIR}/trustme/build/yocto/${ARCH}/fragments" -type f -and \( -name '*\.cfg' -o -name '*\.patch' \) -print0 | sort -z --human-numeric-sort | xargs -0 -L 1 --no-run-if-empty recipetool appendsrcfile -wW "${BUILD_DIR}/meta-appends" virtual/kernel

	find "${SRC_DIR}/trustme/build/yocto/${ARCH}/${DEVICE}/fragments" -type f -and \( -name '*\.cfg' -o -name '*\.patch' \) -print0 | sort -z --human-numeric-sort | xargs -0 -L 1 --no-run-if-empty recipetool appendsrcfile -wW "${BUILD_DIR}/meta-appends" virtual/kernel

	echo "CONFIG_MODULE_SIG_KEY=\"${BUILD_DIR}/test_certificates/certs/signing_key.pem\"" >  ${BUILD_DIR}/modsign_key.cfg
	echo "CONFIG_SYSTEM_TRUSTED_KEYS=\"${BUILD_DIR}/test_certificates/ssig_rootca.cert\"" >>  ${BUILD_DIR}/modsign_key.cfg

	recipetool appendsrcfile -wW "${BUILD_DIR}/meta-appends" virtual/kernel ${BUILD_DIR}/modsign_key.cfg
	sed -i 's/BBFILE_PRIORITY_meta-appends = "[[:digit:]]"/BBFILE_PRIORITY_meta-appends = "8"/' ${BUILD_DIR}/meta-appends/conf/layer.conf

	sed -i "s/# random string to ignore SSTATE_MIRROR/# random string to ignore SSTATE_MIRROR: $(date +%s | sha1sum | awk '{print $1}')/" "${SRC_DIR}/meta-trustx/recipes-trustx/userdata/pki-native.bb"

	if [ "${ENABLE_SCHSM}" = "1" ]; then
		echo "Enabling sc-hsm support"
		sed -i 's/\(TRUSTME_SCHSM = "\)n/\1y/' ${BUILD_DIR}/conf/local.conf
	fi

	# enable SecureBoot support in OVMF
	echo 'PACKAGECONFIG_append_pn-ovmf = " secureboot"' >> ${BUILD_DIR}/conf/local.conf
fi


do_link_devrepo

echo ""
echo "--------------------------------------------"
echo "[\${DEVELOPMENT_BUILD} = '${DEVELOPMENT_BUILD}']"
if [ "${DEVELOPMENT_BUILD}" == "n" ]; then
	echo "### RELEASE_BUILD ###"
else
	echo "### DEVELOPMENT_BUILD ###"
fi
echo "--------------------------------------------"
