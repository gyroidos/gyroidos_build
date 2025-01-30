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

set -e

SELF="$(cd "$(dirname "$0")" && pwd -P)""/$(basename "$0")"

SELF_DIR="$(dirname ${SELF})"
CERTS_DIR=${SELF_DIR}/oss_enrollment/certificates

if [ ! -z $1 ]; then
	OUT_CERTS_DIR=${1}
else
	OUT_CERTS_DIR=${SELF_DIR}/test_certificates
fi

if [ -d ${OUT_CERTS_DIR} ]; then
	echo "Test Certificates already generated!"
	exit 0
fi
mkdir ${OUT_CERTS_DIR}

##############################################
########## Software Signing PKI ##############

bash ${CERTS_DIR}/ssig_pki_generator.sh
if [ "${DO_PLATFORM_KEYS}" == "y" ]; then
	bash ${CERTS_DIR}/sec_platform_keys.sh --dbkey ssig_subca
fi


# copy generated test certificate and keys to out dir
for i in cert key; do
	mv ${CERTS_DIR}/*.${i} ${OUT_CERTS_DIR}
done

if [ "${DO_PLATFORM_KEYS}" == "y" ]; then
	for i in esl crt auth; do
		mv ${CERTS_DIR}/*.${i} ${OUT_CERTS_DIR}
	done
fi

##############################################
############### General PKI ##################

bash ${CERTS_DIR}/gen_pki_generator.sh -p ${SELF_DIR}/test_passwd_env.bash
bash ${CERTS_DIR}/gen_pki_backend_certs.sh -p ${SELF_DIR}/test_passwd_env.bash
bash ${CERTS_DIR}/gen_ocsp_certs.sh -p ${SELF_DIR}/test_passwd_env.bash

# copy generated test certificate and keys to out dir
for i in cert key; do
	mv ${CERTS_DIR}/*.${i} ${OUT_CERTS_DIR}
done


##############################################
# cleanup temporary pki files
for i in txt old attr pem; do
	rm ${CERTS_DIR}/*.${i}
done	

exit 0
