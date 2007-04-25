/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

//#define RUNTIME_DEBUG 1

#include "common.h"
#include "jive.h"


static int search_path(lua_State *L, int widget, char *path, const char *key, int nargs) {
	int argi = lua_gettop(L) - 2;

	char *tok = strtok(path, ".");
	while (tok) {
		lua_pushstring(L, tok);
		lua_rawget(L, -2);

		if (lua_isnil(L, -1)) {
			lua_pop(L, 1);
			return 0;
		}

		luaL_checktype(L, -1, LUA_TTABLE);
		lua_replace(L, -2);

		tok = strtok(NULL, ".");
	}

	lua_pushstring(L, key);
	lua_rawget(L, -2);
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);
		return 0;
	}

	/* is the style value a function? */
	if (lua_isfunction(L, -1)) {
		int i;

		// push widget
		lua_pushvalue(L, widget);

		// push optional arguments
		for (i = 0; i < nargs; i++) {
			lua_pushvalue(L, argi + i);
		}

		if (lua_pcall(L, 1 + nargs, 1, 0) != 0) {
			fprintf(stderr, "error running style function:\n\t%s\n", lua_tostring(L, -1));
			lua_pop(L, 1);
			return 0;
		}
	}

	return 1;
}


static void get_jive_ui_style(lua_State *L) {
	lua_getglobal(L, "jive");
	luaL_checktype(L, -1, LUA_TTABLE);

	lua_getfield(L, -1, "ui");
	luaL_checktype(L, -1, LUA_TTABLE);

	lua_getfield(L, -1, "style");
	luaL_checktype(L, -1, LUA_TTABLE);

	lua_remove(L, -2);
	lua_remove(L, -2);
}


int jiveL_style_value(lua_State *L) {
	const char *key, *path;
	char *ptr;
	int nargs;

	/* stack is:
	 * 1: widget
	 * 2: key
	 * 3: default
	 * 4... args
	 */

	/* Make sure we have a default value */
	if (lua_gettop(L) == 2) {
		lua_pushnil(L);
	}

	key = lua_tostring(L, 2);
	nargs = lua_gettop(L) - 3;

	/* Concatenate style paths */
	lua_getfield(L, 1, "stylePath");
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);

		lua_pushcfunction(L, jiveL_style_path);
		lua_pushvalue(L, 1);
		lua_call(L, 1, 1);
	}

	path = lua_tostring(L, -1);

	DEBUG_TRACE("style: %s : %s", path, key);

	ptr = (char *) path;
	while (ptr) {
		char *tmp = strdup(ptr);

		get_jive_ui_style(L);
		if (search_path(L, 1, tmp, key, nargs)) {
			free(tmp);
			lua_remove(L, -2);
			return 1;
		}
		free(tmp);
		lua_pop(L, 1);

		ptr = strchr(ptr, '.');
		if (ptr) {
			ptr++;
		}
	}

	get_jive_ui_style(L);
	lua_pushstring(L, key);
	lua_rawget(L, -2);
	if (!lua_isnil(L, -1)) {
		lua_remove(L, -2);
		return 1;
	}
	lua_pop(L, 2);

	// default
	lua_pushvalue(L, 3);

	return 1;
}


int jiveL_style_path(lua_State *L) {
	int numStrings = 0;

	lua_pushvalue(L, 1);
	while (!lua_isnil(L, -1)) {
		lua_getfield(L, -1, "style");
		if (!lua_isnil(L, -1)) {
			lua_insert(L, 2);
			lua_pushstring(L, ".");
			lua_insert(L, 2);
			numStrings += 2;
		}
		else {
			lua_pop(L, 1);
		}
		
		lua_getfield(L, -1, "parent");
		lua_replace(L, -2);
	}
	lua_pop(L, 1);

	lua_concat(L, numStrings - 1);
	lua_remove(L, -2);

	lua_pushvalue(L, -1);
	lua_setfield(L, 1, "stylePath");

	return 1;
}


int jive_style_int(lua_State *L, int index, const char *key, int def) {
	int value;

	JIVEL_STACK_CHECK_BEGIN(L);

	lua_pushcfunction(L, jiveL_style_value);
	lua_pushvalue(L, index);
	lua_pushstring(L, key);
	lua_pushinteger(L, def);
	lua_call(L, 3, 1);

	if (lua_isboolean(L, -1)) {
		value = lua_toboolean(L, -1);
	}
	else {
		value = lua_tointeger(L, -1);
	}
	lua_pop(L, 1);

	JIVEL_STACK_CHECK_END(L);

	return value;
}


int jiveL_style_color(lua_State *L) {
	Uint32 r, g, b, a;
	
	/* stack is:
	 * 1: widget
	 * 2: key
	 * 3: default
	 */

	jiveL_style_value(L);

	if (lua_isnil(L, -1)) {
		return 1;
	}

	if (!lua_istable(L, -1)) {
		luaL_error(L, "invalid component in style color, table expected");
	}

	lua_rawgeti(L, -1, 1);
	lua_rawgeti(L, -2, 2);
	lua_rawgeti(L, -3, 3);
	lua_rawgeti(L, -4, 4);

	r = (int) luaL_checknumber(L, -4);
	g = (int) luaL_checknumber(L, -3);
	b = (int) luaL_checknumber(L, -2);
	if (lua_isnumber(L, -1)) {
		a = (int) luaL_checknumber(L, -1);
	}
	else {
		a = 0xFF;
	}

	lua_pop(L, 5);
 
	lua_pushnumber(L, (lua_Integer)((r << 24) | (g << 16) | (b << 8) | a) );
	return 1;
}


Uint32 jive_style_color(lua_State *L, int index, const char *key, Uint32 def, bool *is_set) {
	Uint32 col;

	JIVEL_STACK_CHECK_BEGIN(L);

	lua_pushcfunction(L, jiveL_style_color);
	lua_pushvalue(L, index);
	lua_pushstring(L, key);
	lua_pushnil(L);
	lua_call(L, 3, 1);

	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);

		if (is_set) {
			*is_set = 0;
		}
		return def;
	}

	col = (Uint32) lua_tointeger(L, -1);
	if (is_set) {
		*is_set = 1;
	}
	lua_pop(L, 1);

	JIVEL_STACK_CHECK_END(L);

	return col;
}


JiveSurface *jive_style_image(lua_State *L, int index, const char *key, JiveSurface * def) {
	JiveSurface *value;

	JIVEL_STACK_CHECK_BEGIN(L);

	lua_pushcfunction(L, jiveL_style_value);
	lua_pushvalue(L, index);
	lua_pushstring(L, key);
	tolua_pushusertype(L, def, "Surface");
	lua_call(L, 3, 1);

	value = tolua_tousertype(L, -1, 0);
	lua_pop(L, 1);

	JIVEL_STACK_CHECK_END(L);

	return value;
}


int jiveL_style_font(lua_State *L) {
	
	/* stack is:
	 * 1: widget
	 * 2: key
	 * 3: default
	 */

	jiveL_style_value(L);

	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);

		/* default font */
		tolua_pushusertype(L, jive_font_load("fonts/FreeSans.ttf", 15), "Font");
	}

	return 1;
}


JiveFont *jive_style_font(lua_State *L, int index, const char *key)  {
	JiveFont *value;

	JIVEL_STACK_CHECK_BEGIN(L);

	lua_pushcfunction(L, jiveL_style_font);
	lua_pushvalue(L, index);
	lua_pushstring(L, key);
	lua_pushnil(L);
	lua_call(L, 3, 1);

	value = (JiveFont *) tolua_tousertype(L, -1, NULL);
	lua_pop(L, 1);

	assert(value);

	JIVEL_STACK_CHECK_END(L);

	return value;
}


JiveAlign jive_style_align(lua_State *L, int index, char *key, JiveAlign def) {
	int v;

	const char *options[] = {
		"center",
		"left",
		"right",
		"top",
		"bottom",
		"top-left",
		"top-right",
		"bottom-left",
		"bottom-right",
		NULL
	};

	JIVEL_STACK_CHECK_BEGIN(L);


	lua_pushcfunction(L, jiveL_style_value);
	lua_pushvalue(L, index);
	lua_pushstring(L, key);
	lua_pushnil(L);
	lua_call(L, 3, 1);

	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);		
		return def;
	}

	v = luaL_checkoption(L, -1, options[def], options);
	lua_pop(L, 1);

	JIVEL_STACK_CHECK_END(L);

	return (JiveAlign) v;
}
