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
LIB_FILE="${SELF_DIR}/provisioning_lib.sh"

set_adb_opt_args(){
  VER="$(adb version | head -n1 | awk -F "." '{print $NF}')"
  if [ ${VER} -ge 32 ]; then
     ADB_OPT_ARGS="-p"
     echo "ADB version .${VER} allows to set optional parameters: ${ADB_OPT_ARGS}"
  fi
}

load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for required files in script's folder"
  elif [ $# -gt 8 ]; then
    echo "Too many arguments specified: $# (expected up to 8 option)"
    echo "Usage: $0 [(-i|--images) <path_to_images>] [(-p|--protodir) <path_to_protofiles>] [(-c|--certdir) <path_to_pki_stuff> [(-s|--cfgseedfile) <file>"
    exit 1
  fi
  while [[ $# > 1 ]]
  do
    key="$1"
    case $key in

      -i|--images)
	IMG_DIR="$(cd "${2%/}" && pwd -P)"
	if [ -z ${IMG_DIR} ]; then
          echo "-i ${2} dir not found!"
          exit 1
        fi
        shift
        ;;
      -p|--protodir)
        PROTO_FILE_DIR="$(cd "${2%/}" && pwd -P)"
	if [ -z ${PROTO_FILE_DIR} ]; then
          echo "-i ${2} dir not found!"
          exit 1
        fi
        shift
        ;;
      -c|--certdir)
        CERT_DIR="$(cd "${2%/}" && pwd -P)"
	if [ -z ${CERT_DIR} ]; then
          echo "-i ${2} dir not found!"
          exit 1
        fi
        shift
        ;;
      -s|--cfgseed)
        CFG_SEED_FILE="$(cd "$(dirname "${2%/}")" && pwd -P)""/$(basename "${2%/}")"
	if [ -z ${CFG_SEED_FILE} ]; then
          echo "-i ${2} dir not found!"
          exit 1
        fi
        shift
        ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-i|--images) <path_to_images>] [(-p|--protodir) <path_to_protofiles>] [(-c|--certdir) <path_to_pki_stuff> [(-s|--cfgseedfile) <file>"
        exit 1
        ;;
      esac
    shift
  done
}

### Start of logic ###
source ${LIB_FILE}

load_parameters $@
set_adb_opt_args

echo "Function lib is: ${LIB_FILE}"

adb wait-for-device
adb root || true
adb wait-for-device

let TRUSTME_OLD_VERSIONS="$(adb shell ls /data/cml/operatingsystems/a0os-*.conf | xargs -n 1 basename | cut -d'-' -f2 | cut -d '.' -f1 | tail -n1)"
if [ $? -ne 0 ]; then
   echo "No old version installed! Please do a full deployment!"
   exit 1
fi
TRUSTME_OLD_VERSIONS_ARRAY=(${TRUSTME_OLD_VERSIONS//\n/ })
OLD_VERSION="${TRUSTME_OLD_VERSIONS_ARRAY[${#TRUSTME_OLD_VERSIONS_ARRAY[@]} - 1]}"
echo "Trustme a0 old version is: ${OLD_VERSION}"


if [ ! -d ${IMG_DIR}/a0os-${OLD_VERSION} ]; then
	mkdir -p ${IMG_DIR}/a0os-${OLD_VERSION}
fi

# get images from device if version does not exist on build machine
for image in modem.img root.img system.img; do
  target="${IMG_DIR}/a0os-${OLD_VERSION}/${image}"
  on_device="/data/cml/operatingsystems/a0os-${OLD_VERSION}/${image}"
  if [ ! -f ${target} ]; then
    echo "Pulling missing image ${on_device}"
    adb pull ${ADB_OPT_ARGS} ${on_device} ${target}
  fi
done

echo "Resign image a0"
# do resign of a0os
ln -sf ../boot.img ${IMG_DIR}/a0os-${OLD_VERSION}/boot.img
protoc --python_out=${SELF_DIR}/config_creator -I${PROTO_FILE_DIR} ${PROTO_FILE_DIR}/guestos.proto
python ${SELF_DIR}/config_creator/guestos_config_creator.py \
  -b ${CFG_SEED_FILE} -v ${OLD_VERSION} \
  -c ${IMG_DIR}/a0os-${OLD_VERSION}.conf \
  -i ${IMG_DIR}/a0os-${OLD_VERSION}/ -n a0os ; \

bash ${SELF_DIR}/config_creator/sign_config.sh ${IMG_DIR}/a0os-${OLD_VERSION}.conf \
	${CERT_DIR}/ssig.key ${CERT_DIR}/ssig.cert; \
rm ${SELF_DIR}/config_creator/guestos_pb2.py*

exit 0
