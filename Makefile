CONFIG_FILES = \
	templates/with-spice.tt2\
	templates/cmd/init.tt2\
	templates/cmd/setup/kanku.conf.mod_perl.tt2\
	templates/cmd/setup/kanku.conf.mod_proxy.tt2\
	templates/cmd/setup/kanku-vhost.conf.tt2\
	templates/cmd/setup/openssl.cnf.tt2\
	templates/cmd/setup/dancer-config.yml.tt2\
	templates/cmd/setup/kanku-config.yml.tt2\
	templates/cmd/setup/net-kanku-devel.xml.tt2\
	templates/cmd/setup/net-kanku-ovs.xml.tt2\
        templates/cmd/setup/pool-default.xml\
        templates/cmd/setup/rabbitmq.config.tt2\
	templates/examples-vm/obs-server-26.tt2\
	templates/examples-vm/sles11sp3.tt2\
	templates/examples-vm/obs-server.tt2\
	jobs/examples/obs-server.yml\
	jobs/examples/sles11sp3.yml\
	jobs/examples/obs-server-26.yml\
	jobs/remove-domain.yml\
	logging/default.conf\
	logging/console.conf\
        logging/network-setup.conf

FULL_DIRS	= bin share/migrations share/fixtures
CONFIG_DIRS		= \
	etc/kanku/templates\
	etc/kanku/templates/cmd\
	etc/kanku/templates/cmd/setup\
	etc/kanku/templates/cmd/setup/etc\
	etc/kanku/templates/examples-vm/\
	etc/kanku/jobs\
	etc/kanku/jobs/examples\
	etc/kanku/logging
ifeq ($(DOCDIR),)
DOCDIR = /usr/share/doc/packages/kanku/
endif

_DOCDIR = $(DESTDIR)/$(DOCDIR)

PERL_CRITIC_READY := bin/*

all:

install: install_dirs install_full_dirs install_services install_docs configs public views bashcomp
	install -m 644 ./dist/kanku.logrotate $(DESTDIR)/etc/logrotate.d/kanku-common
	install -m 644 dist/profile.d-kanku.sh $(DESTDIR)/etc/profile.d/kanku.sh
	install -m 644 dist/tmpfiles.d-kanku $(DESTDIR)/usr/lib/tmpfiles.d/kanku.conf
	install -m 644 dist/_etc_apache2_conf.d_kanku-worker.conf $(DESTDIR)/etc/apache2/conf.d/kanku-worker.conf

bashcomp:
	PERL5LIB=./lib ./bin/kanku bash_completion > $(DESTDIR)/etc/bash_completion.d/kanku.sh

configs:
	#
	for i in $(CONFIG_DIRS);do \
		mkdir -p $(DESTDIR)/$$i ; \
	done
	#
	for i in $(CONFIG_FILES);do \
		cp -av ./etc/$$i $(DESTDIR)/etc/kanku/$$i ;\
	done

install_full_dirs: lib dbfiles public views bin sbin

bin:
	install -m 755 bin/network-setup.pl $(DESTDIR)/usr/lib/kanku/network-setup.pl
	install -m 755 bin/kanku $(DESTDIR)/usr/bin/kanku
	install -m 755 bin/kanku-app.psgi $(DESTDIR)/usr/lib/kanku/kanku-app.psgi

sbin:
	install -m 755 sbin/kanku-worker $(DESTDIR)/usr/sbin/kanku-worker
	install -m 755 sbin/kanku-dispatcher $(DESTDIR)/usr/sbin/kanku-dispatcher
	install -m 755 sbin/kanku-scheduler $(DESTDIR)/usr/sbin/kanku-scheduler
	install -m 755 sbin/kanku-triggerd $(DESTDIR)/usr/sbin/kanku-triggerd

public:
	cp -av public $(DESTDIR)/usr/share/kanku/

views:
	cp -av views $(DESTDIR)/usr/share/kanku/

dbfiles:
	cp -av share/migrations $(DESTDIR)/usr/share/kanku/
	cp -av share/fixtures $(DESTDIR)/usr/share/kanku/

lib:
	cp -av ./lib/ $(DESTDIR)/usr/lib/kanku/

install_dirs:
	[ -d $(DESTDIR)/etc/bash_completion.d/ ] || mkdir -p $(DESTDIR)/etc/bash_completion.d/
	[ -d $(DESTDIR)/etc/logrotate.d/ ]       || mkdir -p $(DESTDIR)/etc/logrotate.d/
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

clean:
	rm -rf kanku-*.tar.xz

test:
	prove -Ilib -It/lib t/*.t

critic:
	perlcritic -brutal $(PERL_CRITIC_READY)

cover:
	PERL5LIB=lib:t/lib cover -test -ignore '(^\/usr|t\/)'

check: cover critic

.PHONY: dist install lib cover check test public views bin sbin
