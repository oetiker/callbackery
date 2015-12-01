% my $p = shift;
#  Copyright (C) <%= $p->{year} %> <%= $p->{fullName} %>

AUTOMAKE_OPTIONS =  foreign

MJ_CLASS = <%= $p->{class} %>
MJ_SCRIPT = <%= $p->{name} %>
QX_CLASS = <%= $p->{name} %>

SUBDIRS = thirdparty lib etc frontend

BIN = bin/$(MJ_SCRIPT).pl

PUB := $(shell find public -type d -name ".??*" -prune -o -not -name ".*" -a -not -name "*~" -a -not -name "*.tmp"  -a -type f -print )

TEMPL := $(shell test -d templates && find templates -type f -name "*.ep")

PERLTESTS := $(shell find t -name "*.t")

THIRDPARTY_DIR := $(shell pwd)/thirdparty

EXTRA_DIST = VERSION PERL_MODULES COPYRIGHT LICENSE CHANGES AUTHORS bootstrap $(PUB) \
	$(wildcard t/*.t) $(BIN) $(POD) $(TEMPL) $(PERLTESTS)

YEAR := $(shell date +%Y)
DATE := $(shell date +%Y-%m-%d)

datadir = $(prefix)
nobase_data_DATA = $(PUB) $(TEMPL)

dist_bin_SCRIPTS = $(BIN)

all-local:
	$(GMAKE) public/script/$(QX_CLASS).js

dist-hook: thirdparty/CPAN/touch
	$(PERL) -i -p -e 's/#VERSION#/$(PACKAGE_VERSION)/g;s/#YEAR#/$(YEAR)/g;s/#DATE#/$(DATE)/g;'  $(distdir)/README $(distdir)/COPYRIGHT $(distdir)/public/index.html $(distdir)/public/script/$(QX_CLASS).js
	$(PERL) -i -p -e '"$(PACKAGE_VERSION)" =~ /(\d+)\.(\d+)\.(\d+)/ and $$v = sprintf("%d.%03d%03d",$$1,$$2,$$3) and s/^\$$VERSION\s+=\s+".+?"/\$$VERSION = "$$d"/;'  $(distdir)/lib/$(MJ_CLASS).pm

install-exec-hook:
	[ "$(PERL5LIB)" == "" ] || cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{.*# PERL5LIB}{use lib qw($(PERL5LIB)); # PERL5LIB}' $(BIN) || true
	cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{.*# LIBDIR}{use lib qw($(libdir)); # LIBDIR}' $(BIN)
	cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{^#!.*perl.*}{#!$(PERL)};' $(BIN)
	[ ! -d $(THIRDPARTY_DIR)/lib/perl5 ] || cp -fr $(THIRDPARTY_DIR)/lib/perl5/* $(DESTDIR)$(libdir)


test:
	$(PERL) "-MExtUtils::Command::MM" "-e" "test_harness(0, 'lib','thirdparty/lib/perl5')" t/*.t


if BUILD_QOOXDOO_APP

CALLBACKERY_PATH := $(shell PERL5LIB=$(PERL5LIB) $(PERL) -Ilib -Ithirdparty/lib/perl5 -e 'use File::Basename;use Cwd qw(realpath); eval { require CallBackery }; print !$$@ ? realpath(dirname($$INC{q{CallBackery/Config.pm}}).q{/qooxdoo}) : "CALLBACKERY_NOT_FOUND" ' )

public/script/$(QX_CLASS).js: $(shell find frontend/source $(CALLBACKERY_PATH) -type f ) frontend/config.json config.status
	cd frontend && $(QOOXDOO_PATH)/tool/bin/generator.py -m QOOXDOO_PATH:$(QOOXDOO_PATH) -m CALLBACKERY_PATH:$(CALLBACKERY_PATH) -m CACHE:./cache -m BUILD_PATH:../public build

endif
