/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#ifdef __APPLE__

#include "common.h"
#include "jive.h"

static void osx_get_app_home_dir(char *path);

static void osx_get_app_home_dir(char *path) {
    const char *home = getenv("HOME");
    strcpy(path, home);
    strcat(path, "/Library/Preferences/SqueezePlay");
}

void jive_platform_init(lua_State *L) {
	get_app_home_dir_platform = osx_get_app_home_dir;
}

#endif


