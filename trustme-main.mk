#
# This file is part of trust|me
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
# Fraunhofer AISEC <trustme@aisec.fraunhofer.de>
#

SHELL := /bin/bash

TRUSTME_VERSION := $(shell date +%Y%m%d)
WORKDIR := $(shell pwd)
OUTDIR := $(WORKDIR)/out-trustme
AOSP_DIR := $(WORKDIR)
CFG_OVERLAY_DIR := $(WORKDIR)/trustme/build/config_overlay
SHARED_DATA_DIR := $(WORKDIR)/trustme/build/shared
CONFIG_CREATOR_DIR := $(WORKDIR)/trustme/build/config_creator
PROTO_FILE_DIR := $(WORKDIR)/device/fraunhofer/common/cml/daemon
PROVISIONING_DIR := $(WORKDIR)/trustme/build/device_provisioning
ENROLLMENT_DIR := $(PROVISIONING_DIR)/oss_enrollment
TEST_CERT_DIR := $(PROVISIONING_DIR)/test_certificates

################################################################
# CERT_DIR : directory on code signing machine which contains  #
#         the real software signing cert and keys              #
#        !! overwrite this by jenkins build script !!          #
################################################################
ifndef $(CERT_DIR)
CERT_DIR = $(TEST_CERT_DIR)
endif

# 32 GB (hammerhead)
#BOARD_USERDATAIMAGE_PARTITION_SIZE := 29236373504
# 16 GB (hammerhead)
BOARD_USERDATAIMAGE_PARTITION_SIZE := 13725837312
# 16 GB (x86)
BOARD_USERDATAIMAGE_PARTITION_SIZE_x86 := 13725837312

# set device from name of used manifest
ifndef $(DEVICE)
ifeq ($(shell uname),Linux)
DEVICE := $(shell readlink -f .repo/manifest.xml | awk -F "/" '{gsub('/.xml/', ""); print $$NF}' | awk -F "-" '{print $$2}')
else ifeq ($(shell uname),Darwin)
DEVICE := $(shell greadlink -f .repo/manifest.xml | awk -F "/" '{gsub('/.xml/', ""); print $$NF}' | awk -F "-" '{print $$2}')
#DEVICE := $(shell readlink -f .repo/manifest.xml | xargs basename | sed 's/trustme-//' | sed 's/.xml//')
endif
endif

#directory where all final images for deployment are located
FINAL_OUT := $(OUTDIR)/target/$(DEVICE)

AOSP_CML_LUNCH_COMBO:= "trustme_$(DEVICE)_cml-userdebug"
ifeq ($(DEVICE), bullhead)
AOSP_AX_LUNCH_COMBO := "trustme_$(DEVICE)_aX-userdebug"
AOSP_A0_LUNCH_COMBO := "trustme_$(DEVICE)_a0-userdebug"
else
AOSP_AX_LUNCH_COMBO := "trustme_$(DEVICE)_aX-user"
AOSP_A0_LUNCH_COMBO := "trustme_$(DEVICE)_a0-user"
endif

KERNEL_OUT := $(OUTDIR)/kernel/$(DEVICE)
KERNEL_DIR := $(AOSP_DIR)/device/fraunhofer/trustme_$(DEVICE)-kernel

TARGET_IMAGE_DIR := /data/trustme/images

################################################################
# TESTING DIRECTIVES                                           #
################################################################

# target and host test out directory
UNIT_TEST_TARGET_OUT_DIR := $(WORKDIR)/out-cml/target/product/trustme_$(DEVICE)_cml/system/bin
UNIT_TEST_HOST_OUT_DIR := $(WORKDIR)/out-cml/host/linux-x86/bin

# unit test list: ADD UNIT TESTS HERE
UNIT_TEST_TARGETS := \
	trustme.cml.common.mem.test \
	trustme.cml.common.str.test \
	trustme.cml.common.logf.test \
	trustme.cml.common.list.test \
	trustme.cml.common.nl.test.host \
	trustme.cml.uuid.test.host \
	trustme.cml.control.test \
	trustme.cml.common.event.test \
	trustme.cml.c_net.test

#################################################################
# DOXYGEN PATHS							#
#################################################################

# Doxyfile location
DOXYFILE_DIR := $(WORKDIR)/trustme/build

# Doxygen output directory
DOXYGEN_OUT_DIR := $(OUTDIR)/doxygen

#################################################################

.PHONY:	clean \
	aosp_a0_files \
	aosp_full_files \
	kernel-$(DEVICE) \
	cml_ramdisk \
	binaries-$(DEVICE) \
	aosp_a0_dist \
	aosp_full_dist \
	aosp_a0_system \
	aosp_ax_system \
	aosp_a0_root \
	aosp_ax_root \
	aosp_a0 \
	aosp_ax \
	snapshot \
	finalize_build \
	all \
	unit_tests \
	unit_test_start \
	unit_test_list \
	unit_test_end \
	doxygen_docu \
	deploy_images \
	sign_software \
	prepare_shared_images \
	push_shared_images \
	cts

all: binaries-$(DEVICE) \
	kernel-$(DEVICE) \
	cml_ramdisk \
	aosp_a0_system \
	aosp_a0_root \
	aosp_a0_image \
	aosp_ax_system \
	aosp_ax_root \
	aosp_ax_image \
	prepare_shared_images \
	userdata_image \
	finalize_build \
	sign_software

NPROCS:=1

ifeq ($(shell uname),Linux)
	NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)

	gen_temp_dir=$(shell mktemp -d)

	KERNEL_TOOLCHAIN:=$(AOSP_DIR)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-
	KERNEL64_TOOLCHAIN:=$(AOSP_DIR)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
	MKEXT4IMAGE_AOSP:=$(AOSP_DIR)/out-cml/host/linux-x86/bin/make_ext4fs
	ADB_AOSP:=$(AOSP_DIR)/out-cml/host/linux-x86/bin/adb
	MKSQUASHFS:=$(AOSP_DIR)/out-cml/host/linux-x86/bin/mksquashfs
	MKBOOTIMG:=$(AOSP_DIR)/out/host/linux-x86/bin/mkbootimg
	SIM2IMG=$(AOSP_DIR)/out-cml/host/linux-x86/bin/simg2img

else ifeq ($(shell uname),Darwin)
	NPROCS:=$(shell sysctl hw.ncpu | awk '{print $$2}')

	gen_temp_dir=$(shell mktemp -d -t trustme)
	CM_ADDITIONAL_ENV=export BUILD_MAC_SDK_EXPERIMENTAL=1;

	KERNEL_TOOLCHAIN:=$(AOSP_DIR)/prebuilts/gcc/darwin-x86/arm/arm-eabi-4.8/bin/arm-eabi-
	MKEXT4IMAGE_AOSP:=$(AOSP_DIR)/out-cml/host/darwin-x86/bin/make_ext4fs
	MKBOOTIMG:=$(AOSP_DIR)/out/host/darwin-x86/bin/mkbootimg
	SIM2IMG=$(AOSP_DIR)/out/host/darwin-x86/bin/simg2img
endif

MAKE:=make -j $(NPROCS)

###################################################
# INCLUDE DIST targets after all VARS ar set      #
###################################################
include $(WORKDIR)/trustme/build/trustme-dist.mk
include $(WORKDIR)/trustme/build/trustme-ids.mk
###################################################

aosp_a0_files: $(TEST_CERT_DIR)/dev.user.adbkey
	cd $(AOSP_DIR) && source build/envsetup.sh && lunch $(AOSP_A0_LUNCH_COMBO) && m -j$(NPROCS) files

aosp_full_files: $(TEST_CERT_DIR)/dev.user.adbkey
	@for i in GmsCore GsfProxy FakeStore; do \
	   mkdir -p $(AOSP_DIR)/out-aosp/target/common/obj/APPS/$${i}_intermediates ; \
	done
	cd $(AOSP_DIR) && source build/envsetup.sh && lunch $(AOSP_AX_LUNCH_COMBO) && m -j$(NPROCS) files

$(FINAL_OUT):
	@mkdir -p $(FINAL_OUT)

aosp_a0_system: aosp_a0_files
	@mkdir -p $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0/system
	@mkdir -p $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)
	ln -sf ../boot.img $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)/boot.img
	rsync -a --delete $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/system/ $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0/system/
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_*_a0
	@for i in telephony camera gps; do \
	   bash $(WORKDIR)/trustme/build/remove-system-files.sh a0 $${i} $(CFG_OVERLAY_DIR)/$(DEVICE) \
	      $(OUTDIR)/aosp/trustme_$(DEVICE) $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0 ; \
	done
	@echo "-----------------------------------------------------------------------"
	@echo "ro.trustme.version=$(TRUSTME_VERSION)" >> $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0/system/build.prop

aosp_ax_system: aosp_full_files
	@mkdir -p $(FINAL_OUT)/axos-$(TRUSTME_VERSION)
	@mkdir -p $(OUTDIR)/aosp/trustme_$(DEVICE)/system_aX/system
	rsync -a --delete $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/system/ $(OUTDIR)/aosp/trustme_$(DEVICE)/system_aX/system/
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_*_aX
	@for i in telephony camera generic gps bluetooth fhgapps; do \
	   bash $(WORKDIR)/trustme/build/remove-system-files.sh aX $${i} $(CFG_OVERLAY_DIR)/$(DEVICE) \
	      $(OUTDIR)/aosp/trustme_$(DEVICE) $(OUTDIR)/aosp/trustme_$(DEVICE)/system_aX ; \
	done
	# copy some additional prebuild apks which should appear in feature_fhgapps.img (usually mounted in a1)
	if [ -d $(WORKDIR)/trustme/build/fhgapps ]; then \
		rsync -a $(WORKDIR)/trustme/build/fhgapps/*  $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_fhgapps_aX/system ; \
	else \
		mkdir -p $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_fhgapps_aX/system ; \
	fi
	@echo "-----------------------------------------------------------------------"
	@echo "ro.trustme.version=$(TRUSTME_VERSION)" >> $(OUTDIR)/aosp/trustme_$(DEVICE)/system_aX/system/build.prop


aosp_a0_image: $(MKSQUASHFS) $(FINAL_OUT)
	$(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0/system $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)/system.img \
	   -noappend -comp gzip -b 131072 -android-fs-config -mount-point system \
	   -context-file $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/root/file_contexts \
	   -product-out $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/system

aosp_ax_image: $(MKSQUASHFS) $(FINAL_OUT)
	@echo "-----------------------------------------------------------------------"
	@echo " Installing GApps in $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_gapps_aX "
	@echo "-----------------------------------------------------------------------"
	bash $(WORKDIR)/trustme/build/extract-gapps.sh $(WORKDIR)/trustme/build/gapps/open_gapps*.zip $(OUTDIR)/aosp/trustme_$(DEVICE)/feature_gapps_aX
	@echo "-----------------------------------------------------------------------"
	@echo " Building images "
	@echo "-----------------------------------------------------------------------"
	@for i in system feature_telephony feature_camera feature_generic feature_gps feature_bluetooth feature_fhgapps feature_gapps; do \
	   $(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/$${i}_aX $(FINAL_OUT)/axos-$(TRUSTME_VERSION)/$${i}.img \
	      -noappend -comp gzip -b 131072 -android-fs-config -mount-point / \
	      -context-file $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/root/file_contexts \
	      -product-out $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/system ; \
	done

aosp_a0_root: $(MKSQUASHFS) $(FINAL_OUT)
	@mkdir -p $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0
	@mkdir -p $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)
	rsync -a --delete $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/root/ $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0/
	@echo "-----------------------------------------------------------------------"
	@echo " Overlaying root with a0 specific contents from $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_a0/"
	@echo "-----------------------------------------------------------------------"
	@find $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_a0/
	@echo "-----------------------------------------------------------------------"
	rsync -av $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_a0/ $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0/
	$(CFG_OVERLAY_DIR)/$(DEVICE)/squashfs/prepare.sh $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0
	$(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0 $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)/root.img \
	   -noappend -comp gzip -b 131072 -android-fs-config -mount-point / \
	   -context-file $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0/file_contexts \
	   -product-out $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/system

aosp_ax_root: $(MKSQUASHFS) $(FINAL_OUT)
	@mkdir -p $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX
	@mkdir -p $(FINAL_OUT)/axos-$(TRUSTME_VERSION)
	rsync -a --delete-before $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/root/ $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX/
	@echo "-----------------------------------------------------------------------"
	@echo " Overlaying root with aX specific contents from $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_aX/"
	@echo "-----------------------------------------------------------------------"
	@find $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_aX/
	@echo "-----------------------------------------------------------------------"
	rsync -av $(CFG_OVERLAY_DIR)/$(DEVICE)/rootdir_aX/ $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX/
	$(CFG_OVERLAY_DIR)/$(DEVICE)/squashfs/prepare.sh $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX
	$(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX $(FINAL_OUT)/axos-$(TRUSTME_VERSION)/root.img \
	   -noappend -comp gzip -b 131072 -android-fs-config -mount-point / \
	   -context-file $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX/file_contexts \
	   -product-out $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/system


aosp_a0_clean:
	$(RM) -r $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/root_a0*
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/system_a0*
	$(RM) -r $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/root*
	$(RM) -r $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/system*

aosp_ax_clean:
	$(RM) -r $(FINAL_OUT)/axos-$(TRUSTME_VERSION)
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/root_aX*
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/system_aX*
	$(RM) -r $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/root*
	$(RM) -r $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/system*

#################
# CML           #
#################

cml_ramdisk_clean:
	$(RM) $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/boot.img
	$(RM) $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/ramdisk.img
	$(RM) $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/recovery.img
	$(RM) $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/ramdisk-recovery.img
	$(RM) -r $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/root
	$(RM) -r $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/recovery
	$(RM) $(FINAL_OUT)/boot.img
	$(RM) $(FINAL_OUT)/recovery.img

cml_ramdisk: cml_ramdisk_clean kernel-$(DEVICE) $(FINAL_OUT)
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m -j$(NPROCS) bootimage recoveryimage make_ext4fs adb mksquashfs simg2img_host cml-service-container
	cp $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/boot.img $(FINAL_OUT)
	cp $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/ramdisk.img $(FINAL_OUT)
	cp $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/recovery.img $(FINAL_OUT)

#################
# Kernel        #
#################

kernel-hammerhead:
	@mkdir -p $(KERNEL_OUT)/obj
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm SUBARCH=arm CROSS_COMPILE=$(KERNEL_TOOLCHAIN) $(DEVICE)_defconfig
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm SUBARCH=arm CROSS_COMPILE=$(KERNEL_TOOLCHAIN)

kernel-deb:
	@mkdir -p $(KERNEL_OUT)/obj
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm SUBARCH=arm CROSS_COMPILE=$(KERNEL_TOOLCHAIN) flo_defconfig
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm SUBARCH=arm CROSS_COMPILE=$(KERNEL_TOOLCHAIN)

kernel-x86: $(FINAL_OUT)
	@mkdir -p $(KERNEL_OUT)/obj
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj x86_trustme_defconfig
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj LOCALVERSION=
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj INSTALL_MOD_PATH=$(KERNEL_OUT)/$(DEVICE)-modules modules_install
	$(RM) $(KERNEL_OUT)/obj/source
	cd $(KERNEL_OUT) && $(RM) $(DEVICE)-modules/lib/modules/*/source
	cd $(KERNEL_OUT) && tar cjf $(DEVICE)-modules.tar.bz2 $(DEVICE)-modules/
	cp $(KERNEL_OUT)/obj/arch/x86/boot/bzImage $(FINAL_OUT)/

kernel-bullhead:
	@mkdir -p $(KERNEL_OUT)/obj
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$(KERNEL64_TOOLCHAIN) bullhead_defconfig
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT)/obj ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$(KERNEL64_TOOLCHAIN)

#################
# Misc          #
#################
binaries-$(DEVICE):
	@if [ -f trustme/build/extract-vendor-img-$(DEVICE).sh ]; then \
		bash trustme/build/extract-vendor-img-$(DEVICE).sh ; \
	fi

$(MKSQUASHFS):
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m -j$(NPROCS) mksquashfs

$(MKEXT4IMAGE_AOSP):
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m -j$(NPROCS) make_ext4fs

cts:
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m -j$(NPROCS) cts

$(TEST_CERT_DIR)/dev.user.adbkey: $(FINAL_OUT)
	@if [ ! -d $(TEST_CERT_DIR) ]; then \
		ANDROID_BUILD=true bash $(PROVISIONING_DIR)/gen_dev_certs.sh ; \
	fi

userdata_image: $(TEST_CERT_DIR)/dev.user.adbkey $(FINAL_OUT)
	$(eval $@_TMPDIR := $(gen_temp_dir))
	mkdir -p $($@_TMPDIR)/mnt/cml
	cp $(CFG_OVERLAY_DIR)/$(DEVICE)/device.conf $($@_TMPDIR)/mnt/cml/
	mkdir -p $($@_TMPDIR)/mnt/misc/adb
	cp $(TEST_CERT_DIR)/dev.user.adbkey.pub $($@_TMPDIR)/mnt/misc/adb/adb_keys
	@echo Pushing initial certificates for debug build to avoid provisioning
	mkdir -p $($@_TMPDIR)/mnt/cml/tokens
	# do not change filenames, as they are used in scd.c and in device_provisioning/test_certificates and device_provisioning/configs
	cp -v $(CERT_DIR)/ssig_rootca.cert $($@_TMPDIR)/mnt/cml/tokens/ssig_rootca.cert
	# for initial environment, the certificates originate from the same chain
	cp -v $(CERT_DIR)/gen_rootca.cert $($@_TMPDIR)/mnt/cml/tokens/gen_rootca.cert

ifeq ($(DEVICE), x86)
	$(MKEXT4IMAGE_AOSP) -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE_x86) -a data $(FINAL_OUT)/userdata.img $($@_TMPDIR)/mnt
else
	#$(MKEXT4IMAGE_AOSP) -s -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE) -a data $(FINAL_OUT)/userdata.img $($@_TMPDIR)/mnt
	$(MKEXT4IMAGE_AOSP) -s -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE) -a data -v -S $(AOSP_DIR)/out-cml/target/product/trustme_$(DEVICE)_cml/root/file_contexts $(FINAL_OUT)/userdata.img $($@_TMPDIR)/mnt
endif
	rm -rf $($@_TMPDIR)

prepare_shared_images: $(FINAL_OUT)
	@echo Creating shared images
	mkdir -p $(FINAL_OUT)/shared/
	if [ -d $(SHARED_DATA_DIR) ]; then \
		for dir in $(SHARED_DATA_DIR)/*; do \
			$(MKSQUASHFS) $$dir $(FINAL_OUT)/shared/$$(basename $$dir).img -noappend -comp gzip -b 131072 -android-fs-config -mount-point data/media; \
		done; \
	fi;

push_shared_images:
	@echo Pushing shared images
	adb root
	@for i in $(FINAL_OUT)/shared/* ; do \
	   adb push -p $$i /data/cml/shared ; \
	done

finalize_build: $(FINAL_OUT) $(prepare_shared_images)
	cp $(PROTO_FILE_DIR)/container.proto $(FINAL_OUT)
	cp -v $(TEST_CERT_DIR)/dev.user.adbkey $(FINAL_OUT)/adbkey
	@for i in a0 ax; do \
	   bash $(WORKDIR)/trustme/build/extract-radio-img-$(DEVICE).sh $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION)/modem.img ; \
	   if [ -f "$(WORKDIR)/vendor/lge/$(DEVICE)/proprietary/vendor.img" ]; then \
	      ${SIM2IMG} $(WORKDIR)/vendor/lge/bullhead/proprietary/vendor.img $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION)/vendor.img ; \
	   fi ;\
	done

sign_software: $(FINAL_OUT)
	@echo ----------------------------------------------------------------------------
	@echo   Signing software - guestOSs
	@echo ----------------------------------------------------------------------------
	protoc --python_out=$(ENROLLMENT_DIR)/config_creator -I$(PROTO_FILE_DIR) $(PROTO_FILE_DIR)/guestos.proto
	@for i in a0 ax; do \
	   python $(ENROLLMENT_DIR)/config_creator/guestos_config_creator.py \
	     -b $(CFG_OVERLAY_DIR)/$(DEVICE)/$${i}os.conf -v $(TRUSTME_VERSION) \
	     -c $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION).conf \
	     -i $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION)/ -n $${i}os ; \
	   bash $(ENROLLMENT_DIR)/config_creator/sign_config.sh $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION).conf \
	      $(CERT_DIR)/ssig.key $(CERT_DIR)/ssig.cert $(SIG_KEY_PASS); \
	done
	rm $(ENROLLMENT_DIR)/config_creator/guestos_pb2.py*

deploy_cml:
	@echo ----------------------------------------------------------------------------
	@echo   Deploying cml images on device $(DEVICE)
	@echo ----------------------------------------------------------------------------
	bash $(ENROLLMENT_DIR)/device_resign.sh --images $(FINAL_OUT) -p $(PROTO_FILE_DIR) -c $(CERT_DIR) -s $(CFG_OVERLAY_DIR)/$(DEVICE)/a0os.conf
	bash $(ENROLLMENT_DIR)/device_update.sh --images $(FINAL_OUT) -k

deploy_a0:
	@echo ----------------------------------------------------------------------------
	@echo   Installing container a0 images on device $(DEVICE)
	@echo ----------------------------------------------------------------------------
	bash $(ENROLLMENT_DIR)/deploy_containers.sh --images $(FINAL_OUT) --os a0

deploy_ax:
	@echo ----------------------------------------------------------------------------
	@echo   Installing oparating system ax images on device $(DEVICE)
	@echo ----------------------------------------------------------------------------
	bash $(ENROLLMENT_DIR)/deploy_containers.sh --images $(FINAL_OUT) --os ax

deploy_images:
	@echo ----------------------------------------------------------------------------
	@echo   Installing container images on device $(DEVICE)
	@echo ----------------------------------------------------------------------------
	bash $(ENROLLMENT_DIR)/deploy_containers.sh --images $(FINAL_OUT) --auto 20,80

clean:
	rm -rf $(OUTDIR)
	rm -rf $(FINAL_OUT)
	cd $(KERNEL_DIR) && $(MAKE) clean CROSS_COMPILE=$(KERNEL_TOOLCHAIN) ARCH=arm SUBARCH=arm

mrproper: clean
	@rm -rf $(AOSP_DIR)/out-a0
	@rm -rf $(AOSP_DIR)/out-aosp
	@rm -rf $(AOSP_DIR)/out-cml
	@echo Removed $(AOSP_DIR)/out-a0, $(AOSP_DIR)/out-aosp, $(AOSP_DIR)/out-cml

integration_test:
	cd testing/integration-tests/ && ./run_tests.sh $(phone)

DATE := $(shell date +%Y%m%d)
STATUS ?= UNKNOWN
snapshot:
	cd trustme/manifest && git fetch --all && git checkout -b snapshot trustme-gerrit/snapshot
	# TODO iterate over all manifests for different devices, do a `repo init -m trustme-<device>.xml` with them and the following command with custom output name
	repo manifest -r -o trustme/manifest/trustme-$(DEVICE)-snapshot-$(DATE)-$(PLATFORM_VER).xml
	# TODO do git add for all new snapshot files
	cd trustme/manifest && git add trustme-$(DEVICE)-snapshot-$(DATE)-$(PLATFORM_VER).xml && git commit -m "Manifest file of snapshot for Android $(PLATFORM_VER) from $(DATE) added (Build $(STATUS))" && git push


doxygen_docu:
	@mkdir -p $(OUTDIR)
	@doxygen $(DOXYFILE_DIR)/Doxyfile
	@echo "setting draft option in hyperref package of refman.tex"
	@cd $(DOXYGEN_OUT_DIR)/latex && sed -i -e 's/]{hyperref}/,draft &/g' refman.tex
	@cd $(DOXYGEN_OUT_DIR)/latex && make
	@cp $(DOXYGEN_OUT_DIR)/latex/refman.pdf $(DOXYGEN_OUT_DIR)/specification.pdf
	@cd $(DOXYGEN_OUT_DIR) && tar czf specification.tar.gz html
	@rm -rf $(DOXYGEN_OUT_DIR)/latex

doxygen_link:
	@mkdir -p $(OUTDIR)
	@doxygen $(DOXYFILE_DIR)/Doxyfile
	@cd $(DOXYGEN_OUT_DIR)/latex && make
	@cp $(DOXYGEN_OUT_DIR)/latex/refman.pdf $(DOXYGEN_OUT_DIR)/specification.pdf
	@cd $(DOXYGEN_OUT_DIR) && tar czf specification.tar.gz html
	@rm -rf $(DOXYGEN_OUT_DIR)/latex

######################
# UNIT TESTS         #
######################
unit_tests: unit_test_start \
        unit_test_list \
        unit_test_end

unit_test_list: $(UNIT_TEST_TARGETS)

unit_test_start:
	@echo -------------------------------------------------------------
	@echo EXECUTE FOLLOWING UNIT TEST HOST TARGETS:
	@echo $(UNIT_TEST_TARGETS)
	@echo -------------------------------------------------------------
	@echo START BUILDING AND EXECUTING TESTS:
ifdef UNIT_TEST_TARGETS
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m $(UNIT_TEST_TARGETS)
else
	@echo no unit test targets defined
endif
unit_test_end:
	@echo -------------------------------------------------------------
	@echo SUCCESSFULLY PASSED ALL UNIT TESTS

trustme.cml.%.test.host:
	$(UNIT_TEST_HOST_OUT_DIR)/$@

trustme.cml.%.test:
	trustme/build/qemu-arm-static $(UNIT_TEST_TARGET_OUT_DIR)/$@
