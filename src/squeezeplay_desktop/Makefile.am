## Makefile.am -- Process this file with automake to produce Makefile.in

JIVE_BUILD_DIR = $(DESTDIR)$(pkgdatadir)

include Makefile.am.jive-install.include

install-data-local: jive-static-install
	##eliminate anything we still want private
	rm -rf $(JIVE_BUILD_DIR)/applets/TestDecode/
