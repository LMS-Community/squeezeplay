## Makefile.am -- Process this file with automake to produce Makefile.in


# Check lua syntax
lua-lint:
	@rm -f badsyntax
	@find . -name "*.lua" -and \( -exec luac -p '{}' \; -or -print \) > badsyntax
	@test \! -s badsyntax
	@rm -f badsyntax


AM_CFLAGS = -Wall -Werror -D_GNU_SOURCE

lib_LTLIBRARIES = fab4_bsp.la

fab4_bsp_la_LDFLAGS = -module -no-version
fab4_bsp_la_SOURCES = \
	src/fab4_bsp.c \
	src/ir.c

JIVE_BUILD_DIR = $(DESTDIR)$(datadir)/jive

include Makefile.am.jive-install.include

install-data-local: jive-static-install
