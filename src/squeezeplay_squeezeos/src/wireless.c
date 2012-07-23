/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"
#include "wpa_ctrl.h"


#include <sys/socket.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>		/* Needed for inet_ntoa() */
#include <linux/if.h>
#include <linux/types.h>
#include <linux/wireless.h>
#include <linux/ethtool.h>

#ifndef SIOCETHTOOL
#define SIOCETHTOOL     0x8946
#endif


// The following define, typedefs and struct are needed in jive_net_wlan_get_snr()
//  for Atheros wireless chipset. Copied from athdrv_linux.h.
#define AR6000_IOCTL_WMI_GET_TARGET_STATS    (SIOCIWFIRSTPRIV+25)

typedef int16_t A_INT16;
typedef int32_t A_INT32;
typedef u_int8_t A_UINT8;
typedef u_int16_t A_UINT16;
typedef u_int32_t A_UINT32;
typedef u_int64_t A_UINT64;

/* used by AR6000_IOCTL_WMI_GET_TARGET_STATS */
typedef struct targetStats_t {
    A_UINT64    tx_packets;
    A_UINT64    tx_bytes;
    A_UINT64    tx_unicast_pkts;
    A_UINT64    tx_unicast_bytes;
    A_UINT64    tx_multicast_pkts;
    A_UINT64    tx_multicast_bytes;
    A_UINT64    tx_broadcast_pkts;
    A_UINT64    tx_broadcast_bytes;
    A_UINT64    tx_rts_success_cnt;
    A_UINT64    tx_packet_per_ac[4];
    A_UINT64    tx_errors;
    A_UINT64    tx_failed_cnt;
    A_UINT64    tx_retry_cnt;
    A_UINT64    tx_mult_retry_cnt;
    A_UINT64    tx_rts_fail_cnt;
    A_UINT64    rx_packets;
    A_UINT64    rx_bytes;
    A_UINT64    rx_unicast_pkts;
    A_UINT64    rx_unicast_bytes;
    A_UINT64    rx_multicast_pkts;
    A_UINT64    rx_multicast_bytes;
    A_UINT64    rx_broadcast_pkts;
    A_UINT64    rx_broadcast_bytes;
    A_UINT64    rx_fragment_pkt;
    A_UINT64    rx_errors;
    A_UINT64    rx_crcerr;
    A_UINT64    rx_key_cache_miss;
    A_UINT64    rx_decrypt_err;
    A_UINT64    rx_duplicate_frames;
    A_UINT64    tkip_local_mic_failure;
    A_UINT64    tkip_counter_measures_invoked;
    A_UINT64    tkip_replays;
    A_UINT64    tkip_format_errors;
    A_UINT64    ccmp_format_errors;
    A_UINT64    ccmp_replays;
    A_UINT64    power_save_failure_cnt;
    A_UINT64    cs_bmiss_cnt;
    A_UINT64    cs_lowRssi_cnt;
    A_UINT64    cs_connect_cnt;
    A_UINT64    cs_disconnect_cnt;
    A_INT32     tx_unicast_rate;
    A_INT32     rx_unicast_rate;
    A_UINT32    lq_val;
    A_UINT32    wow_num_pkts_dropped;
    A_UINT16    wow_num_events_discarded;
    A_INT16     noise_floor_calibation;
    A_INT16     cs_rssi;
    A_INT16     cs_aveBeacon_rssi;
    A_UINT8     cs_aveBeacon_snr;
    A_UINT8     cs_lastRoam_msec;
    A_UINT8     cs_snr;
    A_UINT8     wow_num_host_pkt_wakeups;
    A_UINT8     wow_num_host_event_wakeups;
} TARGET_STATS;


struct net_data {
	char *iface;
	struct wpa_ctrl *ctrl;
	int fd;
	char *chipset;	// wireless chipset: "marvell" or "atheros"
};


static int jive_net_wpa_ctrl_open(lua_State *L) {
	char ctrl_path[PATH_MAX];
	struct net_data *data;
	int err;

	/* stack is:
	 * 1: jive.network class
	 * 2: iface
	 * 3: isWireless (nil for wired interfaces)
	 * 4: chipset (nil for wired interfaces)
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

		if (lua_isstring(L, 4)) {
			data->chipset = strdup(lua_tostring(L, 4));
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


static int jive_net_wlan_get_snr( lua_State *L) {
	struct net_data *data;

	data = (struct net_data *) lua_touserdata( L, 1);

	if( !data->fd) {
		lua_pushnil( L);
		lua_pushstring( L, "wlan closed");
		return 2;
	}

	if( strcmp( data->chipset, "marvell") == 0) {
		struct iwreq wrq;
		int buf[4];

		// These two values work with Marvell wireless drivers
		// They might be different for other wireless drivers
		int ioctl_val = 0x8BFD;
		int subioctl_val = 0xA;

		strncpy( wrq.ifr_ifrn.ifrn_name, data->iface, IFNAMSIZ);
		memset( buf, 0, sizeof(buf));
		wrq.u.data.pointer = buf;
		wrq.u.data.length = 0;			// We want all four values
		wrq.u.data.flags = subioctl_val;
		if( ioctl( data->fd, ioctl_val, &wrq) < 0) {
			lua_pushnil( L);
			lua_pushfstring( L, "ioctl error: %s", strerror( errno));
			return 2;
		}

		lua_newtable( L);
		lua_pushinteger( L, buf[0]);	// Beacon non-average
		lua_rawseti( L, -2, 1);
		lua_pushinteger( L, buf[1]);	// Beacon average
		lua_rawseti( L, -2, 2);
		lua_pushinteger( L, buf[2]);	// Data non-average
		lua_rawseti( L, -2, 3);
		lua_pushinteger( L, buf[3]);	// Data average
		lua_rawseti( L, -2, 4);

	} else if( strcmp( data->chipset, "atheros") == 0) {
		struct ifreq ifr;
		TARGET_STATS targetStats;

		memset( &ifr, 0, sizeof(ifr));
		strcpy( ifr.ifr_name, data->iface);
	        ifr.ifr_data = (void *) &targetStats;
	        if( ioctl( data->fd, AR6000_IOCTL_WMI_GET_TARGET_STATS, &ifr) < 0)
	        {
			lua_pushnil( L);
			lua_pushfstring( L, "ioctl error: %s", strerror( errno));
			return 2;
	        }

		// cs_snr and cs_aveBeacon_snr report identical values !!!
		// There are no data snr values reported from the wireless driver
		lua_newtable( L);
		lua_pushinteger( L, (int) targetStats.cs_snr);
		lua_rawseti( L, -2, 1);
		lua_pushinteger( L, (int) targetStats.cs_aveBeacon_snr);
		lua_rawseti( L, -2, 2);
		lua_pushinteger( L, (int) 0);
		lua_rawseti( L, -2, 3);
		lua_pushinteger( L, (int) 0);
		lua_rawseti( L, -2, 4);

	} else {
		lua_pushnil( L);
		lua_pushstring( L, "unsupported wireless chipset");
		return 2;
	}

	return 1;
}


void extractIp( struct ifreq *ifr, char *addr) {
	struct sockaddr *sa;
	sa = (struct sockaddr *) &(ifr->ifr_addr);
	strcpy( addr, inet_ntoa( ( (struct sockaddr_in *) sa)->sin_addr));

	return;
}


static int jive_net_get_if_config( lua_State *L) {
	struct net_data *data;
	struct ifreq ifr;
	char netaddr[INET_ADDRSTRLEN];
	char netmask[INET_ADDRSTRLEN];

	data = (struct net_data *) lua_touserdata( L, 1);

	if( !data->fd) {
		lua_pushnil( L);
		lua_pushstring( L, "wlan closed");
		return 2;
	}

	// Get ip address
	memset( &ifr, 0, sizeof( ifr));
	strcpy( ifr.ifr_name, data->iface);
	if( ioctl( data->fd, SIOCGIFADDR, &ifr) < 0) {
		lua_pushnil( L);
		lua_pushfstring( L, "ioctl error: %s", strerror( errno));
		return 2;
	}
	extractIp( &ifr, netaddr);

	// Get net mask
	memset( &ifr, 0, sizeof( ifr));
	strcpy( ifr.ifr_name, data->iface);
	if( ioctl( data->fd, SIOCGIFNETMASK, &ifr) < 0) {
		lua_pushnil( L);
		lua_pushfstring( L, "ioctl error: %s", strerror(errno));
		return 2;
	}
	extractIp( &ifr, netmask);

	lua_newtable( L);
	lua_pushstring( L, netaddr);
	lua_rawseti( L, -2, 1);
	lua_pushstring( L, netmask);
	lua_rawseti( L, -2, 2);

	return 1;
}


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
      	{ "getSNR", jive_net_wlan_get_snr },
	{ "getIfConfig", jive_net_get_if_config },
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

