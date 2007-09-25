/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"


#define CLOCKS_PER_MSEC (CLOCKS_PER_SEC / 1000)


struct perf_hook_data {
	Uint32 hook_stack;
	clock_t hook_threshold;
	clock_t hook_ticks[100];
};

static void perf_hook(lua_State *L, lua_Debug *ar) {
	struct perf_hook_data *hd;

	lua_pushlightuserdata(L, (void *)((unsigned int)L) + 1);
	lua_gettable(L, LUA_REGISTRYINDEX);
	hd = lua_touserdata(L, -1);

	if (!hd) {
		return;
	}

	clock_t ticks = clock();

	if (ar->event == LUA_HOOKCALL) {
		if (hd->hook_stack < sizeof(hd->hook_ticks)) {
			hd->hook_ticks[hd->hook_stack] = ticks;
		}
		hd->hook_stack++;
	}
	else {
		hd->hook_stack--;
		if (hd->hook_stack < sizeof(hd->hook_ticks)
		    && ticks - hd->hook_ticks[hd->hook_stack] > hd->hook_threshold) {

			lua_getfield(L, LUA_GLOBALSINDEX, "debug");
			if (!lua_istable(L, -1)) {
				lua_pop(L, 1);
				return;
			}
			lua_getfield(L, -1, "traceback");
			if (!lua_isfunction(L, -1)) {
				lua_pop(L, 2);
				return;
			}

			/* message */
			lua_pushstring(L, "Warning function took ");
			lua_pushinteger(L, (ticks - hd->hook_ticks[hd->hook_stack]) / CLOCKS_PER_MSEC);
			lua_pushstring(L, "ms");
			lua_concat(L, 3);
			/* skip this function */
			lua_pushinteger(L, 1);
			lua_call(L, 2, 1);  /* call debug.traceback */

			printf("%s\n", lua_tostring(L, -1));
			
			lua_pop(L, 2);
		}
	}
}


/*
 * Install a debug hook to report functions that take too long to
 * execute. Takes one argument that is the time threshold in ms.
 */
static int jiveL_perfhook(lua_State *L) {
	struct perf_hook_data *hd;

	if (lua_gethook(L) != NULL) {
		return 0;
	}

	lua_sethook(L, perf_hook, LUA_MASKCALL | LUA_MASKRET, 0);

	lua_pushlightuserdata(L, (void *)((unsigned int)L) + 1);
	hd = lua_newuserdata(L, sizeof(struct perf_hook_data));
	lua_settable(L, LUA_REGISTRYINDEX);

	memset(hd, 0, sizeof(hd));
	hd->hook_threshold = lua_tointeger(L, 1) * CLOCKS_PER_MSEC;

	return 0;
}


static const struct luaL_Reg debug_funcs[] = {
	{ "perfhook", jiveL_perfhook },
	{ NULL, NULL }
};


int luaopen_jive_debug(lua_State *L) {
	luaL_register(L, "jive", debug_funcs);
	return 1;
}
