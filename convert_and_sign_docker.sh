#!bin/bash
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

SELF="$(cd "$(dirname "$0")" && pwd -P)""/$(basename "$0")"
SELF_DIR="$(dirname ${SELF})"

image=${1}
tag=${2}

TRUSTX_CONVERTER_WORK_DIR=/tmp/trustx-converter/trustx_image
TRUSTX_CONVERTER_BIN=${SELF_DIR}/../../out-cml/host/linux-x86/bin/converter
PROVISIONING_DIR=${SELF_DIR}/device_provisioning
ENROLLMENT_DIR=${PROVISIONING_DIR}/oss_enrollment
TEST_CERT_DIR=${PROVISIONING_DIR}/test_certificates
CERT_DIR=${TEST_CERT_DIR}

${TRUSTX_CONVERTER_BIN} pull "registry-1.docker.io" ${image} ${tag}

conf=$(ls ${TRUSTX_CONVERTER_WORK_DIR}/$(echo ${image} | tr '/' '_')_${tag}-*.conf | tail -n1)
bash ${ENROLLMENT_DIR}/config_creator/sign_config.sh ${conf} \
	${CERT_DIR}/ssig.key ${CERT_DIR}/ssig.cert

