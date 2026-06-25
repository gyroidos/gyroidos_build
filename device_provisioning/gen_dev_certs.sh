#!/usr/bin/env bash
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

set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"

SELF_DIR="$(dirname "${SELF}")"
CERTS_DIR="${SELF_DIR}/oss_enrollment/certificates"
DO_PLATFORM_KEYS="${DO_PLATFORM_KEYS:-}"

OUT_CERTS_DIR="${1:-${SELF_DIR}/test_certificates}"

# Multiple recipes/multiconfigs invoke this concurrently with the same
# OUT_CERTS_DIR. Serialize them on a dedicated lock (NOT ${OUT_CERTS_DIR}.lock,
# which pki-native holds while calling us -> self-deadlock).
exec 9>"${OUT_CERTS_DIR}.genlock"
flock 9

if [[ -d "${OUT_CERTS_DIR}" ]]; then
	echo "Test Certificates already generated!"
	exit 0
fi
if [[ -L "${OUT_CERTS_DIR}" ]]; then
    # Jenkinsfile seeded an external PKI (PKI_PATH). Use it; NEVER generate over it
    # (that would self-sign a release with throwaway keys). Fail loud if it's broken.
    echo "${BASH_SOURCE[0]} called on release PKI '$(readlink "${OUT_CERTS_DIR}")', doing nothing." >&2
    exit 0
fi
if [[ -e "${OUT_CERTS_DIR}" ]]; then
        echo "Removing stale non-directory at ${OUT_CERTS_DIR}"
        rm -f "${OUT_CERTS_DIR}"
fi

# Generate into a staging dir and publish via atomic rename, so consumers never
# see a half-generated dir. Clean up the staging dir on failure.
FINAL_CERTS_DIR="${OUT_CERTS_DIR}"
OUT_CERTS_DIR="$(mktemp -d "${FINAL_CERTS_DIR}.tmp.XXXXXX")"
trap 'rm -rf "${OUT_CERTS_DIR}"' EXIT

##############################################
########## Software Signing PKI ##############

bash "${CERTS_DIR}/ssig_pki_generator.sh"
if [[ "${DO_PLATFORM_KEYS}" == "y" ]]; then
	bash "${CERTS_DIR}/sec_platform_keys.sh" --dbkey ssig_subca
fi


# copy generated test certificate and keys to out dir
for i in cert key; do
	mv "${CERTS_DIR}/"*."${i}" "${OUT_CERTS_DIR}"
done

if [[ "${DO_PLATFORM_KEYS}" == "y" ]]; then
	for i in esl crt auth; do
		mv "${CERTS_DIR}/"*."${i}" "${OUT_CERTS_DIR}"
	done
fi

##############################################
############### General PKI ##################

bash "${CERTS_DIR}/gen_pki_generator.sh" -p "${SELF_DIR}/test_passwd_env.bash"
bash "${CERTS_DIR}/gen_pki_backend_certs.sh" -p "${SELF_DIR}/test_passwd_env.bash"
bash "${CERTS_DIR}/gen_ocsp_certs.sh" -p "${SELF_DIR}/test_passwd_env.bash"

# copy generated test certificate and keys to out dir
for i in cert key; do
	mv "${CERTS_DIR}/"*."${i}" "${OUT_CERTS_DIR}"
done


##############################################
# cleanup temporary pki files
for i in txt old attr pem; do
	rm "${CERTS_DIR}/"*."${i}"
done

# Publish atomically (same filesystem -> single rename).
mv -T "${OUT_CERTS_DIR}" "${FINAL_CERTS_DIR}"
trap - EXIT

exit 0
