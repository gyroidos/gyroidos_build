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

# cml_tools/Makefile: contains rules in order to install helper-scripts for trust|me guestos generation.
# The default installation path is '/usr/local' and can be set via the 'prefix' and 'DESTDIR'
# environment variables.
# In general the cml_tools debian-package should be preferred for installation.

prefix = /usr/local
INSTALLDIR = $(DESTDIR)$(prefix)/share/cml-tools
SCRIPTS_DIR = $(INSTALLDIR)

all:
	: # do nothing

install: install_ressources install_build_script \
install_certs_script install_sign_script


install_ressources:
	install -d $(INSTALLDIR)
	cp -r ../device_provisioning $(INSTALLDIR)/
	cp -r ../config_overlay/arm $(INSTALLDIR)/config_overlay
	cp -r ../config_overlay/x86 $(INSTALLDIR)/config_overlay
	cp ../config_overlay/*.conf $(INSTALLDIR)/config_overlay
	install -d $(INSTALLDIR)/osconfs
	install ./sampleos.conf $(INSTALLDIR)/
	install ./samplecontainer.conf $(INSTALLDIR)/
	install ./gen_guestos.sh $(INSTALLDIR)/

install_build_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed '0,/SCRIPTS_DIR=.*/s:SCRIPTS_DIR=.*:SCRIPTS_DIR=$(SCRIPTS_DIR):' \
		<./cml_build_guestos.sh > \
		$(DESTDIR)$(prefix)/bin/cml_build_guestos
	chmod +x $(DESTDIR)$(prefix)/bin/cml_build_guestos

install_certs_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed '0,/SCRIPTS_DIR=.*/s:SCRIPTS_DIR=.*:SCRIPTS_DIR=$(SCRIPTS_DIR):' \
		<./cml_gen_dev_certs_wrapper.sh > $(DESTDIR)$(prefix)/bin/cml_gen_dev_certs
	chmod +x $(DESTDIR)$(prefix)/bin/cml_gen_dev_certs

install_sign_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed '0,/SCRIPTS_DIR=.*/s:SCRIPTS_DIR=.*:SCRIPTS_DIR=$(SCRIPTS_DIR):' \
		<./cml_sign_config_wrapper.sh > $(DESTDIR)$(prefix)/bin/cml_sign_config
	chmod +x $(DESTDIR)$(prefix)/bin/cml_sign_config

clean: 
	: # do nothing

distclean:
	: # do nothing

uninstall:
	rm -rf $(INSTALLDIR)
	rm -f $(DESTDIR)$(prefix)/bin/cml_gen_dev_certs
	rm -f $(DESTDIR)$(prefix)/bin/cml_sign_config
	rm -f $(DESTDIR)$(prefix)/bin/cml_build_guestos

.PHONY: all install clean distclean uninstall \
install_build_script install_certs_script install_sign_script \
install_ressources
