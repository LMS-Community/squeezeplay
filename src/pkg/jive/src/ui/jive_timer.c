/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct {
	SDL_TimerID timerId;
	int ref;
	int once;
} TimerData;


static Uint32 timer_callback(Uint32 interval, void *param) {
	TimerData *data = (TimerData *) param;

	SDL_Event user_event;
	memset(&user_event, 0, sizeof(SDL_Event));

	user_event.type = SDL_USEREVENT;
	user_event.user.code = JIVE_USER_EVENT_TIMER;
	user_event.user.data1 = (void *) data->ref;

	SDL_PushEvent(&user_event);

	if (data->once) {
		return 0;
	}
	else {
		return interval;
	}
}


void jive_timer_dispatch_event(lua_State *L, void *param) {
	JIVEL_STACK_CHECK_BEGIN(L);

	lua_rawgeti(L, LUA_REGISTRYINDEX, (lua_Integer) param);
	if (lua_isnil(L, -1) || lua_type(L, -1) != LUA_TTABLE) {
		lua_pop(L, 1);

		JIVEL_STACK_CHECK_ASSERT(L);
		return;
	}


	lua_getfield(L, -1, "callback");
	if (lua_isnil(L, -1) || !lua_isfunction(L, -1)) {
		lua_pop(L, 1);

		JIVEL_STACK_CHECK_ASSERT(L);
		return;
	}

	lua_insert(L, -2);

	if (lua_pcall(L, 1, 0, 0) != 0) {
		fprintf(stderr, "error in timer function:\n\t%s\n", lua_tostring(L, -1));
		lua_pop(L, 1);

		JIVEL_STACK_CHECK_ASSERT(L);
		return;
	}

	JIVEL_STACK_CHECK_END(L);
}


int jiveL_timer_add_timer(lua_State *L) {
	TimerData *data;
	int interval;

	/* stack is:
	 * 1: timer
	 */

	lua_getfield(L, 1, "_timerData");
	if (!lua_isnil(L, -1)) {
		/* timer is already running */
		return 0;
	}

	data = lua_newuserdata(L, sizeof(TimerData));
	lua_setfield(L, 1, "_timerData");

	lua_getfield(L, 1, "once");
	data->once = lua_toboolean(L, -1);

	lua_getfield(L, 1, "interval");
	interval = lua_tointeger(L, -1);

	lua_pushvalue(L, 1);
	data->ref = luaL_ref(L, LUA_REGISTRYINDEX);
	data->timerId = SDL_AddTimer(interval, &timer_callback, data);

	return 0;
}


int jiveL_timer_remove_timer(lua_State *L) {
	TimerData *data;

	/* stack is:
	 * 1: timer
	 */

	lua_getfield(L, 1, "_timerData");
	if (lua_isnil(L, -1)) {
		/* no timer running */
		return 0;
	}

	data = (TimerData *) lua_touserdata(L, -1);
	SDL_RemoveTimer(data->timerId);
	luaL_unref(L, LUA_REGISTRYINDEX, data->ref);

	lua_pushnil(L);
	lua_setfield(L, 1, "_timerData");

	return 0;
}
