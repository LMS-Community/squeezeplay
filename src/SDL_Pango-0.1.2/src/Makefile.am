#Makefile.am for SDL_Pango library/DLL

lib_LTLIBRARIES = libSDL_Pango.la

libSDL_Pangoincludedir = $(includedir)
libSDL_Pangoinclude_HEADERS = SDL_Pango.h

libSDL_Pango_la_SOURCES = SDL_Pango.c

DEFS = @DEFS@ -DBUILD_DLL
libSDL_Pango_la_LDFLAGS = \
	-no-undefined		\
    -version-info $(LT_CURRENT):$(LT_REVISION):$(LT_AGE)

DISTCLEANFILES = *~ *~c *~h *.cross.cache inc
