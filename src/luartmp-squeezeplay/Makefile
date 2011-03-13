# Makefile for C component of Rtmp.lua specifically for squeezeplay
# This module is included here so that it can be built as a shared library rather than statically linked into squeezeplay

MYCFLAGS = -I../squeezeplay/src -I../squeezeplay/src/ui

rtmp.so: rtmp.c
	$(CC) $(CFLAGS) $(MYCFLAGS) -shared rtmp.c -o rtmp.so
