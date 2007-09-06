/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


void jive_widget_pack(lua_State *L, int index, JiveWidget *data) {

	JIVEL_STACK_CHECK_BEGIN(L);

	/* preferred bounds from style */
	data->preferred_bounds.x = jive_style_int(L, 1, "x", JIVE_XY_NIL);
	data->preferred_bounds.y = jive_style_int(L, 1, "y", JIVE_XY_NIL);
	data->preferred_bounds.w = jive_style_int(L, 1, "w", JIVE_WH_NIL);
	data->preferred_bounds.h = jive_style_int(L, 1, "h", JIVE_WH_NIL);

	/* padding from style */
	jive_style_insets(L, 1, "padding", &data->padding);
	jive_style_insets(L, 1, "border", &data->border);

	/* layer from style */
	data->layer = jive_style_int(L, 1, "layer", JIVE_LAYER_CONTENT);

	JIVEL_STACK_CHECK_END(L);
}


int jiveL_widget_set_bounds(lua_State *L) {
	JiveWidget *peer;
	SDL_Rect bounds;
	
	if (jive_getmethod(L, 1, "doSkin")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}
	
	lua_getfield(L, 1, "peer");
	peer = lua_touserdata(L, -1);
	if (!peer) {
		return 0;
	}

	memcpy(&bounds, &peer->bounds, sizeof(bounds));
	
	if (lua_isnumber(L, 2)) {
		bounds.x = lua_tointeger(L, 2);
	}
	if (lua_isnumber(L, 3)) {
		bounds.y = lua_tointeger(L, 3);
	}
	if (lua_isnumber(L, 4)) {
		bounds.w = lua_tointeger(L, 4);
	}
	if (lua_isnumber(L, 5)) {
		bounds.h = lua_tointeger(L, 5);
	}

	// mark old widget bounds for redrawing
	lua_pushcfunction(L, jiveL_widget_redraw);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);

	// check if the widget has moved
	if (memcmp(&peer->bounds, &bounds, sizeof(bounds)) == 0) {
		// no change
		return 0;
	}

	memcpy(&peer->bounds, &bounds, sizeof(bounds));

	// mark widget for layout
	if (jive_getmethod(L, 1, "reLayout")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	// mark new widget bounds for redrawing
	lua_pushcfunction(L, jiveL_widget_redraw);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);

	//printf("## SET_BOUNDS %p %d,%d %dx%d\n", lua_topointer(L, 1), peer->bounds.x, peer->bounds.y, peer->bounds.w, peer->bounds.h);

	return 0;
}


int jiveL_widget_get_bounds(lua_State *L) {
	JiveWidget *peer;

	if (jive_getmethod(L, 1, "doSkin")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}
	
	lua_getfield(L, 1, "peer");
	peer = lua_touserdata(L, -1);
	if (!peer) {
		return 0;
	}
	
	lua_pushinteger(L, peer->bounds.x);
	lua_pushinteger(L, peer->bounds.y);
	lua_pushinteger(L, peer->bounds.w);
	lua_pushinteger(L, peer->bounds.h);
	return 4;
}


int jiveL_widget_get_preferred_bounds(lua_State *L) {
	JiveWidget *peer;

	if (jive_getmethod(L, 1, "doSkin")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}
	
	lua_getfield(L, 1, "peer");
	peer = lua_touserdata(L, -1);
	if (!peer) {
		return 0;
	}
	
	if (peer->preferred_bounds.x == JIVE_XY_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->preferred_bounds.x);
	}
	if (peer->preferred_bounds.y == JIVE_XY_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->preferred_bounds.y);
	}
	if (peer->preferred_bounds.w == JIVE_WH_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->preferred_bounds.w);
	}
	if (peer->preferred_bounds.h == JIVE_WH_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->preferred_bounds.h);
	}
	return 4;
}


int jiveL_widget_get_border(lua_State *L) {
	JiveWidget *peer;

	if (jive_getmethod(L, 1, "doSkin")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}
	
	lua_getfield(L, 1, "peer");
	peer = lua_touserdata(L, -1);
	if (!peer) {
		return 0;
	}
	
	lua_pushinteger(L, peer->border.left);
	lua_pushinteger(L, peer->border.top);
	lua_pushinteger(L, peer->border.right);
	lua_pushinteger(L, peer->border.bottom);
	return 4;
}


int jiveL_widget_redraw(lua_State *L) {
	JiveWidget *peer;

	/* stack is:
	 * 1: widget
	 */

	lua_getfield(L, 1, "visible");
	if (lua_toboolean(L, -1)) {
		lua_getfield(L, 1, "peer");
		peer = lua_touserdata(L, -1);

		if (peer) {
			jive_redraw(&peer->bounds);
		}

		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	return 0;
}


int jiveL_widget_dolayout(lua_State *L) {
	int is_dirty;

	/* stack is:
	 * 1: widget
	 */

	/* does the layout need updating? */
	jiveL_getframework(L);
	lua_getfield(L, -1, "layoutCount");

	lua_getfield(L, 1, "layoutCount");
	is_dirty = lua_equal(L, -1, -2);
	lua_pop(L, 1);

	if (is_dirty == 0) {
		/* layout dirty, update */

		/* does the skin need updating? */
		lua_getfield(L, 1, "skinCount");
		if (lua_equal(L, -1, -2) == 0) {
			if (jive_getmethod(L, 1, "doSkin")) {
				lua_pushvalue(L, 1);
				lua_call(L, 1, 0);
			}
		}
		lua_pop(L, 1);

		/* does the content need updating? */
		lua_getfield(L, 1, "invalid");
		if (lua_toboolean(L, -1)) {
			if (jive_getmethod(L, 1, "_prepare")) {
				lua_pushvalue(L, 1);
				lua_call(L, 1, 0);
			}
			
			lua_pushboolean(L, 0);
			lua_setfield(L, 1, "invalid");
		}
		lua_pop(L, 1);

		/* update the layout */
		if (jive_getmethod(L, 1, "_layout")) {
			lua_pushvalue(L, 1);
			lua_call(L, 1, 0);
		}

		lua_setfield(L, 1, "layoutCount");
		lua_pop(L, 1);
	}

	/* layout children */
	jive_getmethod(L, 1, "iterate");
	lua_pushvalue(L, 1);
	lua_pushcfunction(L, jiveL_widget_dolayout);
	lua_call(L, 2, 0);

	lua_pop(L, 1);
	return 0;
}


int jive_widget_halign(JiveWidget *this, JiveAlign align, Uint16 width) {
	if (this->bounds.w - this->padding.left - this->padding.right < width) {
		return this->padding.left;
	}

	switch (align) {
	default:
        case JIVE_ALIGN_LEFT:
        case JIVE_ALIGN_TOP_LEFT:
        case JIVE_ALIGN_BOTTOM_LEFT:
		return this->padding.left;

        case JIVE_ALIGN_CENTER:
        case JIVE_ALIGN_TOP:
        case JIVE_ALIGN_BOTTOM:
		return ((this->bounds.w - this->padding.left - this->padding.right - width) / 2) + this->padding.left;

        case JIVE_ALIGN_RIGHT:
        case JIVE_ALIGN_TOP_RIGHT:
        case JIVE_ALIGN_BOTTOM_RIGHT:
		return this->bounds.w - this->padding.right - width;
	}
}


int jive_widget_valign(JiveWidget *this, JiveAlign align, Uint16 height) {
	switch (align) {
	default:
        case JIVE_ALIGN_TOP:
        case JIVE_ALIGN_TOP_LEFT:
        case JIVE_ALIGN_TOP_RIGHT:
		return this->padding.top;

        case JIVE_ALIGN_CENTER:
        case JIVE_ALIGN_LEFT:
        case JIVE_ALIGN_RIGHT:
		return this->padding.top + ((this->bounds.h - this->padding.top - this->padding.bottom) - height) / 2;

        case JIVE_ALIGN_BOTTOM:
        case JIVE_ALIGN_BOTTOM_LEFT:
        case JIVE_ALIGN_BOTTOM_RIGHT:
		return this->bounds.h - this->padding.bottom - height;
	}
}
