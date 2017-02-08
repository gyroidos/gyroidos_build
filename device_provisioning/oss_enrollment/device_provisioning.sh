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

### DEFAULT VARIABLES ###
# default values for required files
SELF_DIR="$(dirname ${SELF})"
IMG_DIR="$(dirname ${SELF})"
CONFIG_FILE="${SELF_DIR}/device_provisioning.conf"
LIB_FILE="${SELF_DIR}/provisioning_lib.sh"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  [[ -f ${DEVICE_CERT} ]] && rm ${DEVICE_CERT}
  [[ -f ${DEVICE_CSR} ]] && rm ${DEVICE_CSR}
  [[ -f ${BACKEND_CFG} ]] && rm ${BACKEND_CFG}
}

### HELPER FUNCTIONS ###
# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  assert_file_exists ${CONFIG_FILE}
  assert_file_exists ${LIB_FILE}
  assert_file_not_exists ${DEVICE_CERT}
  assert_file_not_exists ${DEVICE_CSR}
  assert_file_not_exists ${BACKEND_CFG}
  assert_file_exists ${BACKEND_CFG_TEMPLATE}
  assert_file_exists certificates/${DEVICE_SUBCA_CONFIG}
  assert_file_exists ${DEVICE_SUBCA_CERT}
  assert_file_exists ${DEVICE_SUBCA_KEY}
  assert_file_exists ${USER_P12}
  assert_file_exists ${ADB_PUB_KEY_USER}
  if [ "${TRUSTME_DEVICE}" != "y" ]; then
    assert_file_exists ${IMG_DIR}/${USERDATA_IMG}
    assert_file_exists ${IMG_DIR}/${BOOT_IMG}
    assert_file_exists ${IMG_DIR}/${RECOVERY_IMG}
  fi
  echo "Successfully found required files in clean directory"
}

calc_free_space(){
  # extract size of userdata in bytes
  COM_RES=`fastboot getvar partition-size:userdata 2>&1 | sed -ne 's/^.*partition-size:userdata:\([a-f0-9]*\).* /\1/p'`
  # convert results to decimal
  COM_RES=$((0x${COM_RES}))
  echo "Total available space in bytes: ${COM_RES}"
  # sanity check
  if [[ ${SPACE_RESERVED} -gt ${COM_RES} ]]; then
    echo "Space available less then reserved space!"
    exit 1
  fi
  # subtract reserved space (e.g., other images inside a container)
  COM_RES=$((${COM_RES} - ${SPACE_RESERVED})) 
}

# loads parameters
# TODO: missing check, if auto & sizes argument were both provided
# currently, the last argument (auto/sizes) specified is taken into account
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for required files in script's folder"
  elif [ $# -gt 10 ]; then
    echo "Too many arguments specified: $# (expected up to 5 options)"
    echo "Usage: $0 [(-t|--trustme) <y/n>] ([(-c|--config) <config_file>] [(-i|--images) <path_to_images>] [(-u|--user) <token_filename>] [(-a| --auto) <a1_percent,a2_percent>)]"
    exit 1
  fi
  while [[ $# > 1 ]]
  do
    key="$1"
    case $key in
       -t|--trustme)
        TRUSTME_DEVICE="$2"
        shift
        ;;

     -c|--config)
        CONFIG_FILE="$(cd "${2}" && pwd -P)"
        shift
        ;;

      -i|--images)
        IMG_DIR="$(cd "${2%/}" && pwd -P)"
	if [ -z ${IMG_DIR} ]; then
          echo "-i ${2} dir not found!"
          exit 1
        fi
        shift
        ;;

      -u|--user)
        USER_P12="$(readlink -f ${2})"
        ADB_PUB_KEY_USER=${USER_P12%.*}.${ADB_PUB_KEY_NAME}
	if [ -z ${USER_P12} ]; then
          echo "-u ${2} file not found!"
          exit 1
        fi
        shift
        ;;

      -a|--auto)
        IFS=',' read -ra SIZEARR <<< "$2"
        if [[ ${#SIZEARR[*]} -ne 2 ]]; then
          echo "Invalid number of sizes defined, abort"
          exit 1
        fi
        sum=0
        for (( i = 0 ; i < ${#SIZEARR[@]} ; i++ ))
        do
          sum=$(($sum + ${SIZEARR[$i]}))
          cX_userdata_size[$i]="${SIZEARR[$i]}"
        done
        if [[ ${sum} -gt 100 ]]; then
          echo "More than 100 percent of available userdata space exhausted (${sum}). Error!"
          exit 1
        fi
        echo "In total ${sum} percent of the available space for containers will be allocated for a0-a2!"
        #calc_free_space
        #echo "Space available for containers: ${COM_RES}"
        ## calculate space in mb for every container, depending on ratio stored in the array
        #for (( i = 0 ; i < ${#cX_userdata_size[@]} ; i++ ))
        #do
        #  cX_userdata_size[$i]=$((${cX_userdata_size[$i]} * ${COM_RES} / (100*1024*1024)))
        #done
        shift
        ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-t|--trustme) <y/n>] [(-c|--config) <config_file>] [(-i|--images) <path_to_images>] [(-u|--user) <token_filename>] [(-a| --auto) <a1_ratio,a2_ratio>)]"
        exit 1
        ;;
      esac
    shift
  done
}

### Start of logic ###
source ${CONFIG_FILE}
source ${LIB_FILE}

load_parameters $@

cd ${SELF_DIR}
check_clean

if [ "${TRUSTME_DEVICE}" != "y" ]; then
  echo "Path to images is: ${IMG_DIR}"
fi
echo "Config file is: ${CONFIG_FILE}"
echo "Function lib is: ${LIB_FILE}"
echo "User token is: ${USER_P12}"
echo "ADB pubkey is: ${ADB_PUB_KEY_USER}"
echo "Use the following ratio in percent of available space on device for userdata of containers: a1 ${cX_userdata_size[0]}% a2 ${cX_userdata_size[1]}%"

if [ "${TRUSTME_DEVICE}" != "y" ]; then
  echo "Unlocking device"
  fastboot oem unlock
  if [ $? -ne 0 ]; then
    already_unlocked=true
  else
    already_unlocked=false
  fi
  
  echo "Flashing provisioning boot image to device"
  fastboot flash boot ${IMG_DIR}/${BOOT_IMG}
  error_check $? "Flashing of provisioning ramdisk failed"
  
  echo "Flashing recovery image to device"
  fastboot flash recovery ${IMG_DIR}/${RECOVERY_IMG}
  error_check $? "Flashing of recovery image failed"

  if [ "${already_unlocked}" = false ]; then
    fastboot reboot
    echo "Device was rebooted. Please wait till format operations are completed"
    echo "After that, device goes back to bootloader mode"

    #wait, otherwise fastboot flash cmd were triggered to fast...
    sleep 2
    fi

  echo "...waiting for device to flash userdata image"
  fastboot flash userdata ${IMG_DIR}/${USERDATA_IMG}
  error_check $? "Flashing of userdata partition failed"

  echo "...going to expand userdata in recovery mode"
  fastboot boot ${IMG_DIR}/${RECOVERY_IMG}
  bash ${SELF_DIR}/resize_userdata.sh
  adb reboot-bootloader
fi

# provisioning of trustme phones starts in fastboot mode to ensure the device is locked and no containers running, etc
echo "Locking device, then reboot"
fastboot oem lock

fastboot reboot

echo "Connect to device and retrieve device CSR"
adb wait-for-device
adb root || true
adb wait-for-device
adb pull ${DEVICE_TOKEN_DIR}/${DEVICE_CSR}
while [ "$?" != "0" ]; do
  echo "Error getting CSR from device, wait and try again"
  sleep 5
  adb pull ${DEVICE_TOKEN_DIR}/${DEVICE_CSR}
done

# change to certificates subfolder, sign and change one dir up
echo "Sign device CSR with device sub CA certificate"
cd certificates
[[ ! -f ${DEVICE_SUBCA_INDEX_FILE} ]] && touch ${DEVICE_SUBCA_INDEX_FILE}

openssl ca -create_serial -batch -config ${DEVICE_SUBCA_CONFIG} -policy signing_policy -extensions signing_req -out ../${DEVICE_CERT} -infiles ../${DEVICE_CERT} -infiles ../${DEVICE_CSR}
while [ "$?" != "0" ]; do
	echo "Failed to sign device CSR with device sub CA certificate! wrong PW?"
	openssl ca -create_serial -batch -config ${DEVICE_SUBCA_CONFIG} -policy signing_policy -extensions signing_req -out ../${DEVICE_CERT} -infiles ../${DEVICE_CERT} -infiles ../${DEVICE_CSR}
done
cd ../

echo "Verify newly created device certificate"
openssl verify -CAfile ${GEN_ROOTCA_CERT} -untrusted ${DEVICE_SUBCA_CERT} ${DEVICE_CERT}
error_check $? "Failed to verify device certificate"

echo "Concatenate gen CA chain to device cert"
cat ${DEVICE_SUBCA_CERT} >> ${DEVICE_CERT}

echo "Remove CSR on device, push root CAs, user token and device certificate"
adb shell rm ${DEVICE_TOKEN_DIR}/${DEVICE_CSR}
adb push ${DEVICE_CERT} ${DEVICE_TOKEN_DIR}
error_check $? "Failed to push device certificate"

echo "Store device CSR for OCSP Server"
mkdir -p ${DEVICE_CERT_STORE}
cp ${DEVICE_CERT} ${DEVICE_CERT_STORE}/"$(tail -n1 certificates/${DEVICE_SUBCA_INDEX_FILE} | awk '{print $3}')".cert

# TODO insert script with token exchange functionality (re-encrypt data partitions, pull key files, old token, rewrap
echo "Remove existing user tokens"
adb shell rm ${DEVICE_TOKEN_DIR}/*.p12
adb push ${USER_P12} ${DEVICE_TOKEN_DIR}
error_check $? "Failed to push user certificate"

# We enforce our ssig ca during build
#adb push ${SSIG_ROOTCA_CERT} ${DEVICE_TOKEN_DIR}
#error_check $? "Failed to push ssig cert chain"

adb push ${GEN_ROOTCA_CERT} ${DEVICE_TOKEN_DIR}
error_check $? "Failed to push device cert chain"

echo "Set link to Backend (modify stunnel config)"
echo "Link will be set to ${BACKEND_ADDR} (backend) and ${FILESERVER_ADDR} (update server)"
cp ${BACKEND_CFG_TEMPLATE} ${BACKEND_CFG}
sed -i "s|%%SET_BACKEND_IP%%|${BACKEND_ADDR}|g" ${BACKEND_CFG}
sed -i "s|%%SET_FILESERVER_IP%%|${FILESERVER_ADDR}|g" ${BACKEND_CFG}
adb push ${BACKEND_CFG} ${DEVICE_CML_DIR}
error_check $? "Failed to push device backend config"

# TODO: when we have a script that can rewrap container keys, we can add a parameter
# remove any existing container data
# TODO: should we store the paths in the config file?
echo "Remove containers"
adb shell rm /data/cml/keys/*
adb shell rm /data/cml/shared/*
adb shell rm -rf /data/cml/operatingsystems/*
adb shell rm -rf /data/cml/containers/*

# according to system/core/adb/ keys can be in data/misc/adb or /, so this overwrite is sufficient
echo "All operations completed, change ADB key, reboot device"
adb push ${ADB_PUB_KEY_USER} /data/misc/adb/${ADB_PUB_KEY_DEV}
error_check $? "Failed to push user ADB key"

# deploy containers
echo "${SELF_DIR}/deploy_containers.sh -i ${IMG_DIR} -a ${cX_userdata_size[0]},${cX_userdata_size[1]}"
bash ${SELF_DIR}/deploy_containers.sh -i ${IMG_DIR} -a "${cX_userdata_size[0]},${cX_userdata_size[1]}"
error_check $? "deploy containers"

# initial cleanup of spamed logs during provishioning
adb shell rm -rf /data/logs/*

adb shell reboot -f

echo "Device successfully provisioned"
cleanup

exit 0
