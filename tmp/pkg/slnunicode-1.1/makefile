#------
# Load configuration
#
include config

#------
# Hopefully no need to change anything below this line
#
INSTALL_UNICODE_SHARE=$(INSTALL_TOP_SHARE)/unicode
INSTALL_UNICODE_LIB=$(INSTALL_TOP_LIB)/unicode

all clean:
	cd src; $(MAKE) $@


#------
# Install slnunicode according to recommendation
#
install: all
	cd src; mkdir -p $(INSTALL_UNICODE_LIB)
	cd src; $(INSTALL_EXEC) $(UNICODE_SO) $(INSTALL_UNICODE_LIB)/core.$(EXT)

#------
# End of makefile
#
