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

##############################
# GNU (debian) IDS container #
##############################
ids-all: \
	kernel-$(DEVICE) \
	cml_ramdisk \
	ids_image \
	ids_sign \
	ids_userdata_image

CML_SERVICE_CONTAINER = out-cml/target/product/trustme_$(DEVICE)_cml/root/sbin/cml-service-container
CML_TPM2_CONTROL_CONTAINER = out-cml/target/product/trustme_$(DEVICE)_cml/root/sbin/tpm2-control

CML_TRUSTX_CONVERTER_HOST = out-cml/host/linux-x86/bin/converter

$(CML_TPM2_CONTROL_CONTAINER):
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m $@

$(CML_SERVICE_CONTAINER):
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m $@

$(CML_TRUSTX_CONVERTER_HOST):
	source build/envsetup.sh && lunch $(AOSP_CML_LUNCH_COMBO) && m $@

IMAGE_HOST = https://trustme-vpn/trustme
DEBIAN_TARBALL = debian_$(DEVICE)_container_tarballs.tar.gz
IDS_TARBALL = external/trusted-connector/karaf-assembly/target/offline-karaf-1.1.0-SNAPSHOT.tar.gz

TRUSTX_CONVERTER_DIR = /tmp/trustx-converter/trustx_image
TRUSTX_CONVERTER_JAVA_IMG = library_openjdk
TRUSTX_CONVERTER_JAVA_IMG_TAG = 8
TRUSTX_CONVERTER_IMG = $(TRUSTX_CONVERTER_DIR)/trustx_image/library/openjdk

$(IDS_TARBALL):
	cd external/trusted-connector && mvn clean install -DskipITs -DskipTests -DskipDocker

$(OUTDIR)/ids/trustme_$(DEVICE)/$(DEBIAN_TARBALL):
	@mkdir -p $(OUTDIR)/ids/trustme_$(DEVICE)
	wget --no-check-certificate $(IMAGE_HOST)/prebuilt_container/$(DEBIAN_TARBALL) -O $(OUTDIR)/ids/trustme_$(DEVICE)/$(DEBIAN_TARBALL)
	tar xvf $(OUTDIR)/ids/trustme_$(DEVICE)/$(DEBIAN_TARBALL) -C $(OUTDIR)/ids/trustme_$(DEVICE)
	@for i in $(OUTDIR)/ids/trustme_$(DEVICE)/*.tar.gz ; do \
	   (cd $(OUTDIR)/ids/trustme_$(DEVICE) && tar -xzf $$i) ; \
	done
	#wget $(IMAGE_HOST)/prebuild-container/$(IDS_TARBALL) -O $(OUTDIR)/ids/$(IDS_TARBALL)

ids_image: $(OUTDIR)/ids/trustme_$(DEVICE)/$(DEBIAN_TARBALL) $(IDS_TARBALL) $(MKSQUASHFS) $(MKEXT4IMAGE_AOSP) $(FINAL_OUT) $(CML_SERVICE_CONTAINER) $(CML_TPM2_CONTROL_CONTAINER)
	@mkdir -p $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)
	##cp $(CML_SERVICE_CONTAINER) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root/sbin/
	cp $(CML_TPM2_CONTROL_CONTAINER) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root/sbin/
	$(MKSQUASHFS) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_root.img -all-root -noappend -comp gzip -b 131072
	$(MKEXT4IMAGE_AOSP) -l 100663296 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_etc.img $(OUTDIR)/ids/trustme_$(DEVICE)/debian_etc
	$(RM) -r $(OUTDIR)/ids/trustme_$(DEVICE)/debian_var/cache/apt
	$(MKEXT4IMAGE_AOSP) -l 134217728 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_var.img $(OUTDIR)/ids/trustme_$(DEVICE)/debian_var
	mkdir -p $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core
	tar xvzf $(IDS_TARBALL) -C $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core --strip-components=1
	$(MKEXT4IMAGE_AOSP) -l 536870912 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/ids-core.img $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core

#$(TRUSTX_CONVERTER_DIR)/$(TRUSTX_CONVERTER_JAVA_IMG)-$(TRUSTX_CONVERTER_JAVA_IMG_TAG)_extracted:

ids_image_docker: $(TRUSTX_CONVERTER_DIR)/$(TRUSTX_CONVERTER_JAVA_IMG)_$(TRUSTX_CONVERTER_JAVA_IMG_TAG)_extracted $(MKSQUASHFS) $(MKEXT4IMAGE_AOSP) $(CML_TRUSTX_CONVERTER_HOST) $(FINAL_OUT) $(CML_SERVICE_CONTAINER) $(CML_TPM2_CONTROL_CONTAINER)
	@mkdir -p $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)
	rsync -ar --exclude 'var/*' --exclude 'etc/*' $(TRUSTX_CONVERTER_DIR)/$(TRUSTX_CONVERTER_JAVA_IMG)_$(TRUSTX_CONVERTER_JAVA_IMG_TAG)_extracted/ $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root
	rsync -ar $(TRUSTX_CONVERTER_DIR)/$(TRUSTX_CONVERTER_JAVA_IMG)_$(TRUSTX_CONVERTER_JAVA_IMG_TAG)_extracted/etc/ $(OUTDIR)/ids/trustme_$(DEVICE)/debian_etc
	rsync -ar $(TRUSTX_CONVERTER_DIR)/$(TRUSTX_CONVERTER_JAVA_IMG)_$(TRUSTX_CONVERTER_JAVA_IMG_TAG)_extracted/var/ $(OUTDIR)/ids/trustme_$(DEVICE)/debian_var
	cp $(CML_SERVICE_CONTAINER) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root/sbin/
	cp $(CML_TPM2_CONTROL_CONTAINER) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root/sbin/
	$(MKSQUASHFS) $(OUTDIR)/ids/trustme_$(DEVICE)/debian_root $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_root.img -all-root -noappend -comp gzip -b 131072
	$(MKEXT4IMAGE_AOSP) -l 100663296 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_etc.img $(OUTDIR)/ids/trustme_$(DEVICE)/debian_etc
	$(RM) -r $(OUTDIR)/ids/trustme_$(DEVICE)/debian_var/cache/apt
	$(MKEXT4IMAGE_AOSP) -l 134217728 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/debian_var.img $(OUTDIR)/ids/trustme_$(DEVICE)/debian_var
	mkdir -p $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core
	tar xvzf $(IDS_TARBALL) -C $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core --strip-components=1
	$(MKEXT4IMAGE_AOSP) -l 536870912 $(FINAL_OUT)/idsos-$(TRUSTME_VERSION)/ids-core.img $(OUTDIR)/ids/trustme_$(DEVICE)/ids-core

# this is only a demo image with a prebuild cml-service-container inside
DEBIAN_FULL_IMG = debian_$(DEVICE)_root_x11.img

$(OUTDIR)/deb/trustme_$(DEVICE)/$(DEBIAN_FULL_IMG):
	@mkdir -p $(OUTDIR)/deb/trustme_$(DEVICE)
	wget --no-check-certificate $(IMAGE_HOST)/prebuilt_container/$(DEBIAN_FULL_IMG).bz2 -O $(OUTDIR)/deb/trustme_$(DEVICE)/$(DEBIAN_FULL_IMG).bz2
	bunzip2 $(OUTDIR)/deb/trustme_$(DEVICE)/$(DEBIAN_FULL_IMG).bz2

debian_full_image: $(OUTDIR)/deb/trustme_$(DEVICE)/$(DEBIAN_FULL_IMG) $(FINAL_OUT)
	@mkdir -p $(FINAL_OUT)/debos-$(TRUSTME_VERSION)
	cp $(OUTDIR)/deb/trustme_$(DEVICE)/$(DEBIAN_FULL_IMG) $(FINAL_OUT)/debos-$(TRUSTME_VERSION)/debian_root.img


#IDS_UUID = $(shell cat /proc/sys/kernel/random/uuid)
#ids_core_config:
#	rm -rf $(FINAL_OUT)/ids_config
#	mkdir -p $(FINAL_OUT)/ids_config
#	echo trustme_version: $(TRUSTME_VERSION) > $(FINAL_OUT)/ids_config/$(IDS_UUID).conf
#	cat $(CFG_OVERLAY_DIR)/ids-core.conf >> $(FINAL_OUT)/ids_config/$(IDS_UUID).conf
#
#ids_core_push_config:
#	adb push $(FINAL_OUT)/ids_config/*.conf /data/cml/containers/

ids_sign: $(FINAL_OUT)
	@echo ----------------------------------------------------------------------------
	@echo   Signing ids - guestOSs
	@echo ----------------------------------------------------------------------------
	protoc --python_out=$(ENROLLMENT_DIR)/config_creator -I$(PROTO_FILE_DIR) $(PROTO_FILE_DIR)/guestos.proto
	@for i in ids deb; do \
	   python $(ENROLLMENT_DIR)/config_creator/guestos_config_creator.py \
	     -b $(CFG_OVERLAY_DIR)/$(DEVICE)/$${i}os.conf -v $(TRUSTME_VERSION) \
	     -c $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION).conf \
	     -i $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION)/ -n $${i}os ; \
	   bash $(ENROLLMENT_DIR)/config_creator/sign_config.sh $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION).conf \
	      $(CERT_DIR)/ssig.key $(CERT_DIR)/ssig.cert $(SIG_KEY_PASS); \
	done
	rm $(ENROLLMENT_DIR)/config_creator/guestos_pb2.py*
	cp $(PROTO_FILE_DIR)/container.proto $(FINAL_OUT)

ids_userdata_image: $(TEST_CERT_DIR)/dev.user.adbkey $(FINAL_OUT)
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
	mkdir -p $($@_TMPDIR)/mnt/cml/operatingsystems
	@for i in ids deb; do \
	   cp -rv $(FINAL_OUT)/$${i}os-$(TRUSTME_VERSION)* $($@_TMPDIR)/mnt/cml/operatingsystems ; \
	done

ifeq ($(DEVICE), x86)
	$(MKEXT4IMAGE_AOSP) -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE_x86) -a data $(FINAL_OUT)/userdata_ids.img $($@_TMPDIR)/mnt
else
	$(MKEXT4IMAGE_AOSP) -s -l $(BOARD_USERDATAIMAGE_PARTITION_SIZE) -a data $(FINAL_OUT)/userdata_ids.img $($@_TMPDIR)/mnt
endif
	rm -rf $($@_TMPDIR)

deploy_ids:
	@echo ----------------------------------------------------------------------------
	@echo   Installing container ids images on device $(DEVICE)
	@echo ----------------------------------------------------------------------------
	bash $(ENROLLMENT_DIR)/deploy_containers.sh --images $(FINAL_OUT) --os ids

ids-clean:
	$(RM) -r external/trusted-connector/target
