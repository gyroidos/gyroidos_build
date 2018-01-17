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

# This script downloads the stock image from google server and extracts
# the included IMG_ZIP_FILE which contains the vendor.img to a temporyry location
# SIM2IMG is used to generate a non sparse image to the given location OUT_FILE

SIM2IMG=$1
OUT_FILE=$2

if [ -z "${SIM2IMG}" ]; then
	echo "simg2img tool not found!"
	exit 1
fi

if [ -z "${OUT_FILE}" ]; then
	echo "output file not specified!"
	exit 1
fi

FACTORY_ZIP_FILE=bullhead-n2g48c-factory-45d442a2.zip
FACTORY_ZIP_LINK=https://dl.google.com/dl/android/aosp/${FACTORY_ZIP_FILE}
IMG_ZIP_FILE=bullhead-n2g48c/image-bullhead-n2g48c.zip

if [ ! -f ${FACTORY_ZIP_FILE} ]; then
	echo "------------------------------------------------------------"
	echo " Downloading factory image including vendor.img from google! "
	echo "------------------------------------------------------------"
	wget ${FACTORY_ZIP_LINK}
	echo "------------------------------------------------------------"
fi

TMPDIR=$(mktemp -d)
unzip ${FACTORY_ZIP_FILE} ${IMG_ZIP_FILE} -d ${TMPDIR}
unzip -p ${TMPDIR}/${IMG_ZIP_FILE} vendor.img > ${TMPDIR}/vendor.img
${SIM2IMG} ${TMPDIR}/vendor.img ${OUT_FILE}

#rm -r ${TMPDIR}

exit $?
