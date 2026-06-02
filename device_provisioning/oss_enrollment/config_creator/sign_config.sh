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

usage() {
	echo "Usage: $0 -c <config> -k <key> --cert <cert> [--cert <cert> ...] [-p <pass>] [--cms]" >&2
	exit 1
}

cfg=""
key=""
cert_sources=()
pass=""
cms=false

while (( $# > 0 )); do
	case "$1" in
		-c|--config)
			cfg="$2"; shift 2 ;;
		-k|--key)
			key="$2"; shift 2 ;;
		--cert)
			cert_sources+=("$2"); shift 2 ;;
		-p|--pass)
			pass="$2"; shift 2 ;;
		--cms)
			cms=true; shift ;;
		*)
			echo "Unknown option: $1" >&2; usage ;;
	esac
done

if [[ -z "$cfg" || -z "$key" || ${#cert_sources[@]} -eq 0 ]]; then
	usage
fi

# check if key is a PKCS#11 URI and set openssl args accordingly
pkcs11_args=()
if [[ "$key" == pkcs11:* ]]; then
	pkcs11_args=(-engine pkcs11 -keyform engine)
fi

# check if passphrase is supplied from caller
if [[ -z "$pass" ]]; then
	# shellcheck source=/dev/null
	source "${SELF_DIR}/../../test_passwd_env.bash"
	pass_args=(-passin env:GYROIDOS_TEST_PASSWD_PKI)
else
	pass_args=(-passin "pass:$pass")
fi

do_sign_rsa_pss () {
	cert=${cfg%.conf}.cert
	sig=${cfg%.conf}.sig

	openssl dgst "${pkcs11_args[@]}" -sha512 -sign "$key" -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -out "$sig" "${pass_args[@]}" "$cfg"

	openssl_err=$?
	if [ "${openssl_err}" -ne 0 ]; then
		echo "Openssl Error: Wrong PW?"
		exit "${openssl_err}"
	fi

	# copy software signing certificate
	rm -f "$cert"
	for c in "${cert_sources[@]}"; do
		if [[ "$c" == pkcs11:* ]]; then
			p11tool --provider "$PKCS11_MODULE_PATH" --export-chain "$c" >> "$cert"
		else
			cat "$c" >> "$cert"
		fi
	done
}

do_sign_cms () {
	p7s=${cfg%.conf}.p7s
	# chain includes all certificates but the actual signing certificates
	chain=("${cert_sources[@]:1}")

	KEYOPT=()
	if [[ -n "$(openssl x509 -in "${cert_sources[0]}" -text | grep 'Public Key Algorithm: rsassaPss')" ]]; then
		KEYOPT=(-keyopt rsa_padding_mode:pss)
	fi

	openssl cms -sign \
		-outform PEM \
		-md sha512 \
		-signer "${cert_sources[0]}" \
		-inkey "$key" \
		"${KEYOPT[@]}" \
		-out "$p7s" \
		-in "$cfg" \
		${chain[@]/#/--certfile }
}

# create signature
if [[ "$cms" = true ]]; then
	do_sign_cms
else
	do_sign_rsa_pss
fi
