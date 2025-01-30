#!/bin/bash
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2021 Fraunhofer AISEC
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

SCRIPTS_DIR=# Path to cml-tools folder (set on installation)

# check if SCRIPTS_DIR is set
if [[ -z $SCRIPTS_DIR || ! -e $SCRIPTS_DIR/device_provisioning ]]; then
    echo "Error: SCRIPTS_DIR is not set correctly in the script" >&2
    exit 1
fi

if [ -z "$1" ];then
    echo "No directory given, exiting..."
    exit 1
fi

SELF_DIR=$(pwd)
WORKDIR=${SELF_DIR}/.device_provisioning

if [[ -d "WORKDIR" ]]; then
    echo "Error: ${WORKDIR} already exists!" >&2 
    exit 1
fi

# make temporary copy of devise_provisioning inside SELF_DIR
mkdir -p ${WORKDIR}
cp -r ${SCRIPTS_DIR}/device_provisioning/* ${WORKDIR}

# generate certificates
if (( $# == 0 )); then
    bash ${WORKDIR}/gen_dev_certs.sh \
        "${SELF_DIR}"
else
    bash ${WORKDIR}/gen_dev_certs.sh \
        "$@"
fi

# remove temporary devise_provisioning
rm -r ${WORKDIR}
