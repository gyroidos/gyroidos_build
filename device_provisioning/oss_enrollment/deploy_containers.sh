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

# default values for required files
SELF_DIR="$(dirname ${SELF})"
IMG_DIR="$(dirname ${SELF})"
CONFIG_FILE="${IMG_DIR}/deploy_containers.conf"
LIB_FILE="${IMG_DIR}/provisioning_lib.sh"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  [[ -d ${TMPDIR} ]] && rm -rf ${TMPDIR}
  [[ -f ${CONFIG_CREATOR_DIR}/container_pb2.py  ]] && rm ${CONFIG_CREATOR_DIR}/container_pb2.py 
  [[ -f ${CONFIG_CREATOR_DIR}/container_pb2.pyc ]] && rm ${CONFIG_CREATOR_DIR}/container_pb2.pyc
}

### HELPER FUNCTIONS ###
# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  assert_file_exists ${CONFIG_FILE}
  assert_file_exists ${LIB_FILE}
  echo "Successfully found required files in clean directory"
}

set_adb_opt_args(){
  VER="$(adb version | head -n1 | awk -F "." '{print $NF}')"
  if [ ${VER} -ge 32 ]; then
     ADB_OPT_ARGS="-p"
     echo "ADB version .${VER} allows to set optional parameters: ${ADB_OPT_ARGS}"
  fi
}

calc_free_space(){
  # extract size of userdata in bytes
  #COM_RES=$(adb shell blockdev --getsize64 /dev/block/platform/msm_sdcc.1/by-name/userdata)
  #COM_RES=${COM_RES//[^[:alnum:]]/}
  COM_RES=$(adb shell df | grep "^/data " | awk '{print $2}' | awk -F. '{print $1}')
  if [ -z ${COM_RES} ] ; then
    COM_RES=12
  fi
  COM_RES=$(( ${COM_RES} * 1024*1024*1024 ))
  echo "Total available space in bytes: ${COM_RES}"
  # sanity check
  if [[ ${SPACE_RESERVED} -gt ${COM_RES} ]]; then
    echo "Space available less then reserved space!"
    exit 1
  fi
  # subtract reserved space (e.g., other images inside a container)
  COM_RES=$((${COM_RES} - ${SPACE_RESERVED})) 
}

load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for images, tokens and configs in script's folder"
  elif [ $# -gt 6 ]; then
    echo "Too many arguments specified: $# (expected up to 3 options)"
    echo "Usage: $0 ([(-c|--config) <config_file>] [(-i|--images) <path_to_images>] [((-a| --auto) <a0_percent,a1_percent,a2_percent>) | ((-s| --sizes) <a0_size,a1_size,a2_size>)]"
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

      -i|--images)
        IMG_DIR="$(cd "${2%/}" && pwd -P)"
	if [ -z ${IMG_DIR} ]; then
          echo "-i ${2} dir not found!"
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
        calc_free_space
        echo "Space available for containers: ${COM_RES}"
        # calculate space in mb for every container, depending on ratio stored in the array
        for (( i = 0 ; i < ${#cX_userdata_size[@]} ; i++ ))
        do
          cX_userdata_size[$i]=$((${cX_userdata_size[$i]} * (${COM_RES} / (100*1024*1024))))
          container_no=$(( $i +1 ))
          echo "Set size for a$container_no to: ${cX_userdata_size[$i]} Mb"
        done
        shift
        ;;

      -s|--sizes)
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
	calc_free_space
	if [[ ${sum} -gt ${COM_RES} ]]; then
          echo "More than 100 percent of available userdata space exhausted (${sum}). Error!"
          exit 1
        fi
        shift
        ;;

      -o|--os)
        CONTAINER_OS=$2
	shift
	;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-c|--config) <config_file>] [(-i|--images) <path_to_images>] [-o| --os (a0 | a1 | a2)] [((-a| --auto) <a1_ratio,a2_ratio>) | ((-s| --sizes) (<a1_size,a2_size>)]"
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
set_adb_opt_args

cd ${SELF_DIR}
check_clean

adb wait-for-device
adb root || true
adb wait-for-device

TRUSTME_VERSIONS="$(ls ${IMG_DIR}/*.conf | xargs -n 1 basename | cut -d'-' -f2 | cut -d '.' -f1)"
TRUSTME_VERSIONS_ARRAY=(${TRUSTME_VERSIONS//\n/ })
TRUSTME_VERSION="${TRUSTME_VERSIONS_ARRAY[${#TRUSTME_VERSIONS_ARRAY[@]} - 1]}"

echo "Create container configs and flash containers to device"
echo "Config file is: ${CONFIG_FILE}"
echo "Function lib is: ${LIB_FILE}"
echo "Trustme version is: ${TRUSTME_VERSION}"

adb shell mkdir -p /data/cml/containers
if [ "ids" = "${CONTAINER_OS}" ]; then
  echo "Skiping copy of container configs"
else
  if [ -z "$(echo $(adb shell ls /data/cml/containers/) | grep conf)" ] ; then
    echo "Create and copy container configs to device"
    TMPDIR=$(mktemp -d)
    # create protobuf config
    protoc --python_out=${CONFIG_CREATOR_DIR} -I${IMG_DIR} ${IMG_DIR}/container.proto
    error_check $? "Error during software signing and flashing (proto)"

    # generate container configs
    if [[ "$OSTYPE" == "darwin"* ]]; then
      UUID=$(uuid)
    else
      UUID=$(cat /proc/sys/kernel/random/uuid)
    fi
    python ${CONFIG_CREATOR_DIR}/container_config_creator.py -c ${TMPDIR}/${UUID}.conf -n a1 -go axos -v ${TRUSTME_VERSION} -s ${cX_userdata_size[0]} --color 0x550d0dff
    error_check $? "Error during container config creation)"
    echo "feature_enabled: \"fhgapps\"" >> ${TMPDIR}/${UUID}.conf

    if [[ "$OSTYPE" == "darwin"* ]]; then
      UUID=$(uuid)
    else
      UUID=$(cat /proc/sys/kernel/random/uuid)
    fi
    python ${CONFIG_CREATOR_DIR}/container_config_creator.py -c ${TMPDIR}/${UUID}.conf -n a2 -go axos -v ${TRUSTME_VERSION} -s ${cX_userdata_size[1]} --color 0x004456ff
    error_check $? "Error during container config creation)"
    echo "feature_enabled: \"bluetooth\"" >> ${TMPDIR}/${UUID}.conf
    echo "feature_enabled: \"camera\"" >> ${TMPDIR}/${UUID}.conf
    echo "feature_enabled: \"gapps\"" >> ${TMPDIR}/${UUID}.conf
    echo "feature_enabled: \"gps\"" >> ${TMPDIR}/${UUID}.conf
    echo "feature_enabled: \"telephony\"" >> ${TMPDIR}/${UUID}.conf

    # copy container configs
    error_check $? "Error during software signing and flashing (container createdir)"
    for file in ${TMPDIR}/*.conf; do
      adb push ${file} /data/cml/containers ;
      error_check $? "Error during software signing and flashing (container config copy)"
    done;
  fi
fi

# if no os is selected push all
if [ -z ${CONTAINER_OS} ]; then
  CONTAINER_OS="a0 ax"
fi

# create guestos directories on device and push files
for i in ${CONTAINER_OS}; do
  adb shell mkdir -p /data/cml/operatingsystems/${i}os-${TRUSTME_VERSION}
  error_check $? "Error during software signing and flashing (guestos createdir ${i})"

  echo "Copy container ${i} to device"
  for file in ${IMG_DIR}/${i}os-${TRUSTME_VERSION}/* ; do
    adb push ${ADB_OPT_ARGS} ${file} /data/cml/operatingsystems/${i}os-${TRUSTME_VERSION} ;
    error_check $? "Error during software signing and flashing (${i} flash)"
  done

  echo "Copy guestos configs, signatures and ssig certs to device"
  for type in conf sig cert; do
    for file in ${IMG_DIR}/${i}os-${TRUSTME_VERSION}.$type; do
      adb push ${file} /data/cml/operatingsystems ;
      error_check $? "Error during software signing and flashing (os config/sign/cert copy)"
    done;
  done

done

cleanup
exit 0
