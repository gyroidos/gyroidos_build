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

if [ ! -z ${ANDROID_BUILD} ]; then
	bash ${CERTS_DIR}/ssig_pki_generator.sh -p ${SELF_DIR}/test_passwd_env.bash
	bash ${CERTS_DIR}/ssig_aosp_release_keys.sh -p ${SELF_DIR}/test_passwd_env.bash
else
	bash ${CERTS_DIR}/ssig_pki_generator.sh
	bash ${CERTS_DIR}/sec_platform_keys.sh --dbkey ssig_subca
fi


# copy generated test certificate and keys to out dir
for i in cert key esl crt auth; do
	mv ${CERTS_DIR}/*.${i} ${OUT_CERTS_DIR}
done

##############################################
############### General PKI ##################

bash ${CERTS_DIR}/gen_pki_generator.sh -p ${SELF_DIR}/test_passwd_env.bash
bash ${CERTS_DIR}/gen_pki_backend_certs.sh -p ${SELF_DIR}/test_passwd_env.bash
bash ${CERTS_DIR}/gen_ocsp_certs.sh -p ${SELF_DIR}/test_passwd_env.bash

if [ ! -z ${ANDROID_BUILD} ]; then
# generate user token and adbkey
	bash ${CERTS_DIR}/usertoken_generator.sh -u dev.user -p ${SELF_DIR}/test_passwd_env.bash
	mv ${CERTS_DIR}/dev.user.* ${OUT_CERTS_DIR}
fi

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
