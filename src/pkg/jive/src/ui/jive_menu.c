/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct menu_widget {
	JiveWidget w;

	Uint16 item_height;
	Uint32 top_item;
	Uint32 bot_item;
} MenuWidget;


static JivePeerMeta menuPeerMeta = {
	sizeof(MenuWidget),
	"JiveMenu",
	jiveL_menu_gc,
};


int jiveL_menu_pack(lua_State *L) {
	MenuWidget *peer;
	int numItems, visibleItems;
	lua_Integer selected;
	Uint32 y;

	/* stack is:
	 * 1: widget
	 */

	printf("IN MENU PACK\n");

	peer = jive_getpeer(L, 1, &menuPeerMeta);

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);

	jive_widget_pack(L, 1, (JiveWidget *)peer);


	/* menu properties */
	peer->item_height = jive_style_int(L, 1, "itemHeight", 20);

	lua_getfield(L, 1, "items");
	numItems = lua_objlen(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 1, "topItem");
	peer->top_item = lua_tointeger(L, -1);
	lua_pop(L, 1);

	visibleItems = peer->w.bounds.h / peer->item_height;
	if (visibleItems > numItems) {
		visibleItems = numItems;
	}

	peer->bot_item = peer->top_item + visibleItems - 1;

	lua_pushinteger(L, visibleItems);
	lua_setfield(L, 1, "visibleItems");

	
	/* pack visible menu items */
	lua_getfield(L, 1, "style");

	/* items */
	lua_getfield(L, 1, "items");

	/* style overrides */
	lua_getfield(L, 1, "itemStyles");

	lua_getfield(L, 1, "selected");
	selected = lua_tointeger(L, -1);
	lua_pop(L, 1);

	/* stack is:
	 * 1: widget
	 * 2: style
	 * 3: items
	 * 4: itemStyles
	 */

	y = peer->w.bounds.y + peer->w.tp;
	if (!lua_isnil(L, 3)) {
		Uint16 n;
		for (n = peer->top_item; n <= peer->bot_item; n++) {
			SDL_Rect r;

			lua_rawgeti(L, 3, n);

			/* override item style */
			lua_rawgeti(L, 4, n);
			if (lua_isnil(L, -1)) {
				lua_pop(L, 1);
				lua_pushvalue(L, 2);
			}

			/* if selected style .= ".selected" */
			if (n == selected) {
				lua_pushstring(L, ".selected");
				lua_concat(L, 2);
			}

			lua_setfield(L, 1, "style");
			
			/* set bounds */
			jive_widget_get_bounds(L, -1, &r);
			
			r.x = peer->w.bounds.x;
			r.y = y;

			jive_widget_set_bounds(L, -1, &r);
			
			if (jive_getmethod(L, -1, "pack")) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 0);
			}

			lua_pop(L, 1);

			y += peer->item_height;
		}
	}

	/* restore menu style */
	lua_pushvalue(L, 2);
	lua_setfield(L, 1, "style");
	lua_pop(L, 3);

	/* pack scrollbar */
	lua_getfield(L, 1, "items");
	lua_getfield(L, 1, "scrollbar");
	if (!lua_isnil(L, -1)) {
		if (jive_getmethod(L, -1, "setScrollbar")) {
			lua_pushvalue(L, -2);
			lua_pushinteger(L, 0);
			lua_pushinteger(L, lua_objlen(L, -5));
			lua_pushinteger(L, peer->top_item);
			lua_pushinteger(L, visibleItems);

			lua_call(L, 5, 0);
		}

		if (jive_getmethod(L, -1, "pack")) {
			lua_pushvalue(L, -2);
			lua_call(L, 1, 0);
		}
	}
	lua_pop(L, 2);

	printf("DONE MENU PACK\n");

	return 0;
}


int jiveL_menu_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	MenuWidget *peer = jive_getpeer(L, 1, &menuPeerMeta);

	/* draw items */
	lua_getfield(L, 1, "items");
	if (!lua_isnil(L, -1)) {
		Uint16 n;

		for (n = peer->top_item; n <= peer->bot_item; n++) {
			lua_rawgeti(L, -1, n);

			if (jive_getmethod(L, -1, "draw")) {
				lua_pushvalue(L, -2);
				lua_pushvalue(L, 2);
				lua_pushvalue(L, 3);
				lua_call(L, 3, 0);
			}

			lua_pop(L, 1);
		}
	}
	lua_pop(L, 1);

	/* draw scrollbar */
	lua_getfield(L, 1, "scrollbar");
	if (!lua_isnil(L, -1) && jive_getmethod(L, -1, "draw")) {
		lua_pushvalue(L, -2);
		lua_pushvalue(L, 2);
		lua_pushvalue(L, 3);
		lua_call(L, 3, 0);
	}	
	lua_pop(L, 1);

	return 0;
}


int jiveL_menu_gc(lua_State *L) {
	printf("********************* MENU GC\n");

	luaL_checkudata(L, 1, menuPeerMeta.magic);

	/* nothing to do */

	return 0;
}
