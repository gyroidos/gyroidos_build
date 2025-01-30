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

# This script creates the general PKI (general root CA, device subCA, backend subCA, user subCA)
# This script furthermore creates the backend certificate
# With the backend subCA, we can create future backend certificates
# With the device subCA, we can sign device CSRs (device provisioning)
# With the user subCA, we can create user tokens (usertoken generator script)
CONFIG_FILE="gen_pki_generator.conf"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  [[ -f ${DEVICE_SUBCA_CSR} ]] && rm ${DEVICE_SUBCA_CSR}
  [[ -f ${BACKEND_SUBCA_CSR} ]] && rm ${BACKEND_SUBCA_CSR}
  [[ -f ${USER_SUBCA_CSR} ]] && rm ${USER_SUBCA_CSR}
  [[ -f ${BACKEND_CSR} ]] && rm ${BACKEND_CSR}
  for x in *.pem;do rm $x;done
}

# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  # index files
  assert_file_not_exists ${GEN_ROOTCA_INDEX_FILE}
  assert_file_not_exists ${DEVICE_SUBCA_INDEX_FILE}
  assert_file_not_exists ${BACKEND_SUBCA_INDEX_FILE}
  assert_file_not_exists ${USER_SUBCA_INDEX_FILE}
  # serial files
  assert_file_not_exists ${GEN_ROOTCA_SERIAL_FILE}
  assert_file_not_exists ${DEVICE_SUBCA_SERIAL_FILE}
  assert_file_not_exists ${BACKEND_SUBCA_SERIAL_FILE}
  assert_file_not_exists ${USER_SUBCA_SERIAL_FILE}
  # general CA incl chain
  assert_file_not_exists ${GEN_ROOTCA_CERT}
  assert_file_not_exists ${GEN_ROOTCA_KEY}
  # device sub CA
  assert_file_not_exists ${DEVICE_SUBCA_CERT}
  assert_file_not_exists ${DEVICE_SUBCA_CSR}
  assert_file_not_exists ${DEVICE_SUBCA_KEY}
  # backend sub CA
  assert_file_not_exists ${BACKEND_SUBCA_CERT}
  assert_file_not_exists ${BACKEND_SUBCA_CSR}
  assert_file_not_exists ${BACKEND_SUBCA_KEY}
  # user sub CA
  assert_file_not_exists ${USER_SUBCA_CERT}
  assert_file_not_exists ${USER_SUBCA_CSR}
  assert_file_not_exists ${USER_SUBCA_KEY}
  # user, backend, software signing tokens
  assert_file_not_exists ${BACKEND_CSR}
  assert_file_not_exists ${BACKEND_CERT}
  assert_file_not_exists ${BACKEND_KEY}
  # necessary config files
  assert_file_exists ${GEN_ROOTCA_CONFIG}
  assert_file_exists ${DEVICE_SUBCA_CONFIG}
  assert_file_exists ${BACKEND_SUBCA_CONFIG}
  assert_file_exists ${USER_SUBCA_CONFIG}
  assert_file_exists ${BACKEND_CONFIG}
  echo "Successfully found required files in clean directory"
}

load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for config in script's folder"
  elif [ $# -gt 3 ]; then
    echo "Too many arguments specified: $# (expected up to 2 option)"
    echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass)]"
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
        PASS_IN="-passin env:GYROIDOS_TEST_PASSWD_PKI"
        PASS_OUT="-passout env:GYROIDOS_TEST_PASSWD_PKI"
      shift
      ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass)]"
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
check_clean

## Create CA mode ##
# GEN ROOT CA CERT
echo "Create self-signed general root CA certificate"
openssl req -batch -x509 -config ${GEN_ROOTCA_CONFIG} -days ${DAYS_VALID} -newkey rsa:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${GEN_ROOTCA_CERT} -outform PEM
error_check $? "Failed to create self signed general root CA certificate"

# DEVICE SUB CA CERT
echo "Create device sub CA CSR"
openssl req -batch -config ${DEVICE_SUBCA_CONFIG} -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${DEVICE_SUBCA_CSR} -outform PEM
error_check $? "Failed to create device sub CA CSR"

echo "Sign device sub CA CSR with general root CA"
touch ${GEN_ROOTCA_INDEX_FILE}
openssl ca -create_serial -batch -config ${GEN_ROOTCA_CONFIG} -policy signing_policy -extensions signing_req_CA ${PASS_IN} -out ${DEVICE_SUBCA_CERT} -infiles ${DEVICE_SUBCA_CSR}
error_check $? "Failed to sign device sub CA CSR with gen root CA certificate"

echo "Verify newly created device sub CA certificate"
openssl verify -CAfile ${GEN_ROOTCA_CERT} ${DEVICE_SUBCA_CERT}
error_check $? "Failed to verify newly signed device sub CA certificate"

echo "Concatenate gen root CA cert to device subca cert"
cat ${GEN_ROOTCA_CERT} >> ${DEVICE_SUBCA_CERT}

# USER SUB CA CERT
echo "Create user sub CA CSR"
openssl req -batch -config ${USER_SUBCA_CONFIG} -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${USER_SUBCA_CSR} -outform PEM
error_check $? "Failed to create user sub CA CSR"

echo "Sign user sub CA CSR with general root CA"
openssl ca -create_serial -batch -config ${GEN_ROOTCA_CONFIG} -policy signing_policy -extensions signing_req_CA ${PASS_IN} -out ${USER_SUBCA_CERT} -infiles ${USER_SUBCA_CSR}
error_check $? "Failed to sign user sub CA CSR with general root CA certificate"

echo "Verify newly created user sub CA certificate"
openssl verify -CAfile ${GEN_ROOTCA_CERT} ${USER_SUBCA_CERT}
error_check $? "Failed to verify newly signed user sub CA certificate"

echo "Concatenate gen root CA cert to user subca cert"
cat ${GEN_ROOTCA_CERT} >> ${USER_SUBCA_CERT}

echo "General PKI certificate structure successfully created"
echo "Cleanup temporary files"
cleanup
exit 0
