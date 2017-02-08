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

# This script creates usertokens based on the user sub CA (general PKI)
# As input, the script requires a filename, which is currently set as CN
# and the only way to associate the token with the specific user.
# The script also creates the user-specific ADB keypair.
# This script requires ADB v1.0.32
CONFIG_FILE="usertoken_generator.conf"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  [[ -f ${USER_CSR} ]] && rm ${USER_CSR}
  [[ -f ${USER_KEY} ]] && rm ${USER_KEY}
  [[ -f ${USER_CERT} ]] && rm ${USER_CERT}
  #for x in *.pem;do rm $x;done
}

# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  assert_file_not_exists ${USER_CSR}
  assert_file_not_exists ${USER_CERT}
  assert_file_not_exists ${USER_KEY}
  assert_file_not_exists ${USER_P12}
  assert_file_not_exists ${ADB_PRIV_KEY}
  assert_file_not_exists ${ADB_PUB_KEY}
  assert_file_exists ${USER_CONFIG}
  assert_file_exists ${USER_SUBCA_CONFIG}
  assert_file_exists ${USER_SUBCA_CERT}
  assert_file_exists ${USER_SUBCA_KEY}
  echo "Successfully found required files in clean directory"
}

# loads parameters and switch between user token and create ca mode
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for config in script's folder"
  elif [ $# -gt 6 ]; then
    echo "Too many arguments specified: $# (expected up to 4 options)"
    echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>] (-u|--user) <user_name>"
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
        PASS_IN_CA="-passin env:TRUSTME_TEST_PASSWD_PKI"
	PASS_OUT_USER="-passout env:TRUSTME_TEST_PASSWD_USER_TOKEN"
      shift
      ;;
      -u|--user)
        USER_TOKEN_CN="${2%/}"
      shift
      ;;
      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>] (-u|--user) <user_name>"
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

# try to use adb binary from working dir
ADB=`readlink -f ${ADB_BIN}`
echo ${ADB}
if [ ! -x ${ADB} ]; then
	ADB=adb
fi

ADB_VERSION="$(${ADB} version | head -n1 | awk -F "." '{print $NF}')"
if [[ ${ADB_VERSION} -lt 32 ]]; then
  echo "ADB version .${VER} too low (or missing ADB). Requires at least 1.0.32 for adb keygen"
  exit 1
fi

# check if usertoken or create CA mode was triggered with command line arguments
if [ "${USER_TOKEN_CN}" != "" ]; then
  
  # check if directory is smooth and determine p12 token name
  echo "Create user token for user (CN): ${USER_TOKEN_CN}"
  USER_P12="${USER_TOKEN_CN}.p12"
  ADB_PRIV_KEY="${USER_TOKEN_CN}.${ADB_PRIV_KEY}"
  ADB_PUB_KEY="${ADB_PRIV_KEY}.pub"
  check_clean

  echo "Create new user CSR"
  # pwd is set when creating p12 token, so -nodes should be fine here
  openssl req -nodes -batch -config ${USER_CONFIG} -newkey rsa:${KEY_SIZE} ${PASS_IN_CA} -out ${USER_CSR} -outform PEM -subj "/C=DE/O=OSS Release/OU=Development/CN=${USER_TOKEN_CN}/"
  error_check $? "Failed to create new user CSR"

  echo "Sign user CSR with user sub CA certificate"
  [[ ! -f ${USER_SUBCA_INDEX_FILE} ]] && touch ${USER_SUBCA_INDEX_FILE}
  openssl ca -create_serial -batch -config ${USER_SUBCA_CONFIG} -policy signing_policy -extensions signing_req ${PASS_IN_CA} -out ${USER_CERT} -infiles ${USER_CSR}
  error_check $? "Failed to sign user CSR with user sub CA certificate"

  echo "Concatenate gen CA chain to user cert"
  cat ${USER_SUBCA_CERT} >> ${USER_CERT}

  echo "Create user token from certifcate and key"
  openssl pkcs12 -export -inkey ${USER_KEY} -in ${USER_CERT} -out ${USER_P12} ${PASS_OUT_USER}
  error_check $? "Failed to create user p12 token"

  echo "Create ADB public key pair for user ${USER_TOKEN_CN}"
  ${ADB} keygen ${ADB_PRIV_KEY}
else
  echo "Error. Please specify a valid usertoken string"
  exit 1
fi

echo "Successfully created a new user token"
echo "Cleanup temporary files"
cleanup
exit 0
