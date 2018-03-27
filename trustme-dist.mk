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

PHONY:	dist-all \
	dist-sign \
	aosp_a0_sign \
	aosp_aX_sign \
	aosp_dist

dist-all: binaries-$(DEVICE) \
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
	aosp_dist

dist-sign: \
	aosp_a0_sign \
	aosp_aX_sign \
	sign_software \
	userdata_image

$(AOSP_DIR)/out-a0/dist/trustme_$(DEVICE)_a0-target_files-*.zip :
	cd $(AOSP_DIR) && source build/envsetup.sh && lunch $(AOSP_A0_LUNCH_COMBO) && m -j$(NPROCS) dist

$(AOSP_DIR)/out-aosp/dist/trustme_$(DEVICE)_aX-target_files-*.zip:
	cd $(AOSP_DIR) && source build/envsetup.sh && lunch $(AOSP_AX_LUNCH_COMBO) && m -j$(NPROCS) dist

$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/unsigned.zip : UNSIGNED_DIR = $(patsubst %.zip,%,$@)
$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/unsigned.zip : $(AOSP_DIR)/out-a0/dist/trustme_$(DEVICE)_a0-target_files-*.zip
	$(RM) -r $(UNSIGNED_DIR)
	mkdir -p $(UNSIGNED_DIR)
	cp $(AOSP_DIR)/out-a0/dist/*-target_files-*.zip $@
	( cd $(UNSIGNED_DIR) && unzip $@ SYSTEM/build.prop )
	@echo "ro.trustme.version=$(TRUSTME_VERSION)" >> $(UNSIGNED_DIR)/SYSTEM/build.prop
	( cd $(UNSIGNED_DIR) && zip -r $@ SYSTEM/build.prop )

$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/unsigned.zip : UNSIGNED_DIR = $(patsubst %.zip,%,$@)
$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/unsigned.zip : $(AOSP_DIR)/out-aosp/dist/trustme_$(DEVICE)_aX-target_files-*.zip
	$(RM) -r $(UNSIGNED_DIR)
	mkdir -p $(UNSIGNED_DIR)
	cp $(AOSP_DIR)/out-aosp/dist/*-target_files-*.zip $@
	( cd $(UNSIGNED_DIR) && unzip $@ SYSTEM/build.prop )
	@echo "ro.trustme.version=$(TRUSTME_VERSION)" >> $(UNSIGNED_DIR)/SYSTEM/build.prop
	( cd $(UNSIGNED_DIR) && zip -r $@ SYSTEM/build.prop )

$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed.zip:
	@echo ----------------------------------------------------------------------------
	@echo   Signing aosp $@
	@echo ----------------------------------------------------------------------------
	ln -sf out-a0 out
	./build/tools/releasetools/sign_target_files_apks -d $(CERT_DIR) $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/unsigned.zip $@
	rm out

$(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed.zip:
	@echo ----------------------------------------------------------------------------
	@echo   Signing aosp $@
	@echo ----------------------------------------------------------------------------
	ln -sf out-aosp out
	./build/tools/releasetools/sign_target_files_apks -d $(CERT_DIR) $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/unsigned.zip $@
	rm out

aosp_dist: $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/unsigned.zip $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/unsigned.zip

aosp_a0_sign: SIGNED_DIR = $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed
aosp_a0_sign: $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed.zip
	@echo ----------------------------------------------------------------------------
	@echo  Rebuild signed aosp a0 system images
	@echo ----------------------------------------------------------------------------
	$(RM) -r $(SIGNED_DIR)
	mkdir -p $(SIGNED_DIR)/system_a0
	( cd $(SIGNED_DIR)/system_a0 && unzip $< SYSTEM/* && mv SYSTEM system )
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/feature_*_a0
	for i in camera gps; do \
	   bash $(WORKDIR)/trustme/build/remove-system-files.sh a0 $${i} $(CFG_OVERLAY_DIR)/$(DEVICE) \
	      $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed/system_a0 ; \
	done
	$(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_a0/signed/system_a0/system $(FINAL_OUT)/a0os-$(TRUSTME_VERSION)/system.img \
	   -noappend -comp gzip -b 131072 -android-fs-config -mount-point system \
	   -context-file $(AOSP_DIR)/out-a0/target/product/trustme_$(DEVICE)_a0/root/file_contexts

aosp_aX_sign: SIGNED_DIR = $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed
aosp_aX_sign: $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed.zip
	@echo ----------------------------------------------------------------------------
	@echo  Rebuild signed aosp ax system images
	@echo ----------------------------------------------------------------------------
	$(RM) -r $(SIGNED_DIR)
	mkdir -p $(SIGNED_DIR)/system_aX
	( cd $(SIGNED_DIR)/system_aX && unzip $< SYSTEM/* && mv SYSTEM system)
	$(RM) -r $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/feature_*_aX
	for i in telephony camera generic gps bluetooth fhgapps; do \
	   bash $(WORKDIR)/trustme/build/remove-system-files.sh aX $${i} $(CFG_OVERLAY_DIR)/$(DEVICE) \
	      $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed/system_aX ; \
	done
	if [ -d $(WORKDIR)/trustme/build/fhgapps ]; then \
	   rsync -a $(WORKDIR)/trustme/build/fhgapps/*  $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed/feature_fhgapps_aX/system ; \
	fi
	for i in system feature_telephony feature_camera feature_generic feature_gps feature_bluetooth feature_fhgapps; do \
	   $(MKSQUASHFS) $(OUTDIR)/aosp/trustme_$(DEVICE)/dist_aX/signed/$${i}_aX $(FINAL_OUT)/axos-$(TRUSTME_VERSION)/$${i}.img \
	      -noappend -comp gzip -b 131072 -android-fs-config -mount-point / \
	      -context-file $(AOSP_DIR)/out-aosp/target/product/trustme_$(DEVICE)_aX/root/file_contexts ; \
	done
