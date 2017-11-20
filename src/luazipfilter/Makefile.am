AM_CFLAGS = -Wall -Werror -D_GNU_SOURCE
ACLOCAL_AMFLAGS = -I m4
AUTOMAKE_OPTIONS = subdir-objects

lib_LTLIBRARIES = zipfilter.la

zipfilter_la_SOURCES = \
	src/luazipfilter.c

zipfilter_la_LDFLAGS = -module -no-version
zipfilter_la_LIBADD = -lz
