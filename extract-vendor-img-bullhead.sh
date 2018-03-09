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

# This script downloads the binary/vendor tar balls from google server and extracts
# the included binaries to the workspace

BINARIES_TAR_FILE=qcom-bullhead-n2g48c-271cc2de.tgz
VENDOR_IMG_TAR_FILE=lge-bullhead-n2g48c-ce459634.tgz

BINARIES_TAR_LINK=https://dl.google.com/dl/android/aosp/${BINARIES_TAR_FILE}
VENDOR_IMG_TAR_LINK=https://dl.google.com/dl/android/aosp/${VENDOR_IMG_TAR_FILE}

for i in ${BINARIES_TAR_FILE} ${VENDOR_IMG_TAR_FILE}; do

	if [ ! -f ${i} ]; then
		echo "------------------------------------------------------------"
		echo " Downloading ${i}file from google! "
		echo "------------------------------------------------------------"
		wget ${i}
		echo "------------------------------------------------------------"
	fi
	tar xvzf ${i}
done

for i in lge qcom; do

	if [ ! -d vendor/${i} ]; then
		file=extract-${i}-bullhead.sh
		echo "------------------------------------------------------------"
		echo " Extracting ${file} file from google! "
		echo "------------------------------------------------------------"
		# HACK to  skip interactive license check
		archive_line=`awk '/^exit 0/ {print NR + 2; exit 0; }' ${file} `
		tail -n +${archive_line} ${file} | tar xvz
		echo "------------------------------------------------------------"
	fi
done

exit $?
