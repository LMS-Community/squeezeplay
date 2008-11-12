/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#ifndef JIVE_COMMON_H
#define JIVE_COMMON_H

#include "config.h"

#include <assert.h>
#include <errno.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>

#ifdef HAVE_DIRECT_H
#include <direct.h>
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#ifdef HAVE_LIBGEN_H
#include <libgen.h>
#endif

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_STROPTS_H
#include <stropts.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

#ifdef HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_NETDB_H
#include <netdb.h>
#endif

#ifdef HAVE_ARPA_INET_H
#include <arpa/inet.h>
#endif


#ifndef PATH_MAX
/* Default POSIX maximum path length */
#define PATH_MAX 256
#endif


#if defined(WIN32)
#define DIR_SEPARATOR_CHAR	'\\'
#define DIR_SEPARATOR_STR	"\\"
#define PATH_SEPARATOR_CHAR	';'
#define PATH_SEPARATOR_STR	";"
#define LIBRARY_EXT		"dll"
#define mkdir(path,mode) _mkdir (path)
typedef _W64 int   ssize_t;
#endif /* WIN32 */

#ifndef DIR_SEPARATOR_CHAR
#define DIR_SEPARATOR_CHAR	'/'
#define DIR_SEPARATOR_STR	"/"
#define PATH_SEPARATOR_CHAR	':'
#define PATH_SEPARATOR_STR	":"
#define LIBRARY_EXT		"so"
#endif /* !DIR_SEPARATOR_CHAR */

#include <SDL.h>

#include "lua.h"
#include "lauxlib.h"
#include "tolua++.h"

#include "debug.h"
#include "types.h"

#if WITH_DMALLOC
#include <dmalloc.h>
#endif

#if defined(_MSC_VER)
#define inline __inline
#endif //defined(_MSC_VER)

#endif // JIVE_COMMON_H

