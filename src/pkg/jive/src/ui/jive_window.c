/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct window_widget {
	JiveWidget w;

	JiveTile *bg_tile;
	JiveTile *mask_tile;
} WindowWidget;


static JivePeerMeta windowPeerMeta = {
	sizeof(WindowWidget),
	"JiveWindow",
	jiveL_window_gc,
};


int jiveL_window_skin(lua_State *L) {
	WindowWidget *peer;
	JiveTile *bg_tile;
	JiveTile *mask_tile;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &windowPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	/* set window layout function, defaults to borderLayout */
	lua_pushcfunction(L, jiveL_style_rawvalue);
	lua_pushvalue(L, 1); // widget
	lua_pushstring(L, "layout"); // key
	jive_getmethod(L, 1, "borderLayout"); // default
	lua_call(L, 3, 1);
	lua_setfield(L, 1, "_layout");

	bg_tile = jive_style_tile(L, 1, "bgImg", NULL);
	if (bg_tile != peer->bg_tile) {
		if (peer->bg_tile) {
			jive_tile_free(peer->bg_tile);
		}
		peer->bg_tile = jive_tile_ref(bg_tile);
	}

	mask_tile = jive_style_tile(L, 1, "maskImg", NULL);
	if (mask_tile != peer->mask_tile) {
		if (peer->mask_tile) {
			jive_tile_free(peer->mask_tile);
		}
		peer->mask_tile = jive_tile_ref(mask_tile);
	}


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


int jiveL_popup_iterate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 * 2: closure
	 */

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


static int draw_closure(lua_State *L) {
	if (jive_getmethod(L, 1, "draw")) {
		lua_pushvalue(L, 1); // widget
		lua_pushvalue(L, lua_upvalueindex(1)); // surface
		lua_pushvalue(L, lua_upvalueindex(2)); // layer
		lua_call(L, 3, 0);
	}

	return 0;
}


int jiveL_window_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	WindowWidget *peer = jive_getpeer(L, 1, &windowPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	Uint32 layer = luaL_optinteger(L, 3, JIVE_LAYER_ALL);

	/* window background */
	if ((layer & peer->w.layer) && peer->bg_tile) {
		jive_tile_blit(peer->bg_tile, srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.w, peer->w.bounds.h);
	}

	/* draw widgets */
	if (jive_getmethod(L, 1, "iterate")) {
		lua_pushvalue(L, 1); // widget

		lua_pushvalue(L, 2); // surface
		lua_pushvalue(L, 3); // layer
		lua_pushcclosure(L, draw_closure, 2);

		lua_call(L, 2, 0);
	}

	return 0;
}


int jiveL_popup_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	WindowWidget *peer = jive_getpeer(L, 1, &windowPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	Uint32 layer = luaL_optinteger(L, 3, JIVE_LAYER_ALL);

	/* draw underneath a popup */
	if (layer & JIVE_LAYER_FRAME) {
		if (jive_getmethod(L, 1, "getLowerWindow")) {
			lua_pushvalue(L, 1);
			lua_call(L, 1, 1);

			if (jive_getmethod(L, -1, "draw")) {
				lua_pushvalue(L, -2);
				lua_pushvalue(L, 2);
				lua_pushinteger(L, JIVE_LAYER_ALL);
				
				lua_call(L, 3, 0);
			}

			if (peer->mask_tile) {
				lua_getfield(L, -1, "peer");
				JiveWidget *peer2 = lua_touserdata(L, -1);

				jive_tile_blit(peer->mask_tile, srf, peer2->bounds.x, peer2->bounds.y, peer2->bounds.w, peer2->bounds.h);
				
				lua_pop(L, 1);
			}

			lua_pop(L, 1);
		}
	}

	return jiveL_window_draw(L);
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
	WindowWidget *peer;

	printf("********************* WINDOW GC\n");

	luaL_checkudata(L, 1, windowPeerMeta.magic);
	peer = lua_touserdata(L, 1);

	if (peer->bg_tile) {
		jive_tile_free(peer->bg_tile);
		peer->bg_tile = NULL;
	}
	if (peer->mask_tile) {
		jive_tile_free(peer->mask_tile);
		peer->mask_tile = NULL;
	}

	return 0;
}
