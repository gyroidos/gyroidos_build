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

GAPPS_ZIP=$(readlink -f ${1})
OUT_DIR=${2}

TMPDIR=$(mktemp -d)

if [ -d ${OUT_DIR}/system ]; then
	rm -r ${OUT_DIR}/system
fi

mkdir -p ${OUT_DIR}/system

if [ ! -f ${GAPPS_ZIP} ]; then
	echo "No OpenGAPPS zip file found. Generating emtpy GAPPS image ..."
	exit 0
fi

echo "Extracting OpenGAPPS using temp dir ${TMPDIR}"

unzip ${GAPPS_ZIP} -d ${TMPDIR}

(cd ${TMPDIR} && for i in `find Core/ | grep tar`; do tar xvf $i; done )
(cd ${TMPDIR} && for i in `find GApps/ | grep tar`; do tar xvf $i; done )

mkdir ${OUT_DIR}/system/app
mkdir ${OUT_DIR}/system/priv-app

for i in `find ${TMPDIR} | grep /app/ | grep nodpi`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/app; fi; done
for i in `find ${TMPDIR} | grep /app/ | grep "240-320-480"`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/app; fi; done
for i in `find ${TMPDIR} | grep /app/ | grep "480"`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/app; fi; done
for i in `find ${TMPDIR} | grep /priv-app/ | grep nodpi`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/priv-app; fi; done
for i in `find ${TMPDIR} | grep /priv-app/ | grep "240-320-480"`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/priv-app; fi; done
for i in `find ${TMPDIR} | grep /priv-app/ | grep "480"`; do if [ -d $i ]; then cp -r $i ${OUT_DIR}/system/priv-app; fi; done
for i in `find ${TMPDIR} | grep /common$ `; do if [ -d $i ]; then cp -r $i/* ${OUT_DIR}/system/; fi; done

rm -r ${TMPDIR}
