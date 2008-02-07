/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"
#include "wpa_ctrl.h"


static int jive_net_wpa_ctrl_open(lua_State *L) {
	const char *ctrl_path;
	struct wpa_ctrl **ctrl;
	int err;

	/* stack is:
	 * 1: JiveWPA
	 * 2: ctrl_path
	 */

	// FIXME allow variable control path
	ctrl_path = "/var/run/wpa_supplicant/eth0";

	ctrl = lua_newuserdata(L, sizeof(struct wpa_ctrl **));

	*ctrl = wpa_ctrl_open(ctrl_path);
	if (*ctrl == NULL) {
		lua_pushnil(L);
		lua_pushfstring(L, "cannot open wpa_cli %s", ctrl_path);
		return 2;
	}

	err = wpa_ctrl_attach(*ctrl);
	if (err == -1) {
		wpa_ctrl_close(*ctrl);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl attach error");
		return 2;
	}
	if (err == -2) {
		wpa_ctrl_close(*ctrl);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl attach timeout");
		return 2;
	}

	luaL_getmetatable(L, "jive.wireless");
	lua_setmetatable(L, -2);

	return 1;
}


static int jive_net_wpa_ctrl_close(lua_State *L) {
	struct wpa_ctrl **ctrl;

	ctrl = (struct wpa_ctrl **)lua_touserdata(L, 1);
	if (*ctrl) {
		wpa_ctrl_close(*ctrl);
		*ctrl = NULL;
	}

	return 0;
}


static int jive_net_wpa_ctrl_request(lua_State *L) {
	struct wpa_ctrl *ctrl;
	const char *cmd;
	size_t cmd_len;
	int err;

	ctrl = *(struct wpa_ctrl **)lua_touserdata(L, 1);
	cmd = lua_tolstring(L, 2, &cmd_len);

	if (!ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	err = wpa_ctrl_request(ctrl, cmd, cmd_len, NULL, NULL, NULL);
	if (err == -1) {
		jive_net_wpa_ctrl_close(L);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl request error");
		return 2;
	}

	lua_pushboolean(L, 1);
	return 1;
}


static int jive_net_wpa_ctrl_get_fd(lua_State *L) {
	struct wpa_ctrl *ctrl;

	ctrl = *(struct wpa_ctrl **)lua_touserdata(L, 1);

	if (!ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	lua_pushinteger(L, wpa_ctrl_get_fd(ctrl));

	return 1;
}


static int jive_net_wpa_ctrl_recv(lua_State *L) {
	struct wpa_ctrl *ctrl;
	char reply[2048];
	size_t reply_len = sizeof(reply);
	int err;

	ctrl = *(struct wpa_ctrl **)lua_touserdata(L, 1);

	if (!ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	if (!wpa_ctrl_pending(ctrl)) {
		lua_pushnil(L);
		lua_pushstring(L, "timeout");
		return 2;
	}

	err = wpa_ctrl_recv(ctrl, reply, &reply_len);
	if (err == -1) {
		jive_net_wpa_ctrl_close(L);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl recv error");
		return 2;
	}

	lua_pushlstring(L, reply, reply_len);
	return 1;
}


static const struct luaL_Reg jive_net_wpa_ctrl_lib[] = {
	{ "open", jive_net_wpa_ctrl_open },
	{ NULL, NULL }
};


int luaopen_jiveWireless(lua_State *L) {
	luaL_newmetatable(L, "jive.wireless");

	lua_pushcfunction(L, jive_net_wpa_ctrl_close);
	lua_setfield(L, -2, "__gc");

	lua_pushcfunction(L, jive_net_wpa_ctrl_close);
	lua_setfield(L, -2, "close");

	lua_pushcfunction(L, jive_net_wpa_ctrl_request);
	lua_setfield(L, -2, "request");

	lua_pushcfunction(L, jive_net_wpa_ctrl_recv);
	lua_setfield(L, -2, "receive");

	lua_pushcfunction(L, jive_net_wpa_ctrl_get_fd);
	lua_setfield(L, -2, "getfd");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, "jive.wireless", jive_net_wpa_ctrl_lib);
	return 1;
}

