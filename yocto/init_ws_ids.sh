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


if [ -z ${ARCH} ]; then
	echo "\${ARCH} not set, falling back to \"x86\""
	ARCH="x86"
fi


if [ -z ${DEVICE} ]; then
	echo "\${DEVICE} not set, falling back to \"genericx86-64\""
	DEVICE="genericx86-64"
fi

SKIP_CONFIG=0
if [ -d ${BUILD_DIR}/conf ]; then
	SKIP_CONFIG=1
fi

export TEMPLATECONF=${SRC_DIR}/meta-trustx/conf/templates/default
source ${SRC_DIR}/poky/oe-init-build-env ${BUILD_DIR}
# will change to build dir

if [ "${DEVELOPMENT_BUILD}" == "n" ]; then
	sed -i "s|##DEVELOPMENT_BUILD##|n|g" ${BUILD_DIR}/conf/local.conf
else
	sed -i "s|##DEVELOPMENT_BUILD##|y|g" ${BUILD_DIR}/conf/local.conf
fi

if [ "${CC_MODE}" == "y" ]; then
	sed -i "s|##CC_MODE##|y|g" ${BUILD_DIR}/conf/local.conf
else
	sed -i "s|##CC_MODE##|n|g" ${BUILD_DIR}/conf/local.conf
fi

if ! grep -q '##TRUSTME_HARDWARE##' ${BUILD_DIR}/conf/local.conf;then
	sed -i "s|##TRUSTME_HARDWARE##|${ARCH}|g" ${BUILD_DIR}/conf/local.conf
	sed -i "s|##MACHINE##|${DEVICE}|g" ${BUILD_DIR}/conf/local.conf
	sed -i "s|##TRUSTME_HARDWARE##|${ARCH}|g" ${BUILD_DIR}/conf/bblayers.conf
	sed -i "s|##MACHINE##|${DEVICE}|g" ${BUILD_DIR}/conf/bblayers.conf

	if [ "${ENABLE_SCHSM}" = "1" ]; then
		echo "Enabling sc-hsm support"
		sed -i 's/##TRUSTME_SCHSM##/y/' ${BUILD_DIR}/conf/local.conf
	else
		echo "Not enabling sc-hsm support"
		sed -i 's/##TRUSTME_SCHSM##/n/' ${BUILD_DIR}/conf/local.conf
	fi

	if [ "${TRUSTME_SANITIZERS}" = "1" ]; then
	       echo "Enabling sanitizers for cmld"
	       sed -i 's/##TRUSTME_SANITIZERS##/y/' ${BUILD_DIR}/conf/local.conf
	else
	       echo "Not enabling sanitizers for cmld"
	       sed -i 's/##TRUSTME_SANITIZERS##/n/' ${BUILD_DIR}/conf/local.conf
	fi
else
	echo "local.conf already initialized, skipping configuration"
fi

echo ""
echo "--------------------------------------------"
echo "[\${DEVELOPMENT_BUILD} = '${DEVELOPMENT_BUILD}']"
if [ "${DEVELOPMENT_BUILD}" == "n" ]; then
	echo "### RELEASE_BUILD ###"
else
	echo "### DEVELOPMENT_BUILD ###"
fi
echo "--------------------------------------------"
