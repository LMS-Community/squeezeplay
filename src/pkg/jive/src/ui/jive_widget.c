/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


void jive_widget_pack(lua_State *L, int index, JiveWidget *data) {

	JIVEL_STACK_CHECK_BEGIN(L);

	/* default bounds from lua widget */
	jive_widget_get_bounds(L, index, &data->bounds);

	/* bounds from style */
	data->bounds.x = jive_style_int(L, 1, "x", data->bounds.x);
	data->bounds.y = jive_style_int(L, 1, "y", data->bounds.y);
	data->bounds.w = jive_style_int(L, 1, "w", data->bounds.w);
	data->bounds.h = jive_style_int(L, 1, "h", data->bounds.h);

	/* set bounds in lua widget */
	jive_widget_set_bounds(L, index, &data->bounds);

	/* padding from style */
	data->lp = jive_style_int(L, 1, "padding", data->lp);
	data->tp = jive_style_int(L, 1, "padding", data->tp);
	data->rp = jive_style_int(L, 1, "padding", data->rp);
	data->bp = jive_style_int(L, 1, "padding", data->bp);

	data->lp = jive_style_int(L, 1, "paddingLeft", data->lp);
	data->tp = jive_style_int(L, 1, "paddingTop", data->tp);
	data->rp = jive_style_int(L, 1, "paddingRight", data->rp);
	data->bp = jive_style_int(L, 1, "paddingBottom", data->bp);

	/* layer from style */
	data->layer = jive_style_int(L, 1, "layer", JIVE_LAYER_CONTENT);

	/* pack widgets */
	lua_getfield(L, 1, "widgets");
	if (!lua_isnil(L, -1)) {
		int n, len = lua_objlen(L, -1);
		for (n = 1; n <= len; n++) {
			lua_rawgeti(L, -1, n);

			if (jive_getmethod(L, -1, "pack")) {
				lua_pushvalue(L, -2);
				lua_call(L, 1, 0);
			}

			lua_pop(L, 1);
		}
	}
	lua_pop(L, 1);

	/* mark as packed */
	jiveL_getframework(L);
	lua_getfield(L, -1, "layoutCount");
	lua_setfield(L, 1, "layoutCount");
	lua_pop(L, 1);

	JIVEL_STACK_CHECK_END(L);
}


void jive_widget_get_bounds(lua_State *L,  int index, SDL_Rect *r) {

	JIVEL_STACK_CHECK_BEGIN(L);

	lua_getfield(L, index, "bounds");
	luaL_checktype(L, -1, LUA_TTABLE);

	lua_rawgeti(L, -1, 1);
	r->x = lua_tointeger(L, -1);

	lua_rawgeti(L, -2, 2);
	r->y = lua_tointeger(L, -1);

	lua_rawgeti(L, -3, 3);
	r->w = lua_tointeger(L, -1);

	lua_rawgeti(L, -4, 4);
	r->h = lua_tointeger(L, -1);

	lua_pop(L, 5);

	JIVEL_STACK_CHECK_END(L);
}


void jive_widget_set_bounds(lua_State *L, int index, SDL_Rect *r) {

	JIVEL_STACK_CHECK_BEGIN(L);

	if (index < 0) {
		index = lua_gettop(L) + index + 1;
	}

	lua_createtable(L, 4, 0);

	lua_pushinteger(L, r->x);
	lua_rawseti(L, -2, 1);

	lua_pushinteger(L, r->y);
	lua_rawseti(L, -2, 2);

	lua_pushinteger(L, r->w);
	lua_rawseti(L, -2, 3);

	lua_pushinteger(L, r->h);
	lua_rawseti(L, -2, 4);

	lua_setfield(L, index, "bounds");

	JIVEL_STACK_CHECK_END(L);
}


int jive_widget_halign(JiveWidget *this, JiveAlign align, Uint16 width) {
	switch (align) {
	default:
        case JIVE_ALIGN_LEFT:
        case JIVE_ALIGN_TOP_LEFT:
        case JIVE_ALIGN_BOTTOM_LEFT:
		return this->lp;

        case JIVE_ALIGN_CENTER:
        case JIVE_ALIGN_TOP:
        case JIVE_ALIGN_BOTTOM:
		return ((this->bounds.w - this->lp - this->rp) - width) / 2;

        case JIVE_ALIGN_RIGHT:
        case JIVE_ALIGN_TOP_RIGHT:
        case JIVE_ALIGN_BOTTOM_RIGHT:
		return this->bounds.w - this->rp - width;
	}
}


int jive_widget_valign(JiveWidget *this, JiveAlign align, Uint16 height) {
	switch (align) {
	default:
        case JIVE_ALIGN_TOP:
        case JIVE_ALIGN_TOP_LEFT:
        case JIVE_ALIGN_TOP_RIGHT:
		return this->tp;

        case JIVE_ALIGN_CENTER:
        case JIVE_ALIGN_LEFT:
        case JIVE_ALIGN_RIGHT:
		return this->tp + ((this->bounds.h - this->tp - this->bp) - height) / 2;

        case JIVE_ALIGN_BOTTOM:
        case JIVE_ALIGN_BOTTOM_LEFT:
        case JIVE_ALIGN_BOTTOM_RIGHT:
		return this->bounds.h - this->bp - height;
	}
}
