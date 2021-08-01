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

# This script creates the software signing PKI (ssig rootCA, ssig subCA)
# This script furthermore creates the software signing certificate
# With the software signing subCA, we can create future software signing certificates
CONFIG_FILE="ssig_pki_generator.conf"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  for x in releasekey platform shared media; do
	[[ -f ${x}.x509.csr ]] && rm ${x}.x509.csr 
	[[ -f ${x}.key ]] && rm ${x}.key
  done
}

# loads parameters and switch between user token and create ca mode
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for config in script's folder"
  elif [ $# -gt 4 ]; then
    echo "Too many arguments specified: $# (expected up to 2 option)"
    echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>]"
    exit 1
  fi

  while [[ $# > 1 ]]
  do
    key="$1"
    case $key in
      -c|--config)
        CONFIG_FILE="$2"
      shift
      ;;
      -p|--pass)
	source $2
        PASS_IN="-passin env:TRUSTME_TEST_PASSWD_PKI"
        PASS_OUT="-passout env:TRUSTME_TEST_PASSWD_PKI"
      shift
      ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>]"
        exit 1
      ;;
    esac
    shift
  done
}

### Start of logic ###
load_parameters $@
cd $(dirname $0)
# load config parameters and helper functions
source ${CONFIG_FILE}
echo "Config file is: ${CONFIG_FILE}"
source ${LIB_FILE}
echo "Function lib is: ${LIB_FILE}"

# SIGN AOSP KEYS

AOSP_SUBJ='/C=DE/O=OSS Release/OU=Development/'
AOSP_CERT_DAYS=2190

echo "Concatenate aosp release keys"
for x in releasekey platform shared media; do
	#openssl req -new -x509 -sha256 -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} -out ${x}.x509.pem -days 10000 -subj "${AOSP_SUBJ}CN=${x}"
	openssl req -batch -sha256 -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} -out ${x}.x509.csr -keyout ${x}.key -outform PEM -days ${AOSP_CERT_DAYS} -subj "${AOSP_SUBJ}CN=${x}" -nodes
	echo "Sign ${x} AOSP CSR with ssig sub CA certificate"
	openssl ca -create_serial -batch -config ${SSIG_SUBCA_CONFIG} -days ${AOSP_CERT_DAYS} -policy signing_policy -extensions signing_req ${PASS_IN} -out ${x}.x509.pem -infiles ${x}.x509.csr
	error_check $? "Failed to sign $x AOSP CSR with ssig sub CA certificate"
	openssl pkcs8 -in ${x}.key -topk8 -outform DER -out ${x}.pk8 -nocrypt
	echo "Concatenate ssig CA chain to ssig cert"
	cat ${SSIG_SUBCA_CERT} >> ${x}.x509.pem
done

echo "AOSP release keys successfully created"
echo "Cleanup temporary files"
cleanup
exit 0

