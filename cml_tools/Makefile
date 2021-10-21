prefix = /usr/local
INSTALLDIR = $(DESTDIR)$(prefix)/share/cml-tools

all:
	: # do nothing

install: install_ressources install_build_script \
install_certs_script install_sign_script


install_ressources:
	install -d $(INSTALLDIR)
	cp -r ../device_provisioning $(INSTALLDIR)/
	cp -r ../config_overlay $(INSTALLDIR)/
	install -d $(INSTALLDIR)/osconfs
	install ./genericos_x86.sh $(INSTALLDIR)/
	install ./gen_guestos.sh $(INSTALLDIR)/

install_build_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed '7s:SCRIPTS_DIR=.*:SCRIPTS_DIR=$(INSTALLDIR):' \
		<./build_guestos_x86.sh > \
		$(DESTDIR)$(prefix)/bin/build_guestos_x86
	chmod +x $(DESTDIR)$(prefix)/bin/build_guestos_x86

install_certs_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed 's:INSTALLDIR:$(INSTALLDIR):' \
		<./gen_dev_certs_wrapper.sh > $(DESTDIR)$(prefix)/bin/gen_dev_certs
	chmod +x $(DESTDIR)$(prefix)/bin/gen_dev_certs

install_sign_script:
	install -d ${DESTDIR}$(prefix)/bin
	sed 's:INSTALLDIR:$(INSTALLDIR):' \
		<./sign_config_wrapper.sh > $(DESTDIR)$(prefix)/bin/sign_config
	chmod +x $(DESTDIR)$(prefix)/bin/sign_config

clean: 
	: # do nothing

distclean:
	: # do nothing

uninstall:
	rm -rf $(INSTALLDIR)
	rm -f $(DESTDIR)$(prefix)/bin/gen_dev_certs
	rm -f $(DESTDIR)$(prefix)/bin/sign_config
	rm -f $(DESTDIR)$(prefix)/bin/build_container_x86

.PHONY: all install clean distclean uninstall \
install_build_script install_certs_script install_sign_script \
install_ressources
