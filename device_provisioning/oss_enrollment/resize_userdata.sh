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

USERDATA_DEV_NAME="/dev/block/platform/msm_sdcc.1/by-name/userdata"

wait_for_recovery () {
	while ( [ -z "$(adb devices | grep recovery)" ] ); do
		sleep 1
	done
}

wait_for_recovery
adb root || true
wait_for_recovery

if [ -n "$(echo $(adb shell mount) | grep data)" ]; then
	adb shell umount /data
fi
adb shell /sbin/e2fsck_static -f -y ${USERDATA_DEV_NAME}
adb shell /sbin/resize2fs_static -f ${USERDATA_DEV_NAME}
adb shell /sbin/e2fsck_static -f -y ${USERDATA_DEV_NAME}

# adb shell allways returns 0 if adb shell itself works
exit 0
