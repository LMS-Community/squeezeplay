/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"
#include <linux/watchdog.h>


struct wdog_data {
	int fd;
};


static int l_jive_watchdog_open(lua_State *L) {
	struct wdog_data *wdog;

	wdog = lua_newuserdata(L, sizeof(struct wdog_data));

	wdog->fd = open("/dev/watchdog", O_WRONLY, 0);
	if (wdog->fd == -1) {
		perror("watchdog");

		lua_pushnil(L);
		return 1;
	}

	luaL_getmetatable(L, "jive.watchdog");
	lua_setmetatable(L, -2);

	return 1;
}


static int l_jive_watchdog_setTimeout(lua_State *L) {
	struct wdog_data *wdog;
	int timeout;

	wdog = lua_touserdata(L, 1);
	timeout = luaL_checknumber(L, 2);

	ioctl(wdog->fd, WDIOC_SETTIMEOUT, &timeout);
	
	return 0;
}


static int l_jive_watchdog_keepAlive(lua_State *L) {
	struct wdog_data *wdog;
	wdog = lua_touserdata(L, 1);

	ioctl(wdog->fd, WDIOC_KEEPALIVE, 0);

	return 0;
}


static const struct luaL_Reg jive_watchdog_lib[] = {
	{ "open", l_jive_watchdog_open },
	{ NULL, NULL }
};


static const struct luaL_Reg jive_watchdog_methods[] = {
	{ "setTimeout", l_jive_watchdog_setTimeout },
	{ "keepAlive", l_jive_watchdog_keepAlive },
	{ NULL, NULL }
};


int luaopen_jiveWatchdog(lua_State *L) {
	luaL_newmetatable(L, "jive.watchdog");
	luaL_register(L, NULL, jive_watchdog_methods);

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, "jive.watchdog", jive_watchdog_lib);
	return 1;
}
