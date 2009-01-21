/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "wpa_ctrl.h"


#include <sys/socket.h>
#include <net/if.h>
#include <linux/types.h>
#include <linux/wireless.h>
#include <linux/ethtool.h>

#ifndef SIOCETHTOOL
#define SIOCETHTOOL     0x8946
#endif


struct net_data {
	char *iface;
	struct wpa_ctrl *ctrl;
	int fd;
};


static int jive_net_wpa_ctrl_open(lua_State *L) {
	char ctrl_path[PATH_MAX];
	struct net_data *data;
	int err;

	/* stack is:
	 * 1: jive.network class
	 * 2: iface
	 * 3: isWireless
	 */

	data = lua_newuserdata(L, sizeof(struct net_data));

	data->iface = strdup(lua_tostring(L, 2));

	data->fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (data->fd < 0) {
		wpa_ctrl_close(data->ctrl);
		
		lua_pushnil(L);
		lua_pushfstring(L, "wlan socket: ", strerror(errno));
		return 2;
	}

	if (lua_isboolean(L, 3)) {
		sprintf(ctrl_path, "/var/run/wpa_supplicant/%s", data->iface);

		data->ctrl = wpa_ctrl_open(ctrl_path);
		if (data->ctrl == NULL) {
			close(data->fd);

			lua_pushnil(L);
			lua_pushfstring(L, "cannot open wpa_cli %s", ctrl_path);
			return 2;
		}

		err = wpa_ctrl_attach(data->ctrl);
		if (err == -1) {
			close(data->fd);
			wpa_ctrl_close(data->ctrl);

			lua_pushnil(L);
			lua_pushstring(L, "wpa_ctrl attach error");
			return 2;
		}
		if (err == -2) {
			close(data->fd);
			wpa_ctrl_close(data->ctrl);
		
			lua_pushnil(L);
			lua_pushstring(L, "wpa_ctrl attach timeout");
			return 2;
		}
	}

	luaL_getmetatable(L, "jive.network");
	lua_setmetatable(L, -2);

	return 1;
}


static int jive_net_wpa_ctrl_close(lua_State *L) {
	struct net_data *data;

	data = (struct net_data *)lua_touserdata(L, 1);
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
	struct net_data *data;
	const char *cmd;
	size_t cmd_len;
	int err;


	data = (struct net_data *)lua_touserdata(L, 1);
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
	struct net_data *data;

	data = (struct net_data *)lua_touserdata(L, 1);

	if (!data->ctrl) {
		lua_pushnil(L);
		lua_pushstring(L, "wpa_ctrl closed");
		return 2;
	}

	lua_pushinteger(L, wpa_ctrl_get_fd(data->ctrl));

	return 1;
}


static int jive_net_wpa_ctrl_recv(lua_State *L) {
	struct net_data *data;
	char reply[2048];
	size_t reply_len = sizeof(reply);
	int err;

	data = (struct net_data *)lua_touserdata(L, 1);

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
	struct net_data *data;
	struct iwreq wrq;

	data = (struct net_data *)lua_touserdata(L, 1);

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
	struct net_data *data;
	struct iwreq wrq;

	data = (struct net_data *)lua_touserdata(L, 1);

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


static int jive_net_eth_status(lua_State *L) {
	struct net_data *data;
	struct ifreq ifr;
	struct ethtool_cmd ecmd;
	struct ethtool_value edata;

	data = (struct net_data *)lua_touserdata(L, 1);

	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, data->iface);

	ecmd.cmd = ETHTOOL_GSET;
	ifr.ifr_data = (caddr_t)&ecmd;
	if (ioctl(data->fd, SIOCETHTOOL, &ifr) < 0) {
		goto eth_err;
	}

	edata.cmd = ETHTOOL_GLINK;
	ifr.ifr_data = (caddr_t)&edata;
	if (ioctl(data->fd, SIOCETHTOOL, &ifr) < 0) {
		goto eth_err;
	}

	lua_newtable(L);

	switch (ecmd.speed) {
	case SPEED_10:
		lua_pushinteger(L, 10);
		break;
	case SPEED_100:
		lua_pushinteger(L, 100);
		break;
	case SPEED_1000:
		lua_pushinteger(L, 1000);
		break;
	default:
		lua_pushinteger(L, 0);
	}
	lua_setfield(L, -2, "speed");

	lua_pushboolean(L, ecmd.duplex);
	lua_setfield(L, -2, "fullduplex");

	lua_pushboolean(L, edata.data);
	lua_setfield(L, -2, "link");

	return 1;

 eth_err:
	lua_pushnil(L);
	lua_pushfstring(L, "ioctl error: %s", strerror(errno));
	return 2;
}


static const struct luaL_Reg jive_net_lib[] = {
	{ "open", jive_net_wpa_ctrl_open },
	{ NULL, NULL }
};

static const struct luaL_Reg jive_net_methods[] = {
	{ "__gc", jive_net_wpa_ctrl_close },
	{ "close", jive_net_wpa_ctrl_close },
	{ "request", jive_net_wpa_ctrl_request },
	{ "receive", jive_net_wpa_ctrl_recv },
	{ "getfd", jive_net_wpa_ctrl_get_fd },
      	{ "getPower", jive_net_wlan_get_power },
	{ "setPower", jive_net_wlan_set_power },
	{ "ethStatus", jive_net_eth_status },
	{ NULL, NULL },
};

int luaopen_jiveWireless(lua_State *L) {
	luaL_newmetatable(L, "jive.network");
	luaL_register(L, NULL, jive_net_methods);

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, "jive.network", jive_net_lib);
	return 1;
}

