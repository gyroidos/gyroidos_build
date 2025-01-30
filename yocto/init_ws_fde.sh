#!/bin/bash
#
# This file is part of GyroidOS
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
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

SRC_DIR=$(pwd)
BUILD_DIR=${SRC_DIR}/$1
DEVICE=$2

METAS="meta-intel meta-openembedded/meta-oe meta-openembedded/meta-python meta-selinux meta-trustx meta-tpm2d-fde"

if [ -z ${DEVICE} ]; then
	echo "\${DEVICE} not set, falling back to \"x86\""
	DEVICE=x86
fi

SKIP_CONFIG=0
if [ -d ${BUILD_DIR} ]; then
	SKIP_CONFIG=1
fi

source ${SRC_DIR}/poky/oe-init-build-env ${BUILD_DIR}
# will change to build dir

if [ ${SKIP_CONFIG} != 1 ]; then

	for layer in ${METAS}; do
		echo adding layer ${SRC_DIR}/${layer}
		bitbake-layers add-layer ${SRC_DIR}/${layer}
	done

	echo appending local.conf for DEVICE="${DEVICE}"
	cat ${SRC_DIR}/gyroidos/build/yocto/${DEVICE}/local_fde.conf >> ${BUILD_DIR}/conf/local.conf
fi
