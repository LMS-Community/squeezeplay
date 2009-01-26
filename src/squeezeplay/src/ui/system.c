/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


static char *mac_address;
static char *uuid;
static char *arch;
static char *machine;
static char *homedir;
static char *resource_path = NULL;


static int system_get_mac_address(lua_State *L) {
	if (mac_address) {
		lua_pushstring(L, mac_address);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}


static int system_get_uuid(lua_State *L) {
	if (uuid) {
		lua_pushstring(L, uuid);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}


static int system_get_arch(lua_State *L) {
	if (arch) {
		lua_pushstring(L, arch);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}


static int system_get_machine(lua_State *L) {
	if (machine) {
		lua_pushstring(L, machine);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}


static int system_get_uptime(lua_State *L) {
	Uint32 uptime;
	int updays, upminutes, uphours;

	// FIXME wraps around after 49.7 days
	uptime = SDL_GetTicks() / 1000;

	updays = (int) uptime / (60*60*24);
        upminutes = (int) uptime / 60;
        uphours = (upminutes / 60) % 24;
        upminutes %= 60;

	lua_newtable(L);
	lua_pushinteger(L, updays);
	lua_setfield(L, -2, "days");

	lua_pushinteger(L, uphours);
	lua_setfield(L, -2, "hours");

	lua_pushinteger(L, upminutes);
	lua_setfield(L, -2, "minutes");

	return 1;
}


static int system_get_user_dir(lua_State *L) {
	lua_pushfstring(L, "%s/userpath", homedir);
	return 1;
}


static int system_init(lua_State *L) {
	/* stack is:
	 * 1: system
	 * 2: table
	 */

	lua_getfield(L, 2, "macAddress");
	if (!lua_isnil(L, -1)) {
		char *ptr;

		if (mac_address) {
			free(mac_address);
		}
		mac_address = strdup(lua_tostring(L, -1));

		ptr = mac_address;
		while (*ptr) {
			*ptr = tolower(*ptr);
			ptr++;
		}
	}
	lua_pop(L, 1);

	lua_getfield(L, 2, "uuid");
	if (!lua_isnil(L, -1)) {
		if (uuid) {
			free(uuid);
		}
		uuid = strdup(lua_tostring(L, -1));
	}
	lua_pop(L, 1);

	lua_getfield(L, 2, "machine");
	if (!lua_isnil(L, -1)) {
		if (machine) {
			free(machine);
		}
		machine = strdup(lua_tostring(L, -1));
	}
	lua_pop(L, 1);

	return 0;
}


static int system_find_file(lua_State *L) {
	char fullpath[PATH_MAX];
	const char *path;

	/* stack is:
	 * 1: framework
	 * 2: path
	 */

	path = luaL_checkstring(L, 2);

	if (jive_find_file(path, fullpath)) {
		lua_pushstring(L, fullpath);
	}
	else {
		lua_pushnil(L);
	}

	return 1;
}


static int system_init_path(lua_State *L) {
	const char *lua_path;
	char *ptr;

	/* set jiveui_path from lua path */
	lua_getglobal(L, "package");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 0;
	}
	
	lua_getfield(L, -1, "path");
	if (!lua_isstring(L, -1)) {
		lua_pop(L, 2);
		return 0;
	}

	lua_path = lua_tostring(L, -1);

	if (resource_path) {
		free(resource_path);
	}
	resource_path = malloc(strlen(lua_path) + 1);

	/* convert from lua path into jive path */
	ptr = resource_path;
	while (*lua_path) {
		switch (*lua_path) {
		case '?':
			while (*lua_path && *lua_path != ';') {
				lua_path++;
			}
			break;
			
		case ';':
			*ptr++ = ';';
			while (*lua_path && *lua_path == ';') {
				lua_path++;
			}
			break;
			
		default:
			*ptr++ = *lua_path++;
		}
	}
	*ptr = '\0';
	
	lua_pop(L, 2);
	return 0;
}


int jive_find_file(const char *path, char *fullpath) {
	char *begin, *end;
	FILE *fp;

	/* absolute/relative path */
	fp = fopen(path, "r");
	if (fp) {
		fclose(fp);
		strcpy(fullpath, path);
		return 1;
	}

	/* search lua path */
	begin = resource_path;
	end = strchr(begin, ';');

	while (end) {
#if defined(WIN32)
		char *tmp;
#endif

		strncpy(fullpath, begin, end-begin);
		strcpy(fullpath + (end-begin), path);

#if defined(WIN32)
		/* Convert from UNIX style paths */
		tmp = fullpath;
		while (*tmp) {
			if (*tmp == '/') {
				*tmp = '\\';
			}
			++tmp;
		}
#endif

		fp = fopen(fullpath, "r");
		if (fp) {
			fclose(fp);
			return 1;
		}

		begin = end + 1;
		end = strchr(begin, ';');
	}

	return 0;
}


static const struct luaL_Reg squeezeplay_system_methods[] = {
	{ "getArch", system_get_arch },
	{ "getMachine", system_get_machine },
	{ "getMacAddress", system_get_mac_address },
	{ "getUUID", system_get_uuid },
	{ "getUptime", system_get_uptime },
	{ "getUserDir", system_get_user_dir },
	{ "findFile", system_find_file },
	{ "init", system_init },
	{ NULL, NULL }
};


int squeezeplayL_system_init(lua_State *L) {
	const char *homeenv = getenv("SQUEEZEPLAY_HOME");
	char *ptr;

	mac_address = platform_get_mac_address();
	if (mac_address) {
		ptr = mac_address;
		while (*ptr) {
			*ptr = tolower(*ptr);
			ptr++;
		}
	}

	arch = platform_get_arch();
	machine = strdup("squeezeplay");
	if (homeenv) {
		homedir = strdup(homeenv);
	}
	else {
		homedir = platform_get_home_dir();
	}

	system_init_path(L);

	/* register methods */
	lua_getglobal(L, "jive");

	lua_getfield(L, 1, "System");
	luaL_register(L, NULL, squeezeplay_system_methods);
	lua_pop(L, 1);

	lua_pop(L, 1);
	return 0;
}
