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

# A note on passing --cert arguments
#
# It is good practice to keep complete certificate chains in PEM formatted
# cert files as we do in our test PKI. This allows us to only pass a single
# --cert argument, cat that file into guestos.cert and have the complete chain
# there. We can accomplish the same behavior for CMS signing by just passing
# the signing certificate file as --certfile and have all the certificates in
# the file included in the message.
#
# For PKCS#11 tokens, we see the common behaviour that - even when using p11tool's
# --export-chain, we only get the leaf certificate, thus requiring us to
# explicitly state the chain-of-trust by passing multiple --cert arguments.
#
# We explicitly leave it up to the user to ensure not passing certificates
# multiple times if some of the files passed via --cert contain more than one
# certificate.

# A note on using RSA-PSS with PKCS#11 tokens
#
# It turns out, that OpenSSL providers are much pickier with regard to key types
# than their engine predecessors. Therefore, the openssl PKCS#11 provider will
# refuse to sign using RSA-PSS if not both, certificate and private key, report
# usage for PSS. For certificates, that's no issue. For private keys, the token
# needs to report allowed mechanisms RSA-PKCS-PSS,SHA256-RSA-PKCS-PSS,etc..
# To the best or our knowledge, neither scsh nor p11tool set these values! The
# only way to import the key on the token correctly configured is something like:
#
# $ openssl asn1parse -inform pem -in ssig_cml.key -strparse 20 -noout -out ssig_cml.raw
# $ pkcs11-tool --module /usr/lib64/libsofthsm2.so --login --pin 1234 \
# 	--write-object ssig_cml.raw --type privkey --label ssig_cml \
# 	--allowed-mechanisms RSA-PKCS-PSS,SHA256-RSA-PKCS-PSS,SHA384-RSA-PKCS-PSS,SHA512-RSA-PKCS-PSS

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
pkcs11_args_cms=()
if [[ "$key" == pkcs11:* ]]; then
	pkcs11_args=(-engine pkcs11 -keyform engine)
	pkcs11_args_cms=(-provider pkcs11 -provider default)
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

	openssl dgst "${pkcs11_args[@]}" \
		-sha512 \
		-sign "$key" \
		-sigopt rsa_padding_mode:pss \
		-sigopt rsa_pss_saltlen:-1 \
		-out "$sig" \
		"${pass_args[@]}" \
		"$cfg"

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

	KEYOPT=()
	if [[ -n "$(openssl x509 "${pkcs11_args_cms[@]}" "${pass_args[@]}" -in "${cert_sources[0]}" -text \
		| grep 'Public Key Algorithm: rsassaPss')" ]]; then
		KEYOPT=(-keyopt rsa_padding_mode:pss)
	fi

	openssl cms "${pkcs11_args_cms[@]}" "${pass_args[@]}" \
		-sign \
		-outform PEM \
		-md sha512 \
		-signer "${cert_sources[0]}" \
		-inkey "$key" \
		"${KEYOPT[@]}" \
		-out "$p7s" \
		-in "$cfg" \
		${cert_sources[@]/#/--certfile } # include all certs as --certfiles (chains added transparently)
}

# create signature
if [[ "$cms" = true ]]; then
	do_sign_cms
else
	do_sign_rsa_pss
fi
