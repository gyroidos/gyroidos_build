#!/bin/bash
#
# This file is part of trust|me
# Copyright(c) 2013 - 2021 Fraunhofer AISEC
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

set -e

PROGNAME="$(basename "$0")"
SCRIPTS_DIR="$(readlink -f "..")" # !!! this line will be replaced on installation !!!

# ROOTFS | INIT | SIGNOS
MODE=""

IMAGENAME=""
WORKDIR=$(pwd) # default: current directory
PROTO_FILE=""
DEFAULT_PROTO_PATH="/usr/share/cml"
CERT_DIR=""

usage () {
cat << _EOF_
usage: 
    ${PROGNAME} -h
    ${PROGNAME} init [-h] [--proto <path>] [--pki <path>] [--dir <directory>] <imagename>
    ${PROGNAME} build [-h] [--proto <path>] [--pki <path>] [--dir <directory>] <imagename>
    ${PROGNAME} sign [-h] [--proto <path>] [--pki <path>] [--dir <directory>] <path to config>

-h/--help: print this help

OPTIONAL:
    --proto <path>: specify path to directory containing guestos.proto, if not
                    specified either a installed one is taken or a new copy is
                    downloaded and placed in <dir>
    --pki <path>:   specify path to pki, if not specified a new one is generated
                    and placed in <dir>
    --dir <directory>: path to working directory

_EOF_
}

exit_failure () {
    echo "Error: ${1}" >&2
    exit 1
}

exit_failure_with_usage () {
    echo "Error: ${1}" >&2
    usage
    exit 1
}

### parse and validate cli args
## parse first arg
case "$1" in
    -h | --help)
        # print usage and exit
        usage
        exit 0
        ;;
    init)
        MODE=INIT
        ;;
    build)
        MODE=ROOTFS
        ;;
    sign)
        MODE=SIGNOS
        ;;
    *)
        exit_failure_with_usage "Unknown execution mode, exiting..."
        ;;
esac
[[ -n "$DEBUG" ]] && echo "MODE=$MODE" # DEBUG

## parse remaining args
shift
while [[ -n "$1" ]]; do
    case "$1" in
        -h | --help)
            # print usage and exit
            usage
            exit 0
            ;;
        --proto)
            # evaluate path arg
            shift
            if [[ -z "$1" || "$1" =~ ^"-".*$ ]]; then
                exit_failure_with_usage "No path to protofile specified, exiting..."
            elif [[ -f "$1" ]]; then
                if [[ "${1}" =~ ^.*".proto"$ ]]; then
                    PROTO_FILE="$(readlink -f "${1}")" # store absolute path
                    [[ -n "$DEBUG" ]] && echo "PROTO_FILE=$PROTO_FILE" # DEBUG
                else
                    exit_failure "${1} contains no guestos.proto file, exiting..."
                fi
            else 
                exit_failure "${1} does not exist or is not a directory, exiting..."
            fi
            ;;
        --pki)
            # evaluate path arg
            shift
            if [[ -z "$1" || "$1" =~ ^"-".*$ ]]; then
                exit_failure_with_usage "No path to pki specified, exiting..."
            elif [[ -d "$1" ]]; then
                CERT_DIR="$(readlink -f "${1}")" # store absolute path
                [[ -n "$DEBUG" ]] && echo "CERT_DIR=$CERT_DIR" # DEBUG
            else 
                exit_failure "${1} does not exist or is not a directory, exiting..."
            fi
            ;;
        --dir)
            # evaluate path arg
            shift
            if [[ -z "$1" || "$1" =~ ^"-".*$ ]]; then
                exit_failure_with_usage "No path to working directory specified, exiting..."
            elif [[ -d "$1" ]]; then
                WORKDIR="$(readlink -f "${1}")" # store absolute path
                [[ -n "$DEBUG" ]] && echo "WORKDIR=$WORKDIR" # DEBUG
            else 
                exit_failure "${1} does not exist or is not a directory, exiting..."
            fi
            ;;
        -*)
            exit_failure_with_usage "Unknown Flag, exiting..."
            ;;
        *)
            if [[ -z "$IMAGENAME" ]]; then
                # TODO: sanitize
                IMAGENAME="${1}"
                [[ -n "$DEBUG" ]] && echo "IMAGENAME=${1}" # DEBUG
            else
                exit_failure_with_usage "Too many positional arguments, exiting..."
            fi
            ;;
    esac
    shift
done

## check if positional arguments are set
# check if imagename is set
if [[ -z "$IMAGENAME" ]]; then
    exit_failure_with_usage "No imagename specified, exiting..."
fi

## check for necessary build files
# check for guestos.proto
if [[ -z "$PROTO_FILE" ]]; then
    # check if guestos.proto is installed with cmld
    if [[ -f "${DEFAULT_PROTO_PATH}/guestos.proto" ]]; then
        echo "Use guestos.proto in $DEFAULT_PROTO_PATH"
        PROTO_FILE="${DEFAULT_PROTO_PATH}/guestos.proto"
    elif [[ -e "${WORKDIR}/guestos.proto" ]];then
        echo "Use guestos.proto at ${WORKDIR}/guestos.proto"
        PROTO_FILE=="${WORKDIR}/guestos.proto"
    else
        echo "guestos.proto is not installed on this system."
        # prombt user
        while true; do
            read -p "Download guestos.proto from GitHub? [y/n]: "
            if [[ "$REPLY" == "y" ]]; then
                # try to download it
                echo "Try to download latest guestos.proto..."
                wget \
                    https://github.com/trustm3/device_fraunhofer_common_cml/raw/trustx-master/daemon/guestos.proto \
                    -O "${WORKDIR}"/guestos.proto
                PROTO_FILE="${WORKDIR}"
                if [[ ! -f "$PROTO_FILE/guestos.proto" ]]; then
                    exit_failure "Download failed -> no guestos.proto available, exiting..."
                fi
                echo "Download successful -> use ${PROTO_FILE}/guestos.proto"

                # break out of loop
                break
            elif [[ "$REPLY" == "n" ]]; then
                exit_failure "no guestos.proto specified, please install cmld or provide a path to guestos.proto"
            else
                echo "invalid input, try again..."
                continue
            fi
        done
    fi
elif [[ ! -e "${WORKDIR}/guestos.proto" ]]; then
    # make symbolic link to given guestos.proto
    ln -s "$PROTO_FILE" "${WORKDIR}/guestos.proto"
fi
[[ -n "$DEBUG" ]] && echo "PROTO_FILE=$PROTO_FILE" # DEBUG

# check for pki
if [[ -z "${CERT_DIR}" ]]; then
    if [[ -e "${WORKDIR}/test_pki" ]]; then
        echo "Using PKI at ${WORKDIR}/test_pki"
        CERT_DIR="${WORKDIR}/test_pki"
    else
        # prombt user
        echo "No PKI specified."
        while true; do
            read -p "Generate new PKI? [y/n]: "
            if [[ "$REPLY" == "y" ]]; then
                # generate new one
                CERT_DIR="${WORKDIR}/test_pki"
                cml_gen_dev_certs "${CERT_DIR}" # ! corresponds to cml_gen_dev_certs_wrapper.sh

                # break out of loop
                break
            elif [[ "$REPLY" == "n" ]]; then
                exit_failure "no pki specified, please provide a path using the --pki <path> flag"
            else
                echo "invalid input, try again..."
                continue
            fi
        done
    fi
elif [[ ! -e "${WORKDIR}/test_pki" ]]; then
    ln -s "${CERT_DIR}" "${WORKDIR}/test_pki"
fi
[[ -n "$DEBUG" ]] && echo "CERT_DIR=${CERT_DIR}" # DEBUG

### MODE-related functions
## initialise the working directory
init_wdir() {
    mkdir -p ${WORKDIR}/conf
    mkdir -p ${WORKDIR}/rootfs
    mkdir -p ${WORKDIR}/out
    cp ${SCRIPTS_DIR}/sampleos.conf ${WORKDIR}/conf/${IMAGENAME}os.conf
    cp ${SCRIPTS_DIR}/samplecontainer.conf ${WORKDIR}/conf/${IMAGENAME}container.conf
    sed -i "s:sampleos:${IMAGENAME}os:" ${WORKDIR}/conf/${IMAGENAME}os.conf ${WORKDIR}/conf/${IMAGENAME}container.conf
    sed -i "1s:samplecontainer:${IMAGENAME}container:" ${WORKDIR}/conf/${IMAGENAME}container.conf
}

## generate guestos
build_guestos () {
    ROOTFS_OUT=${WORKDIR}/rootfs
    PROTO_FILE_DIR=${WORKDIR}
    TMP_SCRIPTS_DIR=${WORKDIR}/.cml-tools

    cp -r ${SCRIPTS_DIR} ${TMP_SCRIPTS_DIR}

    bash "${TMP_SCRIPTS_DIR}/gen_guestos.sh" \
        "${WORKDIR}/conf/${IMAGENAME}os.conf" \
        "${IMAGENAME}" \
        "${ROOTFS_OUT}/${IMAGENAME}os.tar" \
        "${TMP_SCRIPTS_DIR}" \
        "${PROTO_FILE_DIR}" \
        "${CERT_DIR}" \
        "${WORKDIR}"

    rm -r ${TMP_SCRIPTS_DIR}
}

## sign a guestos
sign_guestos() {
    echo "Signing GuestOS config: ${IMAGENAME}"
    # TODO: proper path eval to guestos
    cml_sign_config \
        "${IMAGENAME}" \
        "${CERT_DIR}/ssig_cml.key" \
        "${CERT_DIR}/ssig_cml.cert"
}

### switch over MODE
case "$MODE" in
    INIT)
        init_wdir
        ;;
    ROOTFS)
        build_guestos
        ;;
    SIGNOS)
        sign_guestos
        ;;
    *)
        ;;
esac