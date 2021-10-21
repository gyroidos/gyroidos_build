#!/bin/bash

set -e

# Simple testing script for cli
PROGNAME="$(basename "$0")"
SCRIPTS_DIR="$(readlink -f ".")"
# ROOTFS | DOCKER | INIT
MODE=""

IMAGENAME=""
WORKDIR=""
PROTO_FILE_DIR=""
DEFAULT_PROTO_PATH="/usr/share/cml"
CERT_DIR=""

usage () {
cat << _EOF_
usage: ${PROGNAME} -i | -r | -d [--proto <path>] [--pki <path>] <imagename> <dir>

-i/--init: initialize working directory
-r/--rootfs: build from rootfs
-d/--docker: build from docker image

OPTIONAL:
    --proto <path>: specify path to directory containing guestos.proto, if not
                    specified either a installed one is taken or a new copy is
                    downloaded and placed in <dir>
    --pki <path>:   specify path to pki, if not specified a new one is generated
                    and placed in <dir>

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

if (( $# < 3 )); then
    exit_failure_with_usage "Too few arguments, exiting..."
fi

# parse cli args
while [[ -n "$1" ]]; do
    case "$1" in
        -i | --init)
            if [[ -z "$MODE" ]]; then
                MODE=INIT
                echo "MODE=$MODE" # DEBUG
            else 
                exit_failure_with_usage "Too many flags specified, exiting..."
            fi
            ;;
        -r | --rootfs)
            if [[ -z "$MODE" ]]; then
                MODE=ROOTFS
                echo "MODE=$MODE" # DEBUG
            else 
                exit_failure_with_usage "Too many flags specified, exiting..."
            fi
            ;;
        -d | --docker)
            if [[ -z "$MODE" ]]; then
                MODE=DOCKER
                echo "MODE=$MODE" # DEBUG
            else 
                exit_failure_with_usage "Too many flags specified, exiting..."
            fi
            ;;
        --proto)
            # evaluate path arg
            shift
            if [[ -z "$1" || "$1" =~ ^"-".*$ ]]; then
                exit_failure_with_usage "No path to protofile specified, exiting..."
            elif [[ -d "$1" ]]; then
                if [[ -f "${1}/guestos.proto" ]]; then
                    PROTO_FILE_DIR="$(readlink -f "${1}")" # store absolute path
                    echo "PROTO_FILE_DIR=$PROTO_FILE_DIR" # DEBUG
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
                echo "CERT_DIR=$CERT_DIR" # DEBUG
            else 
                exit_failure "${1} does not exist or is not a directory, exiting..."
            fi
            ;;
        -*)
            exit_failure_with_usage "Unknown Flag, exiting..."
            ;;
        *)
            if [[ -z "$IMAGENAME" ]]; then
                # TODO sanitize
                IMAGENAME="${1}"
                echo "IMAGENAME=${1}" # DEBUG
            elif [[ -z "$WORKDIR" ]]; then
                if [[ ! -d "$1" ]]; then
                    exit_failure "$1 is not a directory, exiting..."
                fi
                WORKDIR="$(readlink -f "${1}")" # store absolute path
                echo "WORKDIR=$WORKDIR" # DEBUG
            else
                exit_failure_with_usage "Too many positional arguments, exiting..."
            fi
            ;;
    esac
    shift
done

## check positional arguments
# check if imagename is set
if [[ -z "$IMAGENAME" ]]; then
    exit_failure_with_usage "No imagename specified, exiting..."
fi

# check if workdir is set
if [[ -z "$WORKDIR" ]]; then
    #WORKDIR="$PWD"
    #echo "WORKDIR=$WORKDIR" # DEBUG
    exit_failure_with_usage "No workdirectory specified, exiting..."
fi

## check for necessary build files
# check for guestos.proto
if [[ -z "$PROTO_FILE_DIR" ]]; then
    # check if guestos.proto is installed with cmld
    if [[ -f "${DEFAULT_PROTO_PATH}/guestos.proto" ]]; then
        echo "Use guestos.proto in $DEFAULT_PROTO_PATH"
        PROTO_FILE_DIR="${DEFAULT_PROTO_PATH}/guestos.proto"
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
                PROTO_FILE_DIR="${WORKDIR}"
                if [[ ! -f "$PROTO_FILE_DIR/guestos.proto" ]]; then
                    exit_failure "Download failed -> no guestos.proto available, exiting..."
                fi
                echo "Download successful -> use ${PROTO_FILE_DIR}/guestos.proto"

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
fi
echo "PROTO_FILE_DIR=$PROTO_FILE_DIR" # DEBUG

# check for pki
if [[ -z "$CERT_DIR" ]]; then
    # generate new one
    CERT_DIR="${WORKDIR}/test_pki"
    gen_dev_certs "${CERT_DIR}"
fi
echo "CERT_DIR=${CERT_DIR}"

## set variables for gen_guestos()
ROOTFS_OUT=${WORKDIR}/rootfs
TME_CONTAINER_OUT=${WORKDIR}/trustme_containers
PROVISIONING_DIR=${SCRIPTS_DIR}/device_provisioning

#exports pre-built docker containers as root filesystem
#export_docker_img() {
#    echo "Exporting image ${2} as $(basename ${IMAGENAME})"
#    #docker build --platform arm64 -t bootstrapper_arm64v8 src/bootstrapper/ -f 
#    #src/bootstrapper/Dockerfile.arm64v8
#    container_id="$(docker create ${2})"
#    echo created temporay container ${container_id}
#    mkdir -p ${ROOTFS_OUT}
#    rm -f ${ROOTFS_OUT}/${IMAGENAME}.tar
#    docker export ${container_id} -o ${ROOTFS_OUT}/${IMAGENAME}.tar
#    docker rm ${container_id}
#}

init_wdir() {
    # TODO: autogenerate/provide valid example.conf
    mkdir -p ${WORKDIR}/osconf
    mkdir -p ${WORKDIR}/rootfs
    echo "# config file" > ${WORKDIR}/osconf/${IMAGENAME}.conf
}

build_guestos () {
    bash "${SCRIPTS_DIR}/gen_guestos.sh" \
        "${WORKDIR}/osconfs/${IMAGENAME}.conf" \
        "${IMAGENAME}" \
        "${ROOTFS_OUT}/${IMAGENAME}.tar" \
        "${SCRIPTS_DIR}" \
        "${PROTO_FILE_DIR}" \
        "${TEST_CERT_DIR}" \
        "${WORKDIR}"
}
# switch over MODE
case "$MODE" in
    DOCKER)
        echo NOP
        ;;
    INIT)
        init_wdir
        ;;
    ROOTFS)
        build_guestos
        ;;
    *)
        ;;
esac
