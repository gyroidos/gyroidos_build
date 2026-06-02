#!/usr/bin/env bash
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2018 Fraunhofer AISEC
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

set -euo pipefail

# shellcheck disable=SC2329
cleanup(){
  echo "Cleanup unnecessary files"
  for x in PK KEK DB; do
	[[ -f "${x}.x509.csr" ]] && rm "${x}.x509.csr"
	[[ -f "${x}.key" ]] && rm "${x}.key"
  done
}

# loads parameters and switch between user token and create ca mode
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified."
  elif [ $# -gt 4 ]; then
    echo "Too many arguments specified: $# (expected up to 2 options)"
    echo "Usage: $0 [(-k|--keytype) <signature_algorithm>] [(-dk|--dbkey) <key_name>]"
    exit 1
  fi

  while (( $# > 1 ))
  do
    key="$1"
    case "$key" in
      -k|--keytype)
        KEY_TYPE="$2"
      shift
      ;;
      -dk|--dbkey)
        ADDITIONAL_DB_KEY="$2"
      shift
      ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-k|--keytype) <signature_algorithm>] [(-dk|--dbkey) <key_name>]"
        exit 1
      ;;
    esac
    shift
  done
}

ADDITIONAL_DB_KEY="${ADDITIONAL_DB_KEY:-}"

### Start of logic ###
load_parameters "$@"
cd "$(dirname "$0")" || exit
# shellcheck source=/dev/null
source "../provisioning_lib.sh"
echo "Function lib is: ../provisioning_lib.sh"
set_newkey_args "${KEY_TYPE}"

# GEN SELF SIGNED PLATFORM KEYS

SUBJ='/C=DE/O=OSS Release/OU=Development/'
CERT_DAYS=2190

UUID=$(cat /proc/sys/kernel/random/uuid)

echo "$UUID"

for x in PK KEK DB; do
  echo "generate secure boot key=${x}"
  openssl req -new -x509 -sha256 "${NEWKEY_ARGS_primary[@]}" -subj "${SUBJ}CN=${x}/" -keyout "${x}.key" -out "${x}.crt" -days "${CERT_DAYS}" -nodes
  cert-to-efi-sig-list -g "$UUID" "${x}.crt" "${x}.esl"
done

sign-efi-sig-list -t "$(date +'%Y-%m-%d %H:%M:%S')" -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -t "$(date +'%Y-%m-%d %H:%M:%S')" -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -t "$(date +'%Y-%m-%d %H:%M:%S')" -k KEK.key -c KEK.crt db DB.esl DB.auth


echo "adding ${ADDITIONAL_DB_KEY} to DB"
cert-to-efi-sig-list -g "$(cat /proc/sys/kernel/random/uuid)" "${ADDITIONAL_DB_KEY}.cert" "${ADDITIONAL_DB_KEY}.esl"

mv DB.esl _DB.esl
cat _DB.esl "${ADDITIONAL_DB_KEY}.esl" > DB.esl

echo "secure boot keys successfully created"
#echo "Cleanup temporary files"
#cleanup
exit 0
