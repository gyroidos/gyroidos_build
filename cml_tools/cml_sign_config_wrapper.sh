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

bash ${SCRIPTS_DIR}/device_provisioning/oss_enrollment/config_creator/\
sign_config.sh "$@"
