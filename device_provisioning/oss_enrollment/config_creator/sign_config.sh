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

SELF="$(cd "$(dirname "$0")" && pwd -P)""/$(basename "$0")"
SELF_DIR="$(dirname ${SELF})"

cfg="$1"
key="$2"
cert_src="$3"
cert=${cfg%.conf}.cert
sig=${cfg%.conf}.sig

# create signature
if [ -z $4 ]
then
	source ${SELF_DIR}/../../test_passwd_env.bash
	PASS_IN_CA="-passin env:TRUSTME_TEST_PASSWD_PKI"
	openssl dgst -sha512 -sign "$key" -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -out "$sig" ${PASS_IN_CA} "$cfg"
else
	openssl dgst -sha512 -sign "$key" -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -out "$sig" -passin "pass:$4" "$cfg"
fi

openssl_err=$?
if [ ${openssl_err} -ne 0 ]; then
	echo "Openssl Error: Wrong PW?"
	exit ${openssl_err}
fi

# copy software signing certificate
cp -v "$cert_src" "$cert"

