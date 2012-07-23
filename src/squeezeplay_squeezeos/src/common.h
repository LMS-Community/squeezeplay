/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#ifndef SQUEEZEPLAY_JIVE_COMMON_H
#define SQUEEZEPLAY_JIVE_COMMON_H

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

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <SDL.h>

#include "lua.h"
#include "lauxlib.h"

/* boolean type */
typedef unsigned int bool;
#define true 1
#define false !true


#endif // SQUEEZEPLAY_JIVE_COMMON_H
