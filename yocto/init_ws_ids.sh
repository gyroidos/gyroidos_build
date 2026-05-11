#!/usr/bin/env bash
# Save caller's shell options — this script is sourced, not executed
{ _saved_setopts="$(set +o)"; _saved_shopt="$(shopt -po)"; } 2>/dev/null
set -euo pipefail +x
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2020 Fraunhofer AISEC
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

RUNDIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=common.sh
source "${RUNDIR}/common.sh"

SRC_DIR=$(pwd)
BUILD_DIR="${SRC_DIR}/${1:-}"
ARCH="${2:-x86}"
DEVICE="${3:-genericx86-64}"

[[ -n "${ARCH}" ]]   || { ewarn "\${ARCH} not set, falling back to x86";             ARCH="x86"; }
[[ -n "${DEVICE}" ]] || { ewarn "\${DEVICE} not set, falling back to genericx86-64"; DEVICE="genericx86-64"; }

einfo "Initializing workspace: BUILD_DIR=${BUILD_DIR}, ARCH=${ARCH}, DEVICE=${DEVICE}"

SKIP_CONFIG=0
if [[ -d "${BUILD_DIR}/conf" ]]; then
	SKIP_CONFIG=1
fi

export TEMPLATECONF="${SRC_DIR}/meta-gyroidos/conf/templates/default"
# oe-init-build-env doesn't tolerate nounset — suspend it for the duration
set +u
# shellcheck disable=SC1091
source "${SRC_DIR}/poky/oe-init-build-env" "${BUILD_DIR}"
set -u

if [[ "${DEVELOPMENT_BUILD:-}" == "n" ]]; then
	sed -i "s|##DEVELOPMENT_BUILD##|n|g" "${BUILD_DIR}/conf/local.conf"
else
	sed -i "s|##DEVELOPMENT_BUILD##|y|g" "${BUILD_DIR}/conf/local.conf"
	if [[ -n "${UPSTREAM_VERSION:-}" ]]; then
		UPSTREAM_VERSION="${UPSTREAM_VERSION} DEV Build"
	fi
fi

if [[ "${CC_MODE:-}" == "y" ]]; then
	sed -i "s|##CC_MODE##|y|g" "${BUILD_DIR}/conf/local.conf"
else
	sed -i "s|##CC_MODE##|n|g" "${BUILD_DIR}/conf/local.conf"
fi

sed -i "s|##UPSTREAM_VERSION##|${UPSTREAM_VERSION:-}|g" "${BUILD_DIR}/conf/local.conf"

if ! grep -q '##GYROIDOS_HARDWARE##' "${BUILD_DIR}/conf/local.conf"; then
	sed -i "s|##GYROIDOS_HARDWARE##|${ARCH}|g" "${BUILD_DIR}/conf/local.conf"
	sed -i "s|##MACHINE##|${DEVICE}|g" "${BUILD_DIR}/conf/local.conf"
	sed -i "s|##GYROIDOS_HARDWARE##|${ARCH}|g" "${BUILD_DIR}/conf/bblayers.conf"
	sed -i "s|##MACHINE##|${DEVICE}|g" "${BUILD_DIR}/conf/bblayers.conf"

	_lc="${BUILD_DIR}/conf/local.conf"
	if [[ "${ENABLE_SCHSM:-}" == "1" ]]; then sed -i 's/##GYROIDOS_SCHSM##/y/' "$_lc"; else sed -i 's/##GYROIDOS_SCHSM##/n/' "$_lc"; fi
	if [[ "${ENABLE_BNSE:-}" == "1" ]]; then sed -i 's/##GYROIDOS_BNSE##/y/' "$_lc"; else sed -i 's/##GYROIDOS_BNSE##/n/' "$_lc"; fi
	if [[ "${ENABLE_A_B_UPDATE:-}" == "1" ]]; then sed -i 's/##GYROIDOS_A_B_UPDATE##/y/' "$_lc"; else sed -i 's/##GYROIDOS_A_B_UPDATE##/n/' "$_lc"; fi
	if [[ "${GYROIDOS_SANITIZERS:-}" == "1" ]]; then sed -i 's/##GYROIDOS_SANITIZERS##/y/' "$_lc"; else sed -i 's/##GYROIDOS_SANITIZERS##/n/' "$_lc"; fi
	if [[ "${GYROIDOS_PLAIN_DATAPART:-}" == "1" ]]; then sed -i 's/##GYROIDOS_PLAIN_DATAPART##/y/' "$_lc"; else sed -i 's/##GYROIDOS_PLAIN_DATAPART##/n/' "$_lc"; fi

	elog "Configured: SCHSM=${ENABLE_SCHSM:-0} BNSE=${ENABLE_BNSE:-0} A/B=${ENABLE_A_B_UPDATE:-0} SANITIZERS=${GYROIDOS_SANITIZERS:-0} PLAIN_DATA=${GYROIDOS_PLAIN_DATAPART:-0}"
fi

if [[ "${DEVELOPMENT_BUILD:-}" != "n" ]]; then
	if [[ -z "${DEV_SSH_PUBKEY:-}" ]]; then
		sed -i "s/##DEV_SSH_PUBKEY##//" "${BUILD_DIR}/conf/local.conf"
	else
		sed -i "s|##DEV_SSH_PUBKEY##|${DEV_SSH_PUBKEY}|" "${BUILD_DIR}/conf/local.conf"
	fi
fi

einfo "Workspace ready: ${DEVELOPMENT_BUILD:-dev} build, ARCH=${ARCH}, MACHINE=${DEVICE}"

# Restore caller's shell options
eval "$_saved_setopts" 2>/dev/null
eval "$_saved_shopt" 2>/dev/null
unset _saved_setopts _saved_shopt
