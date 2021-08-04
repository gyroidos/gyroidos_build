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
  [[ -f ${SSIG_SUBCA_CSR} ]] && rm ${SSIG_SUBCA_CSR}
  [[ -f ${SSIG_SUBCA_CML_CSR} ]] && rm ${SSIG_SUBCA_CML_CSR}
  [[ -f ${SSIG_CSR} ]] && rm ${SSIG_CSR}
  [[ -f ${SSIG_CML_CSR} ]] && rm ${SSIG_CML_CSR}
  for x in *.pem;do rm $x;done
}

# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  # index files
  assert_file_not_exists ${SSIG_ROOTCA_INDEX_FILE}
  assert_file_not_exists ${SSIG_SUBCA_INDEX_FILE}
  # serial files
  assert_file_not_exists ${SSIG_ROOTCA_SERIAL_FILE}
  assert_file_not_exists ${SSIG_SUBCA_SERIAL_FILE}
  # ssig CA incl chain
  assert_file_not_exists ${SSIG_ROOTCA_CERT}
  assert_file_not_exists ${SSIG_ROOTCA_KEY}
  assert_file_not_exists ${SSIG_SUBCA_CERT}
  assert_file_not_exists ${SSIG_SUBCA_CSR}
  assert_file_not_exists ${SSIG_SUBCA_KEY}
  assert_file_not_exists ${SSIG_SUBCA_CML_CERT}
  assert_file_not_exists ${SSIG_SUBCA_CML_CSR}
  assert_file_not_exists ${SSIG_SUBCA_CML_KEY}
  assert_file_not_exists ${SSIG_CML_CSR}
  assert_file_not_exists ${SSIG_CML_CERT}
  assert_file_not_exists ${SSIG_CML_KEY}
  assert_file_exists ${SSIG_ROOTCA_CONFIG}
  assert_file_exists ${SSIG_SUBCA_CONFIG}
  assert_file_exists ${SSIG_CONFIG}
  echo "Successfully found required files in clean directory"
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

PASS_IN=""
PASS_OUT="-nodes"

### Start of logic ###
load_parameters $@
cd $(dirname $0)
# load config parameters and helper functions
source ${CONFIG_FILE}
echo "Config file is: ${CONFIG_FILE}"
source ${LIB_FILE}
echo "Function lib is: ${LIB_FILE}"
check_clean

# SSIG ROOT CA CERT
echo "Create self-signed ssig root CA certificate"
openssl req -batch -x509 -config ${SSIG_ROOTCA_CONFIG} -newkey rsa:${KEY_SIZE} -days ${DAYS_VALID} ${PASS_IN} ${PASS_OUT} -out ${SSIG_ROOTCA_CERT} -outform PEM
error_check $? "Failed to create self signed ssig root CA certificate"

# SSIG SUB CA (kernel) CERT
echo "Create ssig sub CA (kernel) CSR"
openssl req -batch -config ${SSIG_SUBCA_CONFIG} -newkey rsa:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${SSIG_SUBCA_CSR} -outform PEM
error_check $? "Failed to create ssig sub CA CSR"

echo "Sign ssig sub CA CSR with ssig root CA"
touch ${SSIG_ROOTCA_INDEX_FILE}
openssl ca -notext -create_serial -batch -config ${SSIG_ROOTCA_CONFIG} -policy signing_policy -extensions signing_req_CA ${PASS_IN} -out ${SSIG_SUBCA_CERT} -infiles ${SSIG_SUBCA_CSR}
error_check $? "Failed to sign ssig sub CA CSR with ssig root CA certificate"

echo "Verify newly created ssig sub CA certificate"
openssl verify -CAfile ${SSIG_ROOTCA_CERT} ${SSIG_SUBCA_CERT}
error_check $? "Failed to verify newly signed ssig sub CA (kernel) certificate"

echo "Concatenate ssig root CA cert to ssig subca (kernel) cert"
cat ${SSIG_ROOTCA_CERT} >> ${SSIG_SUBCA_CERT}

# SSIG SUB CA (CML) CERT
echo "Create ssig sub CA (CML) CSR"
openssl req -batch -config ${SSIG_SUBCA_CML_CONFIG} -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${SSIG_SUBCA_CML_CSR} -outform PEM
error_check $? "Failed to create ssig sub CA (CML) CSR"

echo "Sign ssig sub CA (CML) CSR with ssig root CA"
touch ${SSIG_ROOTCA_INDEX_FILE}
openssl ca -notext -create_serial -batch -config ${SSIG_ROOTCA_CONFIG} -policy signing_policy -extensions signing_req_CA ${PASS_IN} -out ${SSIG_SUBCA_CML_CERT} -infiles ${SSIG_SUBCA_CML_CSR}
error_check $? "Failed to sign ssig sub CA CSR (CML) with ssig root CA certificate"

echo "Verify newly created ssig sub CA (CML) certificate"
openssl verify -CAfile ${SSIG_ROOTCA_CERT} ${SSIG_SUBCA_CML_CERT}
error_check $? "Failed to verify newly signed ssig sub CA (CML) certificate"


# SSIG CERT (kernel)
echo "Create software signing CSR"
openssl req -batch -config ${SSIG_CONFIG} -newkey rsa:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${SSIG_CSR} -outform PEM
error_check $? "Failed to create software signing CSR"

echo "Sign software signing CSR with ssig sub CA certificate"
touch ${SSIG_SUBCA_INDEX_FILE}
openssl ca -notext -create_serial -batch -config ${SSIG_SUBCA_CONFIG} -policy signing_policy -extensions signing_req ${PASS_IN} -out ${SSIG_CERT} -infiles ${SSIG_CSR}
error_check $? "Failed to sign software signing CSR with ssig sub CA certificate"

echo "Verify newly created ssig certificate"
openssl verify -CAfile ${SSIG_ROOTCA_CERT} -untrusted ${SSIG_SUBCA_CERT} ${SSIG_CERT}
error_check $? "Failed to verify newly signed ssig certificate"

echo "Concatenate ssig CA chain to ssig cert"
cat ${SSIG_SUBCA_CERT} >> ${SSIG_CERT}


# SSIG CERT (CML)
echo "Create software signing (CML) CSR"
openssl req -batch -config ${SSIG_CML_CONFIG} -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${SSIG_CML_CSR} -outform PEM
error_check $? "Failed to create software signing (CML) CSR"

echo "Sign software signing CSR with ssig sub CA (CML) certificate"
touch ${SSIG_SUBCA_CML_INDEX_FILE}
openssl ca -notext -create_serial -batch -config ${SSIG_SUBCA_CML_CONFIG} -policy signing_policy -extensions signing_req ${PASS_IN} -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -out ${SSIG_CML_CERT} -infiles ${SSIG_CML_CSR}
error_check $? "Failed to sign software signing (CML) CSR with ssig sub CA (CML) certificate"

echo "Verify newly created ssig (CML) certificate"
openssl verify -CAfile ${SSIG_ROOTCA_CERT} -untrusted ${SSIG_SUBCA_CML_CERT} ${SSIG_CML_CERT}
error_check $? "Failed to verify newly signed (CML) ssig certificate"

echo "Concatenate ssig CA chain to ssig cert"
cat ${SSIG_SUBCA_CML_CERT} >> ${SSIG_CML_CERT}



echo "Software Signing PKI certificate structure successfully created"
echo "Cleanup temp files"
cleanup
exit 0
