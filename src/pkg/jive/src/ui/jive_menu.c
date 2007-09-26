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
	bool has_scrollbar;
} MenuWidget;


static JivePeerMeta menuPeerMeta = {
	sizeof(MenuWidget),
	"JiveMenu",
	jiveL_menu_gc,
};


int jiveL_menu_skin(lua_State *L) {
	MenuWidget *peer;
	int numWidgets;

	/* stack is:
	 * 1: widget
	 */

	peer = jive_getpeer(L, 1, &menuPeerMeta);

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	/* menu properties */
	peer->item_height = jive_style_int(L, 1, "itemHeight", 20);

	/* number of menu items visible */
	numWidgets = peer->w.bounds.h / peer->item_height;
	lua_pushinteger(L, numWidgets);
	lua_setfield(L, 1, "numWidgets");

	return 0;
}


int jiveL_menu_prepare(lua_State *L) {

	/* stack is:
	 * 1: widget
	 */

	return 0;
}


int jiveL_menu_layout(lua_State *L) {
	MenuWidget *peer;
	Uint16 x, y;
	Uint16 sx, sy, sw, sh;
	JiveInset sborder;
	int numWidgets, listSize;

	peer = jive_getpeer(L, 1, &menuPeerMeta);


	/* number of menu items visible */
	numWidgets = peer->w.bounds.h / peer->item_height;
	lua_pushinteger(L, numWidgets);
	lua_setfield(L, 1, "numWidgets");


	/* update widget contents */
	if (jive_getmethod(L, 1, "_updateWidgets")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}


	lua_getfield(L, 1, "listSize");
	listSize = lua_tointeger(L, -1);
	lua_pop(L, 1);

	peer->has_scrollbar = (listSize > numWidgets);

	/* measure scrollbar */
	sw = 0;
	sh = peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom;

	if (peer->has_scrollbar) {
		lua_getfield(L, 1, "scrollbar");
		if (!lua_isnil(L, -1)) {
			if (jive_getmethod(L, -1, "getPreferredBounds")) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 4);
				
				if (!lua_isnil(L, -2)) {
					sw = lua_tointeger(L, -2);
				}
				if (!lua_isnil(L, -1)) {
					sh = lua_tointeger(L, -1);
				}

				lua_pop(L, 4);
			}

			if (jive_getmethod(L, -1, "getBorder")) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 4);
				
				sborder.left = lua_tointeger(L, -4);
				sborder.top = lua_tointeger(L, -3);
				sborder.right = lua_tointeger(L, -2);
				sborder.bottom = lua_tointeger(L, -1);
				lua_pop(L, 4);
			}
		}
		lua_pop(L, 1);

		sw += sborder.left + sborder.right;
		sh += sborder.top + sborder.bottom;
	}

	sx = peer->w.bounds.x + peer->w.bounds.w - sw + sborder.left - peer->w.padding.right;
	sy = peer->w.bounds.y + peer->w.padding.top + sborder.top;


	/* position widgets */
	x = peer->w.bounds.x + peer->w.padding.left;
	y = peer->w.bounds.y + peer->w.padding.top;

	lua_getfield(L, 1, "widgets");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (jive_getmethod(L, -1, "setBounds")) {
			lua_pushvalue(L, -2);
			lua_pushinteger(L, x);
			lua_pushinteger(L, y);
			lua_pushinteger(L, peer->w.bounds.w - peer->w.padding.left - peer->w.padding.right - sw);
			lua_pushinteger(L, peer->item_height);
			
			lua_call(L, 5, 0);
		}

		y += peer->item_height;
		lua_pop(L, 1);
	}
	lua_pop(L, 1);


	/* position scrollbar */
	if (peer->has_scrollbar) {
		lua_getfield(L, 1, "scrollbar");
		if (!lua_isnil(L, -1)) {
			if (jive_getmethod(L, -1, "setBounds")) {
				lua_pushvalue(L, -2);
				lua_pushinteger(L, sx);
				lua_pushinteger(L, sy);
				lua_pushinteger(L, sw - sborder.left - sborder.right);
				lua_pushinteger(L, sh - sborder.top - sborder.bottom);
				lua_call(L, 5, 0);
			}
		}
		lua_pop(L, 1);
	}

	return 0;
}

int jiveL_menu_iterate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 * 2: closure
	 */

	/* iterate widgets */
	lua_getfield(L, 1, "widgets");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_call(L, 1, 0);

		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	/* iterate scrollbar */
	lua_getfield(L, 1, "scrollbar");
	if (!lua_isnil(L, -1)) {
		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_call(L, 1, 0);
	}	
	lua_pop(L, 1);

	return 0;
}

int jiveL_menu_draw(lua_State *L) {
	MenuWidget *peer;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	peer = jive_getpeer(L, 1, &menuPeerMeta);

	/* draw widgets */
	lua_getfield(L, 1, "widgets");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (jive_getmethod(L, -1, "draw")) {
			lua_pushvalue(L, -2);
			lua_pushvalue(L, 2);
			lua_pushvalue(L, 3);
			lua_call(L, 3, 0);
		}

		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	/* draw scrollbar */
	if (peer->has_scrollbar) {
		lua_getfield(L, 1, "scrollbar");
		if (!lua_isnil(L, -1) && jive_getmethod(L, -1, "draw")) {
			lua_pushvalue(L, -2);
			lua_pushvalue(L, 2);
			lua_pushvalue(L, 3);
			lua_call(L, 3, 0);
		}	
		lua_pop(L, 1);
	}

	return 0;
}


int jiveL_menu_gc(lua_State *L) {
	printf("********************* MENU GC\n");

	luaL_checkudata(L, 1, menuPeerMeta.magic);

	/* nothing to do */

	return 0;
}
