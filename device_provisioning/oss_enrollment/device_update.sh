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

# loads parameters
# TODO: missing check, if auto & sizes argument were both provided
# currently, the last argument (auto/sizes) specified is taken into account
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for required files in script's folder"
  elif [ $# -gt 3 ]; then
    echo "Too many arguments specified: $# (expected up to 2 option)"
    echo "Usage: $0 [(-i|--images) <path_to_images>]"
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
      -k|--kernel)
	KERNEL_ONLY=1
	;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-i|--images) <path_to_images>] [-k]"
        exit 1
        ;;
      esac
    shift
  done
}

### Start of logic ###
source ${LIB_FILE}

load_parameters $@

echo "Function lib is: ${LIB_FILE}"

adb wait-for-device
adb root || true
adb wait-for-device

if [ -n ${KERNEL_ONLY} ]; then
  let TRUSTME_OLD_VERSIONS="$(adb shell ls /data/cml/operatingsystems/a0os-*.conf | xargs -n 1 basename | cut -d'-' -f2 | cut -d '.' -f1 | tail -n1)"
  if [ $? -ne 0 ]; then
     echo "No old version installed! Please do a full deployment!"
     exit 1
  fi
  TRUSTME_OLD_VERSIONS_ARRAY=(${TRUSTME_OLD_VERSIONS//\n/ })
  TRUSTME_OLD_VERSION="${TRUSTME_OLD_VERSIONS_ARRAY[${#TRUSTME_OLD_VERSIONS_ARRAY[@]} - 1]}"
  echo "Trustme old version is: ${TRUSTME_OLD_VERSION}"
fi

TRUSTME_VERSIONS="$(ls ${IMG_DIR}/a0os-*.conf | xargs -n 1 basename | cut -d'-' -f2 | cut -d '.' -f1)"
TRUSTME_VERSIONS_ARRAY=(${TRUSTME_VERSIONS//\n/ })
TRUSTME_VERSION="${TRUSTME_VERSIONS_ARRAY[${#TRUSTME_VERSIONS_ARRAY[@]} - 1]}"
echo "Trustme version is: ${TRUSTME_VERSION}"

echo "Update OS kernel"
adb push ${IMG_DIR}/boot.img /tmp/boot.img
adb push ${IMG_DIR}/recovery.img /tmp/recovery.img
adb shell dd if=/tmp/boot.img of=/dev/block/platform/msm_sdcc.1/by-name/boot
adb shell dd if=/tmp/recovery.img of=/dev/block/platform/msm_sdcc.1/by-name/recovery
echo "Update of OS kernel done."

if [ -n ${KERNEL_ONLY} ]; then
  echo "Pushing old a0os config with new ramdisk"
  adb push ${IMG_DIR}/a0os-${TRUSTME_OLD_VERSION}.* /data/cml/operatingsystems
  adb shell dd if=/tmp/boot.img of=/data/cml/operatingsystems/a0os-${TRUSTME_OLD_VERSION}/boot.img
  exit 0
fi


# deploy containers
echo "${SELF_DIR}/deploy_containers.sh -i ${IMG_DIR}"
bash ${SELF_DIR}/deploy_containers.sh -i ${IMG_DIR}
error_check $? "deploy containers"

adb shell reboot -f

echo "Device successfully updated"

exit 0
