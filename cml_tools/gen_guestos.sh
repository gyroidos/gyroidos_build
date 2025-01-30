#!/bin/bash
#
# This file is part of GyroidOS
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
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

OSTMPL=$1
OSNAME=$2
ROOTFS_TARBALL="$3"
GYROIDOS_VERSION="1"

SCRIPT_DIR="$4"
DEPLOY_DIR_IMAGE="$7/out"
GYROIDOS_HARDWARE="x86"


CFG_OVERLAY_DIR="${SCRIPT_DIR}/config_overlay"
CONFIG_CREATOR_DIR="${SCRIPT_DIR}/config_creator"
PROTO_FILE_DIR="$5"
PROVISIONING_DIR="${SCRIPT_DIR}/device_provisioning"
ENROLLMENT_DIR="${PROVISIONING_DIR}/oss_enrollment"
TEST_CERT_DIR="$6"

GUESTOS_OUT="${DEPLOY_DIR_IMAGE}/gyroidos-guests"


do_sign_guestos () {
    name=${1}
    rootfs=${2}
    protoc --python_out=${ENROLLMENT_DIR}/config_creator \
        -I${PROTO_FILE_DIR} ${PROTO_FILE_DIR}/guestos.proto
    if [ ! -d ${GUESTOS_OUT} ]; then
        mkdir -p ${GUESTOS_OUT}
    fi
    if [ ! -d ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION} ]; then
        mkdir -p ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/
    fi

    tmpdir=$(mktemp -u -d)
    fakeroot -- bash -c "\
        mkdir -p ${tmpdir} &&\
        tar -xvf ${rootfs} -C ${tmpdir} &&\
        mksquashfs ${tmpdir} \
            ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/root.img -noappend &&\
        rm -r ${tmpdir}"

        echo "${OSTMPL}"

        dd if=/dev/zero of=${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/root.hash.img bs=1M count=10

        root_hash=$(veritysetup format ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/root.img \
                    ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/root.hash.img | \
                    grep 'Root hash:' | \
                    cut -d ":" -f2 | \
                    tr -d '[:space:]')

    python3 ${ENROLLMENT_DIR}/config_creator/guestos_config_creator.py \
        -b ${OSTMPL} -v ${GYROIDOS_VERSION} \
        -c ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}.conf \
        -i ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}/ -n ${name}os \
        -d ${root_hash}
    cml_sign_config \
        ${GUESTOS_OUT}/${name}os-${GYROIDOS_VERSION}.conf \
        ${TEST_CERT_DIR}/ssig_cml.key ${TEST_CERT_DIR}/ssig_cml.cert

    rm ${ENROLLMENT_DIR}/config_creator/guestos_pb2.py*
}

mkdir -p ${DEPLOY_DIR_IMAGE}
mkdir -p ${PROTO_FILE_DIR}

echo do_sign_guestos ${OSNAME} ${ROOTFS_TARBALL}
do_sign_guestos ${OSNAME} ${ROOTFS_TARBALL}
