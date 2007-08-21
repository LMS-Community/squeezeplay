/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"
#include "wpa_ctrl.h"


static struct wpa_ctrl *open_wpa_ctrl(lua_State *L) {
	const char *ctrl_path;
	struct wpa_ctrl **ctrl;

	// FIXME allow variable control path
	ctrl_path = "/var/run/wpa_supplicant/eth0";

	ctrl = (struct wpa_ctrl **)lua_touserdata(L, 1);
	if (*ctrl == NULL) {
		*ctrl = wpa_ctrl_open(ctrl_path);
	}
	if (*ctrl == NULL) {
		luaL_error(L, "cannot open wpa_cli %s", ctrl_path);
	}

	return *ctrl;
}

static void close_wpa_ctrl(lua_State *L) {
	struct wpa_ctrl **ctrl;

	ctrl = (struct wpa_ctrl **)lua_touserdata(L, 1);
	if (*ctrl) {
		wpa_ctrl_close(*ctrl);
		*ctrl = NULL;
	}
}


static int jive_net_wpa_ctrl_open(lua_State *L) {
	//const char *ctrl_path;
	struct wpa_ctrl **ctrl;

	/* stack is:
	 * 1: JiveWPA
	 * 2: ctrl_path
	 */

	ctrl = lua_newuserdata(L, sizeof(struct wpa_ctrl *));
	*ctrl = NULL;

	luaL_getmetatable(L, "jive.wireless");
	lua_setmetatable(L, -2);

	return 1;
}

static int jive_net_wpa_ctrl_gc(lua_State *L) {
	close_wpa_ctrl(L);
	return 0;
}


static int jive_net_wpa_ctrl_request(lua_State *L) {
	struct wpa_ctrl *ctrl;
	const char *cmd;
	char reply[2048];
	size_t cmd_len, reply_len;
	int err;

	ctrl = open_wpa_ctrl(L);
	cmd = lua_tolstring(L, 2, &cmd_len);

	reply_len = sizeof(reply);
	err = wpa_ctrl_request(ctrl, cmd, cmd_len, reply, &reply_len, NULL);
	if (err == -1) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request error");
	}
	if (err == -2) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request timeout");
	}

	lua_pushlstring(L, reply, reply_len);

	return 1;
}


static int jive_net_wpa_ctrl_attach(lua_State *L) {
	struct wpa_ctrl *ctrl;
	int err;

	ctrl = open_wpa_ctrl(L);
	err = wpa_ctrl_attach(ctrl);
	if (err == -1) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request error");
	}
	if (err == -2) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request timeout");
	}

	return 0;
}


static int jive_net_wpa_ctrl_detach(lua_State *L) {
	struct wpa_ctrl *ctrl;
	int err;

	ctrl = open_wpa_ctrl(L);
	err = wpa_ctrl_detach(ctrl);
	if (err == -1) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request error");
	}
	if (err == -2) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request timeout");
	}

	return 0;
}


static int jive_net_wpa_ctrl_get_fd(lua_State *L) {
	struct wpa_ctrl *ctrl;
	
	ctrl = open_wpa_ctrl(L);
	lua_pushinteger(L, wpa_ctrl_get_fd(ctrl));

	return 1;
}


static int jive_net_wpa_ctrl_recv(lua_State *L) {
	struct wpa_ctrl *ctrl;
	char reply[100];
	size_t reply_len = sizeof(reply);
	int err;
	
	ctrl = open_wpa_ctrl(L);
	err = wpa_ctrl_recv(ctrl, reply, &reply_len);
	if (err == -1) {
		close_wpa_ctrl(L);
		luaL_error(L, "wpa_ctrl_request error");
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

	lua_pushcfunction(L, jive_net_wpa_ctrl_gc);
	lua_setfield(L, -2, "__gc");

	lua_pushcfunction(L, jive_net_wpa_ctrl_request);
	lua_setfield(L, -2, "request");

	lua_pushcfunction(L, jive_net_wpa_ctrl_recv);
	lua_setfield(L, -2, "receive");

	lua_pushcfunction(L, jive_net_wpa_ctrl_attach);
	lua_setfield(L, -2, "attach");

	lua_pushcfunction(L, jive_net_wpa_ctrl_detach);
	lua_setfield(L, -2, "detach");

	lua_pushcfunction(L, jive_net_wpa_ctrl_get_fd);
	lua_setfield(L, -2, "getfd");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, "jive.wireless", jive_net_wpa_ctrl_lib);
	return 1;
}

