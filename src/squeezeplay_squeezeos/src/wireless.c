/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"
#include "wpa_ctrl.h"


#include <sys/socket.h>
#include <net/if.h>
#include <linux/types.h>
#include <linux/wireless.h>


struct wlan_data {
	char *iface;
	struct wpa_ctrl *ctrl;
	int fd;
};


static int jive_net_wpa_ctrl_open(lua_State *L) {
	char ctrl_path[PATH_MAX];
	struct wlan_data *data;
	int err;

	/* stack is:
	 * 1: Wireless class
	 * 2: iface
	 */

	data = lua_newuserdata(L, sizeof(struct wlan_data));

	data->iface = strdup(lua_tostring(L, 2));
	sprintf(ctrl_path, "/var/run/wpa_supplicant/%s", data->iface);

	data->ctrl = wpa_ctrl_open(ctrl_path);
	if (data->ctrl == NULL) {
		lua_pushnil(L);
		lua_pushfstring(L, "cannot open wpa_cli %s", ctrl_path);
		return 2;
	}

	err = wpa_ctrl_attach(data->ctrl);
	if (err == -1) {
		wpa_ctrl_close(data->ctrl);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl attach error");
		return 2;
	}
	if (err == -2) {
		wpa_ctrl_close(data->ctrl);
		
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl attach timeout");
		return 2;
	}

	data->fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (data->fd < 0) {
		wpa_ctrl_close(data->ctrl);
		
		lua_pushnil(L);
		lua_pushfstring(L, "wlan socket: ", strerror(errno));
		return 2;
	}

	luaL_getmetatable(L, "jive.wireless");
	lua_setmetatable(L, -2);

	return 1;
}


static int jive_net_wpa_ctrl_close(lua_State *L) {
	struct wlan_data *data;

	data = (struct wlan_data *)lua_touserdata(L, 1);
	if (data->ctrl) {
		wpa_ctrl_close(data->ctrl);
		data->ctrl = NULL;
	}

	if (data->fd) {
		close(data->fd);
		data->fd = 0;
	}

	if (data->iface) {
		free(data->iface);
		data->iface = 0;
	}

	return 0;
}


static int jive_net_wpa_ctrl_request(lua_State *L) {
	struct wlan_data *data;
	const char *cmd;
	size_t cmd_len;
	int err;


	data = (struct wlan_data *)lua_touserdata(L, 1);
	cmd = lua_tolstring(L, 2, &cmd_len);

	if (!data->ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	err = wpa_ctrl_request(data->ctrl, cmd, cmd_len, NULL, NULL, NULL);
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
	struct wlan_data *data;

	data = (struct wlan_data *)lua_touserdata(L, 1);

	if (!data->ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	lua_pushinteger(L, wpa_ctrl_get_fd(data->ctrl));

	return 1;
}


static int jive_net_wpa_ctrl_recv(lua_State *L) {
	struct wlan_data *data;
	char reply[2048];
	size_t reply_len = sizeof(reply);
	int err;

	data = (struct wlan_data *)lua_touserdata(L, 1);

	if (!data->ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	if (!wpa_ctrl_pending(data->ctrl)) {
		lua_pushnil(L);
		lua_pushstring(L, "timeout");
		return 2;
	}

	err = wpa_ctrl_recv(data->ctrl, reply, &reply_len);
	if (err == -1) {
		jive_net_wpa_ctrl_close(L);

		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl recv error");
		return 2;
	}

	lua_pushlstring(L, reply, reply_len);
	return 1;
}


static int jive_net_wlan_get_power(lua_State *L) {
	struct wlan_data *data;
	struct iwreq wrq;

	data = (struct wlan_data *)lua_touserdata(L, 1);

	if (!data->fd) {
		lua_pushnil(L);
		lua_pushstring(L, "wlan closed");
		return 2;
	}

	strncpy(wrq.ifr_ifrn.ifrn_name, data->iface, IFNAMSIZ);
	wrq.u.power.flags = 0;

	if (ioctl(data->fd, SIOCGIWPOWER, &wrq) < 0) {
		lua_pushnil(L);
		lua_pushfstring(L, "ioctl error: %s", strerror(errno));
		return 2;
	}

	if (wrq.u.power.disabled) {
		lua_pushboolean(L, 0);
	}
	else {
		lua_pushboolean(L, 1);
	}

	return 1;
};


static int jive_net_wlan_set_power(lua_State *L) {
	struct wlan_data *data;
	struct iwreq wrq;

	data = (struct wlan_data *)lua_touserdata(L, 1);

	if (!data->fd) {
		lua_pushnil(L);
		lua_pushstring(L, "wlan closed");
		return 2;
	}

	strncpy(wrq.ifr_ifrn.ifrn_name, data->iface, IFNAMSIZ);

	if (lua_toboolean(L, 2)) {
		wrq.u.power.disabled = 0;
		wrq.u.power.flags = IW_POWER_ON;
	}
	else {
		wrq.u.power.disabled = 1;
		wrq.u.power.flags = 0;
	}

	if (ioctl(data->fd, SIOCSIWPOWER, &wrq) < 0) {
		lua_pushnil(L);
		lua_pushfstring(L, "ioctl error: %s", strerror(errno));
		return 2;
	}

	lua_pushboolean(L, 1);
	return 1;
};


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

	lua_pushcfunction(L, jive_net_wlan_get_power);
	lua_setfield(L, -2, "getPower");

	lua_pushcfunction(L, jive_net_wlan_set_power);
	lua_setfield(L, -2, "setPower");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, "jive.wireless", jive_net_wpa_ctrl_lib);
	return 1;
}

