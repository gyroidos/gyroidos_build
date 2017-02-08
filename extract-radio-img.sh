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
# the included RADIO_IMG_FILE to the given location OUT_FILE

OUT_FILE=$1
FACTORY_ZIP_FILE=hammerhead-lmy48m-factory-e01ca3b7.zip
FACTORY_ZIP_LINK=https://dl.google.com/dl/android/aosp/${FACTORY_ZIP_FILE}
RADIO_IMG_FILE=hammerhead-lmy48m/radio-hammerhead-m8974a-2.0.50.2.26.img

if [ ! -f ${FACTORY_ZIP_FILE} ]; then
	echo "------------------------------------------------------------"
	echo " Downloading factory image including modem.img from google! "
	echo "------------------------------------------------------------"
	wget ${FACTORY_ZIP_LINK}
	echo "------------------------------------------------------------"
fi

unzip -p ${FACTORY_ZIP_FILE} ${RADIO_IMG_FILE} > ${OUT_FILE}

exit $?
