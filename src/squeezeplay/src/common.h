/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
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

#ifdef HAVE_DIRENT_H
#include "dirent.h"
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

#ifdef HAVE_LIBGEN_H
#include <libgen.h>
#endif

#ifdef HAVE_LIBPTHREAD
#include <pthread.h>
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

#ifdef HAVE_SYS_SHM_H
#include <sys/shm.h>
#endif

#ifdef HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
#include <sys/utsname.h>
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

#include "log.h"
#include "types.h"

/* utilities */
extern int squeezeplay_find_file(const char *path, char *fullpath);

/* watchdog */
int watchdog_get();
int watchdog_keepalive(int watchdog_id, int count);

/* system */
const char * system_get_machine(void);
const char * system_get_arch(void);
const char * system_get_version(void);
const char * system_get_uuid_char(void);

/* time */
#if HAVE_CLOCK_GETTIME
static inline u32_t jive_jiffies(void)
{
	struct timespec now;

	clock_gettime(CLOCK_MONOTONIC, &now);
	return (now.tv_sec*1000)+(now.tv_nsec/1000000);
}
#else
#define jive_jiffies() SDL_GetTicks()
#endif


#if WITH_DMALLOC
#include <dmalloc.h>
#endif

#if defined(_MSC_VER)
#define inline __inline
#endif //defined(_MSC_VER)

#endif // JIVE_COMMON_H

