/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct window_widget {
	JiveWidget w;

	bool is_popup;
} WindowWidget;


static JivePeerMeta windowPeerMeta = {
	sizeof(WindowWidget),
	"JiveWindow",
	jiveL_window_gc,
};


int jiveL_window_skin(lua_State *L) {
	WindowWidget *peer;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &windowPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	peer->is_popup = jive_style_int(L, 1, "popup", 0);


	/* set window layout function, defaults to borderLayout */
	lua_pushcfunction(L, jiveL_style_rawvalue);
	lua_pushvalue(L, 1); // widget
	lua_pushstring(L, "layout"); // key
	jive_getmethod(L, 1, "borderLayout"); // default
	lua_call(L, 3, 1);
	lua_setfield(L, 1, "_layout");


	/* pack global widgets */
	/* FIXME should this be needed here ? */
	jiveL_getframework(L);
	lua_getfield(L, -1, "widgets");
	if (!lua_isnil(L, -1)) {
		int n, len = (int) lua_objlen(L, -1);
		for (n = 1; n <= len; n++) {
			lua_rawgeti(L, -1, n);

			if (jive_getmethod(L, -1, "_pack")) {
				lua_pushvalue(L, -2);	// widget
				lua_call(L, 1, 0);
			}

			// reparent global widget
			lua_pushvalue(L, 1);
			lua_setfield(L, -2, "parent");

			lua_pop(L, 1);
		}
	}
	lua_pop(L, 2);

	return 0;
}


int jiveL_window_prepare(lua_State *L) {

	/* stack is:
	 * 1: widget
	 */

	return 0;
}


int jiveL_window_iterate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 * 2: closure
	 */

	// global widgets
	jiveL_getframework(L);
	lua_getfield(L, -1, "widgets");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_call(L, 1, 0);

		lua_pop(L, 1);
	}
	lua_pop(L, 2);

	// window widgets
	lua_getfield(L, 1, "widgets");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_call(L, 1, 0);

		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	return 0;
}


static void do_array_draw(lua_State *L) {
	if (lua_isnil(L, -1)) {
		return;
	}

	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (jive_getmethod(L, -1, "draw")) {
			lua_pushvalue(L, -2);	// widget
			lua_pushvalue(L, 2);	// surface
			lua_pushvalue(L, 3);	// layer
			lua_call(L, 3, 0);
		}

		lua_pop(L, 1);
	}
}


int jiveL_window_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	WindowWidget *peer = jive_getpeer(L, 1, &windowPeerMeta);
	Uint32 layer = luaL_optinteger(L, 3, JIVE_LAYER_ALL);

	/* draw underneath a popup */
	if (peer->is_popup && (layer & JIVE_LAYER_FRAME)) {
		jiveL_getframework(L);
		lua_getfield(L, -1, "windowStack");
		lua_rawgeti(L, -1, 2);

		if (jive_getmethod(L, -1, "draw")) {
			lua_pushvalue(L, -2);
			lua_pushvalue(L, 2);
			lua_pushinteger(L, JIVE_LAYER_ALL);

			lua_call(L, 3, 0);
		}
		lua_pop(L, 3);
	}

	/* draw global widgets */
	jiveL_getframework(L);
	lua_getfield(L, -1, "widgets");
	do_array_draw(L);
	lua_pop(L, 2);

	/* draw child widgets */
	lua_getfield(L, 1, "widgets");
	do_array_draw(L);
	lua_pop(L, 1);

	return 0;
}


static int do_array_event(lua_State *L) {
	int r = 0;

	if (lua_isnil(L, -1)) {
		return r;
	}

	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (jive_getmethod(L, -1, "_event")) {
			lua_pushvalue(L, -2);	// widget
			lua_pushvalue(L, 2);	// event
			lua_call(L, 2, 1);
					
			r |= lua_tointeger(L, -1);
			lua_pop(L, 1);
		}

		lua_pop(L, 1);
	}

	return r;
}


int jiveL_window_event_handler(lua_State *L) {
	int r = 0;

	/* stack is:
	 * 1: widget
	 * 2: event
	 */

	JiveEvent *event = lua_touserdata(L, 2);

	switch (event->type) {

	case JIVE_EVENT_SCROLL:
	case JIVE_EVENT_KEY_DOWN:
	case JIVE_EVENT_KEY_UP:
	case JIVE_EVENT_KEY_PRESS:
	case JIVE_EVENT_KEY_HOLD:

		/*
		 * Only send UI events to focused widget
		 */
		lua_getfield(L, 1, "focus");
		if (!lua_isnil(L, -1) && jive_getmethod(L, -1, "_event")) {
			lua_pushvalue(L, -2); // widget
			lua_pushvalue(L, 2); // event
			lua_call(L, 2, 1);

			return 1;
		}
		break;


	case JIVE_EVENT_WINDOW_PUSH:
	case JIVE_EVENT_WINDOW_POP:
	case JIVE_EVENT_WINDOW_ACTIVE:
	case JIVE_EVENT_WINDOW_INACTIVE:
		/*
		 * Don't forward window events
		 */
		break;


	case JIVE_EVENT_SHOW:
	case JIVE_EVENT_HIDE:
		/* Forward visiblity events to child widgets */
		lua_getfield(L, 1, "widgets");
		r |= do_array_event(L);
		lua_pop(L, 1);

		lua_pushinteger(L, r);
		return 1;

	default:
		/*
		 * Other events to all widgets
		 */
		r = 0;

		/* events to global widgets */
		jiveL_getframework(L);
		lua_getfield(L, -1, "widgets");
		r |= do_array_event(L);
		lua_pop(L, 2);

		/* events to child widgets */
		lua_getfield(L, 1, "widgets");
		r |= do_array_event(L);
		lua_pop(L, 1);

		lua_pushinteger(L, r);
		return 1;
	}

	lua_pushinteger(L, JIVE_EVENT_UNUSED);
	return 1;
}


int jiveL_window_gc(lua_State *L) {
	printf("********************* WINDOW GC\n");

	luaL_checkudata(L, 1, windowPeerMeta.magic);

	return 0;
}
