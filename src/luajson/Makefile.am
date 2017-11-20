AM_CFLAGS = -D_GNU_SOURCE
ACLOCAL_AMFLAGS = -I m4
AUTOMAKE_OPTIONS = subdir-objects

lib_LTLIBRARIES = json.la

json_la_LDFLAGS = -module -no-version
json_la_SOURCES = \
	src/json_lua.c \
	src/json_tokener.c
