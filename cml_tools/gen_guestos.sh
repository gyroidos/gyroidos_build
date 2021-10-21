#!/bin/bash

OSTMPL=$1
OSNAME=$2
ROOTFS_TARBALL="$3"
TRUSTME_VERSION="1"

SCRIPT_DIR="$4"
DEPLOY_DIR_IMAGE="$7/out"
TRUSTME_HARDWARE="x86"


CFG_OVERLAY_DIR="${SCRIPT_DIR}/config_overlay"
CONFIG_CREATOR_DIR="${SCRIPT_DIR}/config_creator"
PROTO_FILE_DIR="$5"
PROVISIONING_DIR="${SCRIPT_DIR}/device_provisioning"
ENROLLMENT_DIR="${PROVISIONING_DIR}/oss_enrollment"
TEST_CERT_DIR="$6"

GUESTOS_OUT="${DEPLOY_DIR_IMAGE}/trustx-guests"


do_sign_guestos () {
    name=${1}
    rootfs=${2}
    protoc --python_out=${ENROLLMENT_DIR}/config_creator \
        -I${PROTO_FILE_DIR} ${PROTO_FILE_DIR}/guestos.proto
    if [ ! -d ${GUESTOS_OUT} ]; then
        mkdir -p ${GUESTOS_OUT}
    fi
    if [ ! -d ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION} ]; then
        mkdir -p ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION}/
    fi

    tmpdir=$(mktemp -u -d)
    fakeroot -- bash -c "\
        mkdir -p ${tmpdir} &&\
        tar -xvf ${rootfs} -C ${tmpdir} &&\
        mksquashfs ${tmpdir} \
            ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION}/root.img -noappend &&\
        rm -r ${tmpdir}"

   echo "${OSTMPL}" 
    python ${ENROLLMENT_DIR}/config_creator/guestos_config_creator.py \
        -b ${OSTMPL} -v ${TRUSTME_VERSION} \
        -c ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION}.conf \
        -i ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION}/ -n ${name}os
    sign_config \
        ${GUESTOS_OUT}/${name}os-${TRUSTME_VERSION}.conf \
        ${TEST_CERT_DIR}/ssig.key ${TEST_CERT_DIR}/ssig.cert

    rm ${ENROLLMENT_DIR}/config_creator/guestos_pb2.py*
}

mkdir -p ${DEPLOY_DIR_IMAGE}
mkdir -p ${PROTO_FILE_DIR}

echo do_sign_guestos ${OSNAME} ${ROOTFS_TARBALL}
do_sign_guestos ${OSNAME} ${ROOTFS_TARBALL}
