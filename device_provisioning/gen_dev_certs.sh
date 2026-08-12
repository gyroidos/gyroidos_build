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
KEY_TYPE="rsa:4096"

OUT_CERTS_DIR="${1:-${SELF_DIR}/test_certificates}"
KEY_TYPE="${2:-${KEY_TYPE}}"

# Derived, format-converted exports of already generated material. Only
# creates missing files, never overwrites - safe to run on a seeded release
# PKI, where format conversions are wanted but generation is forbidden.
# - certs/signing_key.{pem,x509}: kernel module signing key/cert
#   (CONFIG_MODULE_SIG_KEY expects key + cert concatenated in one PEM file)
# - PK.cer: DER variant of the UEFI platform key certificate
derive_exports() {
	local dir="$1"
	if [[ -f "${dir}/ssig_subca.cert" ]]; then
		mkdir -p "${dir}/certs"
		if [[ ! -f "${dir}/certs/signing_key.x509" ]]; then
			openssl x509 -in "${dir}/ssig_subca.cert" -outform DER -out "${dir}/certs/signing_key.x509"
		fi
		if [[ -f "${dir}/ssig_subca.key" && ! -f "${dir}/certs/signing_key.pem" ]]; then
			cat "${dir}/ssig_subca.key" > "${dir}/certs/signing_key.pem"
			openssl x509 -in "${dir}/ssig_subca.cert" -outform PEM >> "${dir}/certs/signing_key.pem"
		fi
	fi
	if [[ -f "${dir}/PK.crt" && ! -f "${dir}/PK.cer" ]]; then
		openssl x509 -in "${dir}/PK.crt" -outform DER -out "${dir}/PK.cer"
	fi
}

# Multiple recipes/multiconfigs and the pki-bootstrap event handler invoke
# this concurrently with the same OUT_CERTS_DIR. Serialize on a dedicated
# lock; losing racers see the atomically published dir and exit early.
exec 9>"${OUT_CERTS_DIR}.genlock"
flock 9

if [[ -L "${OUT_CERTS_DIR}" ]]; then
    # Jenkinsfile seeded an external PKI (PKI_PATH). Use it; NEVER generate over it
    # (that would self-sign a release with throwaway keys). Fail loud if it's broken.
    echo "${BASH_SOURCE[0]} called on release PKI '$(readlink "${OUT_CERTS_DIR}")', only deriving exports." >&2
    derive_exports "${OUT_CERTS_DIR}"
    exit 0
fi
if [[ -d "${OUT_CERTS_DIR}" ]]; then
	if [[ "${DO_PLATFORM_KEYS}" == "y" && ! -f "${OUT_CERTS_DIR}/DB.auth" ]]; then
		# Second phase: add the UEFI platform keys to an already published
		# PKI. The ssig certs are generated separately (and earlier, with
		# only openssl available); this phase additionally needs efitools
		# (cert-to-efi-sig-list/sign-efi-sig-list). Runs under the genlock;
		# consumers of the platform keys are ordered behind this call.
		cp "${OUT_CERTS_DIR}/ssig_subca.cert" "${CERTS_DIR}/"
		bash "${CERTS_DIR}/sec_platform_keys.sh" -k "${KEY_TYPE}" --dbkey ssig_subca
		rm "${CERTS_DIR}/ssig_subca.cert"
		for i in esl crt auth key; do
			mv "${CERTS_DIR}/"*."${i}" "${OUT_CERTS_DIR}"
		done
		echo "UEFI platform keys added to ${OUT_CERTS_DIR}"
	else
		echo "Test Certificates already generated!"
	fi
	derive_exports "${OUT_CERTS_DIR}"
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

bash "${CERTS_DIR}/ssig_pki_generator.sh" -k "${KEY_TYPE}"
if [[ "${DO_PLATFORM_KEYS}" == "y" ]]; then
	bash "${CERTS_DIR}/sec_platform_keys.sh" -k "${KEY_TYPE}" --dbkey ssig_subca
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

bash "${CERTS_DIR}/gen_pki_generator.sh" -k "${KEY_TYPE}" -p "${SELF_DIR}/test_passwd_env.bash"
bash "${CERTS_DIR}/gen_pki_backend_certs.sh" -k "${KEY_TYPE}" -p "${SELF_DIR}/test_passwd_env.bash"
bash "${CERTS_DIR}/gen_ocsp_certs.sh" -k "${KEY_TYPE}" -p "${SELF_DIR}/test_passwd_env.bash"

# copy generated test certificate and keys to out dir
for i in cert key; do
	mv "${CERTS_DIR}/"*."${i}" "${OUT_CERTS_DIR}"
done


##############################################
# cleanup temporary pki files
for i in txt old attr pem; do
	rm "${CERTS_DIR}/"*."${i}"
done

derive_exports "${OUT_CERTS_DIR}"

# Publish atomically (same filesystem -> single rename).
mv -T "${OUT_CERTS_DIR}" "${FINAL_CERTS_DIR}"
trap - EXIT

exit 0
