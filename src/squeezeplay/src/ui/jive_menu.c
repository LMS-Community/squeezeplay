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

	JiveFont *font;
	Uint32 fg;
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

	lua_pushinteger(L, peer->item_height);
	lua_setfield(L, 1, "itemHeight");

	peer->font = jive_font_ref(jive_style_font(L, 1, "font"));
	peer->fg = jive_style_color(L, 1, "fg", JIVE_COLOR_BLACK, NULL);

	/* number of menu items visible */
	numWidgets = peer->w.bounds.h / peer->item_height;
	lua_pushinteger(L, numWidgets);
	lua_setfield(L, 1, "numWidgets");

	return 0;
}


int jiveL_menu_layout(lua_State *L) {
	MenuWidget *peer;
	Uint16 x, y;
	Uint16 sx, sy, sw, sh, tmp;
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
	sborder.left = 0;
	sborder.top = 0;
	sborder.right = 0;
	sborder.bottom = 0;

	if (peer->has_scrollbar) {
		lua_getfield(L, 1, "scrollbar");
		if (!lua_isnil(L, -1)) {
			if (jive_getmethod(L, -1, "getPreferredBounds")) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 4);
				
				if (!lua_isnil(L, -2)) {
					tmp = lua_tointeger(L, -2);
					if (tmp != JIVE_WH_FILL) {
						sw = tmp;
					}
				}
				if (!lua_isnil(L, -1)) {
					tmp = lua_tointeger(L, -1);
					if (tmp != JIVE_WH_FILL) {
						sh = tmp;
					}
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
	const char *accelKey;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	MenuWidget *peer = jive_getpeer(L, 1, &menuPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	lua_getfield(L, 1, "accelKey");
	accelKey = lua_tostring(L, -1);

	/* draw acceleration key letter */
	if (drawLayer && accelKey) {
		JiveSurface *txt;
		Uint16 srf_w, srf_h, txt_w, txt_h;

		txt = jive_font_draw_text(peer->font, peer->fg, accelKey);

		jive_surface_get_size(srf, &srf_w, &srf_h);
		jive_surface_get_size(txt, &txt_w, &txt_h);

		jive_surface_blit(txt, srf, (srf_w - txt_w) / 2, (srf_h - txt_h) / 2);

		jive_surface_free(txt);
	}


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
	MenuWidget *peer;

	luaL_checkudata(L, 1, menuPeerMeta.magic);

	peer = lua_touserdata(L, 1);

	if (peer->font) {
		jive_font_free(peer->font);
		peer->font = NULL;
	}

	return 0;
}
