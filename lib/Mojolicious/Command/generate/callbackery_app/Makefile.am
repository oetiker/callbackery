% my $p = shift;
#  Copyright (C) <%= $p->{year} %> <%= $p->{fullName} %>

AUTOMAKE_OPTIONS =  foreign

MJ_CLASS = <%= $p->{class} %>
MJ_SCRIPT = <%= $p->{name} %>
QX_CLASS = <%= $p->{name} %>

SUBDIRS = lib etc frontend

BIN = bin/$(MJ_SCRIPT).pl

PUB := $(shell find public -type d -name ".??*" -prune -o -not -name ".*" -a -not -name "*~" -a -not -name "*.tmp"  -a -type f -print )

TEMPL := $(shell find templates -type f -name "*.ep")

PERLTESTS := $(shell find t -name "*.t")

THIRDPARTY_DIR := $(shell pwd)/thirdparty

THIRDPARTY_DIST := $(shell test -d thirdparty/CPAN && find thirdparty/CPAN -type d -name ".??*" -prune -o -not -name ".*" -a -not -name "*~" -a -not -name "*.tmp"  -a -type f -print )

EXTRA_DIST = VERSION PERL_MODULES COPYRIGHT LICENSE CHANGES AUTHORS bootstrap $(PUB) \
	$(wildcard t/*.t) $(BIN) $(POD) $(TEMPL) $(THIRDPARTY_DIST) $(wildcard thirdparty/bin/cpanm) \
	$(PERLTESTS)

YEAR := $(shell date +%Y)
DATE := $(shell date +%Y-%m-%d)

datadir = $(prefix)
nobase_data_DATA = $(PUB) $(TEMPL)

dist_bin_SCRIPTS = $(BIN)

all-local:
	$(AM_V_GEN)[ "$(MISSING_PERL_MODULES)" == "" ] || $(GMAKE) thirdparty/touch
	$(GMAKE) public/script/$(QX_CLASS).js

dist-hook: thirdparty/CPAN/touch
	$(PERL) -i -p -e 's/#VERSION#/$(PACKAGE_VERSION)/g;s/#YEAR#/$(YEAR)/g;s/#DATE#/$(DATE)/g;'  $(distdir)/README $(distdir)/COPYRIGHT
	$(PERL) -i -p -e '"$(PACKAGE_VERSION)" =~ /(\d+)\.(\d+)\.(\d+)/ and $$v = sprintf("%d.%03d%03d",$$1,$$2,$$3) and s/^\$$VERSION\s+=\s+".+?"/\$$VERSION = "$$d"/;'  $(distdir)/lib/$(MJ_CLASS).pm

install-exec-hook:
	[ "$(PERL5LIB)" == "" ] || cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{.*# PERL5LIB}{use lib qw($(PERL5LIB)); # PERL5LIB}' $(BIN) || true
	cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{.*# LIBDIR}{use lib qw($(libdir)); # LIBDIR}' $(BIN)
	cd "$(DESTDIR)$(exec_prefix)" && $(PERL) -i -p -e 's{^#!.*perl.*}{#!$(PERL)};' $(BIN)
	[ ! -d $(THIRDPARTY_DIR)/lib/perl5 ] || cp -fr $(THIRDPARTY_DIR)/lib/perl5/* $(DESTDIR)$(libdir)


test:
	$(PERL) "-MExtUtils::Command::MM" "-e" "test_harness(0, 'lib','thirdparty/lib/perl5')" t/*.t


thirdparty/touch: thirdparty/CPAN/touch
	$(AM_V_GEN)echo $(MISSING_PERL_MODULES) | PERL_CPANM_HOME=$(THIRDPARTY_DIR) xargs $(PERL) $(THIRDPARTY_DIR)/bin/cpanm -q --notest --local-lib-contained $(THIRDPARTY_DIR)  --mirror file://$(THIRDPARTY_DIR)/CPAN --mirror-only
	$(AM_V_GEN)touch thirdparty/touch

thirdparty/CPAN/touch: PERL_MODULES
	echo "POPULATING OUR LOCAL micro CPAN"
	$(AM_V_GEN)$(URL_CAT) https://cpanmin.us | PERL_CPANM_HOME=$(THIRDPARTY_DIR) $(PERL) - -q --notest --local-lib $(THIRDPARTY_DIR) --save-dists $(THIRDPARTY_DIR)/CPAN --force App::cpanminus
	$(AM_V_GEN)PERL_CPANM_HOME=$(THIRDPARTY_DIR)/Ore $(THIRDPARTY_DIR)/bin/cpanm -q --notest  --local-lib $(THIRDPARTY_DIR)/Ore OrePAN
	$(AM_V_GEN)cat PERL_MODULES | PERL_CPANM_HOME=$(THIRDPARTY_DIR) xargs $(PERL) $(THIRDPARTY_DIR)/bin/cpanm -q --self-contained --notest --local-lib-contained $(THIRDPARTY_DIR) --save-dists $(THIRDPARTY_DIR)/CPAN
	$(AM_V_GEN)PERL5LIB=$(THIRDPARTY_DIR)/Ore/lib/perl5 $(THIRDPARTY_DIR)/Ore/bin/orepan_index.pl --repository $(THIRDPARTY_DIR)/CPAN
# Ore fails to extract the version form DBI
	$(AM_V_GEN)gunzip -c thirdparty/CPAN/modules/02packages.details.txt.gz | perl -pe 's{^(DBI\s+)undef(\s+\S+/DBI-)(\d+\.\d+)(\.tar)}{$$1$$3$$2$$3$$4}' |  gzip | cat > x.gz && mv x.gz thirdparty/CPAN/modules/02packages.details.txt.gz
	$(AM_V_GEN)touch thirdparty/CPAN/touch


if BUILD_QOOXDOO_APP

CALLBACKERY_PATH := $(shell PERL5LIB=$(PERL5LIB) $(PERL) -Ilib -Ithirdparty/lib/perl5 -e 'use File::Basename;use Cwd qw(realpath); eval { require CallBackery }; print !$$@ ? realpath(dirname($$INC{q{CallBackery/Config.pm}}).q{/qooxdoo}) : "CALLBACKERY_NOT_FOUND" ' )

public/script/$(QX_CLASS).js: $(shell find frontend/source/) frontend/config.json configure
	cd frontend && $(QOOXDOO_PATH)/tool/bin/generator.py -m QOOXDOO_PATH:$(QOOXDOO_PATH) -m CALLBACKERY_PATH:$(CALLBACKERY_PATH) -m CACHE:./cache -m BUILD_PATH:../public build
	$(PERL) -i -p -e 's/#VERSION#/$(PACKAGE_VERSION)/g;s/#YEAR#/$(YEAR)/g;s/#DATE#/$(DATE)/g;' public/index.html public/script/$(QX_CLASS).js

endif
