## Makefile.am -- Process this file with automake to produce Makefile.in


# Check lua syntax
lua-lint:
	@rm -f badsyntax
	@find . -name "*.lua" -and \( -exec luac -p '{}' \; -or -print \) > badsyntax
	@test \! -s badsyntax
	@rm -f badsyntax

jive-static-install:
	mkdir -p $(JIVE_BUILD_DIR)
	cd share; tar -pcf  - \
		`find . \( -name "*.jpg" -o -name "*.gif" -o -name "*.png" -o -name "*.wav" -o -name "*.txt" -o -name "*.lua" \)` \
		| tar -C $(JIVE_BUILD_DIR) -pxf -

AM_CFLAGS = -Wall -Werror -D_GNU_SOURCE

lib_LTLIBRARIES = jiveWireless.la squeezeos_bsp.la

jiveWireless_la_LDFLAGS = -module -no-version
jiveWireless_la_SOURCES = \
	src/wireless.c \
	src/wpa_ctrl.c

squeezeos_bsp_la_LDFLAGS = -module -no-version
squeezeos_bsp_la_SOURCES = \
	src/squeezeos.c

JIVE_BUILD_DIR = $(DESTDIR)$(datadir)/jive

include Makefile.am.jive-install.include

install-data-local: jive-static-install
