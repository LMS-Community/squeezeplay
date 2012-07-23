## Makefile.am -- Process this file with automake to produce Makefile.in


# Check lua syntax
lua-lint:
	@rm -f badsyntax
	@find . -name "*.lua" -and \( -exec luac -p '{}' \; -or -print \) > badsyntax
	@test \! -s badsyntax
	@rm -f badsyntax


AM_CFLAGS = -Wall -Werror -D_GNU_SOURCE

lib_LTLIBRARIES = baby_bsp.la

baby_bsp_la_LDFLAGS = -module -no-version
baby_bsp_la_SOURCES = \
	src/baby_bsp.c \
	src/ir.c

JIVE_BUILD_DIR = $(DESTDIR)$(datadir)/jive

include Makefile.am.jive-install.include

install-data-local: jive-static-install
