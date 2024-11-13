CONFIG_FILES = \
	jobs/examples/obs-server.yml\
	jobs/examples/sles11sp3.yml\
	jobs/examples/obs-server-26.yml\
	jobs/remove-domain.yml\
	logging/default.conf\
	logging/console.conf\
        logging/network-setup.conf

FULL_DIRS	= bin share/migrations share/fixtures
CONFIG_DIRS		= \
	etc/kanku/dancer\
	etc/kanku/jobs\
	etc/kanku/job_groups\
	etc/kanku/jobs/examples\
	etc/kanku/logging

TEMPLATE_DIRS = \
	etc/kanku/templates\
	etc/kanku/templates/cmd\
	etc/kanku/templates/cmd/init\
	etc/kanku/templates/cmd/setup\
	etc/kanku/templates/cmd/setup/etc\
	etc/kanku/templates/examples-vm/\

TEMPLATE_FILES = \
	templates/with-spice.tt2\
	templates/vm-x86_64-uefi-tpm2.0.tt2\
	templates/cmd/init/default.tt2\
	templates/cmd/init/vagrant.tt2\
	templates/cmd/setup/kanku.conf.mod_perl.tt2\
	templates/cmd/setup/kanku.conf.mod_proxy.tt2\
	templates/cmd/setup/kanku-vhost.conf.tt2\
	templates/cmd/setup/openssl.cnf.tt2\
	templates/cmd/setup/dancer-config.yml.tt2\
	templates/cmd/setup/kanku-config.yml.tt2\
	templates/cmd/setup/net-kanku-devel.xml.tt2\
	templates/cmd/setup/net-kanku-ovs.xml.tt2\
	templates/cmd/setup/net-kanku.xml.tt2\
	templates/cmd/setup/pool-default.xml\
	templates/cmd/setup/rabbitmq.config.tt2\
	templates/examples-vm/obs-server-26.tt2\
	templates/examples-vm/sles11sp3.tt2\
	templates/examples-vm/obs-server.tt2\

ifeq ($(DOCDIR),)
DOCDIR = /usr/share/doc/packages/kanku/
endif

_DOCDIR = $(DESTDIR)/$(DOCDIR)

PERL_CRITIC_READY := bin/*

ARCH = $(shell uname -m)

all:

install_arch_templates:
	install -m 644 etc/templates/default-vm.tt2.$(ARCH) $(DESTDIR)/etc/kanku/templates/default-vm.tt2

install: install_dirs install_full_dirs install_services install_docs configs templates public views bashcomp urlwrapper install_arch_templates install_tests
	install -m 644 dist/profile.d-kanku.sh $(DESTDIR)/etc/profile.d/kanku.sh
	install -m 644 dist/tmpfiles.d-kanku $(DESTDIR)/usr/lib/tmpfiles.d/kanku.conf
	install -m 644 dist/_etc_apache2_conf.d_kanku-worker.conf $(DESTDIR)/etc/apache2/conf.d/kanku-worker.conf

bashcomp:
	# FIXME: This is only a temporary workaround until we got upstream
	#        MooseX/App/Plugin/BashCompletion bug fixed.
	#        ATM its not able to handle subcommands like in 
	#        `kanku rguest console` properly.
	#PERL5LIB=./lib ./bin/kanku bash_completion > $(DESTDIR)/etc/bash_completion.d/kanku.sh
	cp dist/_etc_bash_completion.d_kanku.sh $(DESTDIR)/etc/bash_completion.d/kanku.sh

configs: config_dirs config_files

config_dirs:
	#
	for i in $(CONFIG_DIRS);do \
		[ -d $(DESTDIR)/$$i ] || mkdir -p $(DESTDIR)/$$i ; \
	done

config_files:
	#
	for i in $(CONFIG_FILES);do \
		cp -rv ./etc/$$i $(DESTDIR)/etc/kanku/$$i ;\
	done

templates: template_dirs template_files

template_dirs:
	#
	for i in $(TEMPLATE_DIRS);do \
		[ -d $(DESTDIR)/$$i ] || mkdir -p $(DESTDIR)/$$i ; \
	done

template_files:
	#
	for i in $(TEMPLATE_FILES);do \
		cp -rv ./etc/$$i $(DESTDIR)/etc/kanku/$$i ;\
	done

install_full_dirs: lib dbfiles public views bin sbin

bin:
	install -m 755 bin/network-setup.pl $(DESTDIR)/usr/lib/kanku/network-setup.pl
	install -m 755 bin/kanku $(DESTDIR)/usr/bin/kanku
	install -m 755 bin/kanku-app.psgi $(DESTDIR)/usr/lib/kanku/kanku-app.psgi
	install -m 755 bin/ss_netstat_wrapper $(DESTDIR)/usr/lib/kanku/ss_netstat_wrapper
	install -m 755 bin/iptables_wrapper $(DESTDIR)/usr/lib/kanku/iptables_wrapper

sbin:
	install -m 755 sbin/kanku-worker $(DESTDIR)/usr/sbin/kanku-worker
	install -m 755 sbin/kanku-dispatcher $(DESTDIR)/usr/sbin/kanku-dispatcher
	install -m 755 sbin/kanku-scheduler $(DESTDIR)/usr/sbin/kanku-scheduler
	install -m 755 sbin/kanku-triggerd $(DESTDIR)/usr/sbin/kanku-triggerd

public:
	cp -rv public $(DESTDIR)/usr/share/kanku/

views:
	cp -rv views $(DESTDIR)/usr/share/kanku/

dbfiles:
	cp -rv share/migrations $(DESTDIR)/usr/share/kanku/
	cp -rv share/fixtures $(DESTDIR)/usr/share/kanku/

lib:
	cp -rv ./lib/ $(DESTDIR)/usr/lib/kanku/

install_dirs:
	[ -d $(DESTDIR)/etc/bash_completion.d/ ] || mkdir -p $(DESTDIR)/etc/bash_completion.d/
	[ -d $(DESTDIR)/etc/apache2/conf.d ]     || mkdir -p $(DESTDIR)/etc/apache2/conf.d
	[ -d $(DESTDIR)/etc/profile.d ]          || mkdir -p $(DESTDIR)/etc/profile.d
	[ -d $(DESTDIR)/etc/kanku ]              || mkdir -p $(DESTDIR)/etc/kanku
	[ -d $(DESTDIR)/var/log/kanku ]          || mkdir -p $(DESTDIR)/var/log/kanku
	[ -d $(DESTDIR)/run/kanku ]              || mkdir -p $(DESTDIR)/run/kanku
	[ -d $(DESTDIR)/var/cache/kanku ]        || mkdir -p $(DESTDIR)/var/cache/kanku
	[ -d $(DESTDIR)/var/lib/kanku ]          || mkdir -p $(DESTDIR)/var/lib/kanku
	[ -d $(DESTDIR)/var/lib/kanku/db ]       || mkdir -p $(DESTDIR)/var/lib/kanku/db
	[ -d $(DESTDIR)/var/lib/kanku/sessions ] || mkdir -p $(DESTDIR)/var/lib/kanku/sessions
	[ -d $(DESTDIR)/usr/lib/systemd/system ] || mkdir -p $(DESTDIR)/usr/lib/systemd/system
	[ -d $(DESTDIR)/usr/bin ]                || mkdir -p $(DESTDIR)/usr/bin
	[ -d $(DESTDIR)/usr/sbin ]               || mkdir -p $(DESTDIR)/usr/sbin
	[ -d $(_DOCDIR)/contrib/libvirt-configs ] || mkdir -p $(_DOCDIR)/contrib/libvirt-configs
	[ -d $(DESTDIR)/usr/share/kanku ]        || mkdir -p $(DESTDIR)/usr/share/kanku
	[ -d $(DESTDIR)/usr/lib/kanku ]          || mkdir -p $(DESTDIR)/usr/lib/kanku
	[ -d $(DESTDIR)/usr/lib/tmpfiles.d ]     || mkdir -p $(DESTDIR)/usr/lib/tmpfiles.d

install_services: install_dirs
	install -m 644 ./dist/systemd/kanku-worker.service $(DESTDIR)/usr/lib/systemd/system/kanku-worker.service
	install -m 644 ./dist/systemd/kanku-scheduler.service $(DESTDIR)/usr/lib/systemd/system/kanku-scheduler.service
	install -m 644 ./dist/systemd/kanku-triggerd.service $(DESTDIR)/usr/lib/systemd/system/kanku-triggerd.service
	install -m 644 ./dist/systemd/kanku-web.service $(DESTDIR)/usr/lib/systemd/system/kanku-web.service
	install -m 644 ./dist/systemd/kanku-dispatcher.service $(DESTDIR)/usr/lib/systemd/system/kanku-dispatcher.service
	install -m 644 ./dist/systemd/kanku-iptables.service $(DESTDIR)/usr/lib/systemd/system/kanku-iptables.service

install_docs:
	install -m 644 README.md $(_DOCDIR)
	install -m 644 CONTRIBUTING.md $(_DOCDIR)
	install -m 644 INSTALL.md $(_DOCDIR)
	install -m 644 LICENSE $(_DOCDIR)
	install -m 644 docs/Development.pod $(_DOCDIR)/contrib/
	install -m 644 docs/README.apache-proxy.md $(_DOCDIR)/contrib/
	install -m 644 docs/README.rabbitmq.md $(_DOCDIR)/contrib/
	install -m 644 docs/README.setup-ovs.md $(_DOCDIR)/contrib/
	install -m 644 docs/README.setup-worker.md $(_DOCDIR)/contrib/

install_tests:
	cp -rv ./t/ $(DESTDIR)/usr/share/kanku/

clean:
	rm -rf kanku-*.tar.xz

test:
	prove -Ilib -It/lib t/*.t

critic:
	perlcritic -brutal $(PERL_CRITIC_READY)

cover:
	PERL5LIB=lib:t/lib cover -test -ignore '(^\/usr|t\/)'

check: cover critic

urlwrapper:
	[ -d $(DESTDIR)/usr/share/applications/ ] || mkdir -p $(DESTDIR)/usr/share/applications/
	[ -d $(DESTDIR)/usr/share/mime/packages ] || mkdir -p $(DESTDIR)/usr/share/mime/packages
	install -m 644 dist/kanku-urlwrapper.desktop $(DESTDIR)/usr/share/applications/kanku-urlwrapper.desktop
	install -m 644 dist/x-scheme-handler_kanku.xml $(DESTDIR)/usr/share/mime/packages/kanku.xml
	[ -d $(DESTDIR)/usr/share/icons/hicolor/32x32/apps ] || mkdir -p $(DESTDIR)/usr/share/icons/hicolor/32x32/apps
	[ -d $(DESTDIR)/usr/share/icons/hicolor/48x48/apps ] || mkdir -p $(DESTDIR)/usr/share/icons/hicolor/48x48/apps
	[ -d $(DESTDIR)/usr/share/icons/hicolor/64x64/apps ] || mkdir -p $(DESTDIR)/usr/share/icons/hicolor/64x64/apps
	install -m 644 public/images/32/kanku.png $(DESTDIR)/usr/share/icons/hicolor/32x32/apps/kanku.png
	install -m 644 public/images/48/kanku.png $(DESTDIR)/usr/share/icons/hicolor/48x48/apps/kanku.png
	install -m 644 public/images/64/kanku.png $(DESTDIR)/usr/share/icons/hicolor/64x64/apps/kanku.png

test-kankufiles:
	make -C KankuFile.examples/ test-kankufiles

.PHONY: dist install lib cover check test public views bin sbin install_tests
