/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


void jive_pushevent(lua_State *L, JiveEvent *event) {
	JiveEvent *obj = lua_newuserdata(L, sizeof(JiveEvent));

	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");
	lua_getfield(L, -1, "Event");

	lua_setmetatable(L, -4);
	lua_pop(L, 2);

	/* copy event data */
	memcpy(obj, event, sizeof(JiveEvent));
}

int jiveL_event_new(lua_State *L) {
	
	/* stack is:
	 * 1: jive.ui.Event
	 * 2: type
	 * 3: value (optional)
	 */

	JiveEvent *event = lua_newuserdata(L, sizeof(JiveEvent));

	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");
	lua_getfield(L, -1, "Event");

	lua_setmetatable(L, -4);
	lua_pop(L, 2);

	/* send attributes */
	event->type = lua_tointeger(L, 2);
	if (!lua_isnil(L, 3)) {
		switch (event->type) {
		case JIVE_EVENT_SCROLL:
			event->scroll_rel = lua_tointeger(L, 3);
			break;
		
		case JIVE_EVENT_KEY_DOWN:
		case JIVE_EVENT_KEY_UP:
		case JIVE_EVENT_KEY_PRESS:
		case JIVE_EVENT_KEY_HOLD:
			event->key_code = lua_tointeger(L, 3);
			break;
		
		case JIVE_EVENT_MOUSE_DOWN:
		case JIVE_EVENT_MOUSE_UP:
		case JIVE_EVENT_MOUSE_PRESS:
		case JIVE_EVENT_MOUSE_HOLD:
			event->mouse_x = lua_tointeger(L, 3);
			event->mouse_y = lua_tointeger(L, 4);
			break;
    	
		default:
			break;
		}
	}

	return 1;
}

int jiveL_event_get_type(lua_State *L) {
	JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
	if (event == NULL) {
		luaL_error(L, "invalid Event");
	}

	lua_pushinteger(L, event->type);

	return 1;
}


int jiveL_event_get_scroll(lua_State *L) {
	JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
	if (event == NULL) {
		luaL_error(L, "invalid Event");
	}

	switch (event->type) {
	case JIVE_EVENT_SCROLL:
		lua_pushinteger(L, event->scroll_rel);
		return 1;

	default:
		luaL_error(L, "Not a scroll event");
	}
	return 0;
}


int jiveL_event_get_keycode(lua_State *L) {
	JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
	if (event == NULL) {
		luaL_error(L, "invalid Event");
	}

	switch (event->type) {
	case JIVE_EVENT_KEY_DOWN:
	case JIVE_EVENT_KEY_UP:
	case JIVE_EVENT_KEY_PRESS:
	case JIVE_EVENT_KEY_HOLD:
		lua_pushinteger(L, event->key_code);
		return 1;

	default:
		luaL_error(L, "Not a key event");
	}
	return 0;
}


int jiveL_event_get_mouse(lua_State *L) {
	JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
	if (event == NULL) {
		luaL_error(L, "invalid Event");
	}

	switch (event->type) {
	case JIVE_EVENT_MOUSE_DOWN:
	case JIVE_EVENT_MOUSE_UP:
	case JIVE_EVENT_MOUSE_PRESS:
	case JIVE_EVENT_MOUSE_HOLD:
		lua_pushinteger(L, event->mouse_x);
		lua_pushinteger(L, event->mouse_y);
		return 2;

	default:
		luaL_error(L, "Not a mouse event");
	}
	return 0;
}


int jiveL_event_tostring(lua_State* L) {
	luaL_Buffer buf;

	JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
	if (event == NULL) {
		luaL_error(L, "invalid Event");
	}

	luaL_buffinit(L, &buf);
	lua_pushfstring(L, "Event(type=");
	luaL_addvalue(&buf);

	switch (event->type) {
	case JIVE_EVENT_NONE:
		lua_pushstring(L, "none");
		break;
					
	case JIVE_EVENT_SCROLL:
		lua_pushfstring(L, "SCROLL rel=%d", event->scroll_rel);
		break;
		
	case JIVE_EVENT_KEY_DOWN:
		lua_pushfstring(L, "KEY_DOWN code=%d", event->key_code);
		break;
	case JIVE_EVENT_KEY_UP:
		lua_pushfstring(L, "KEY_UP code=%d", event->key_code);
		break;
	case JIVE_EVENT_KEY_PRESS:
		lua_pushfstring(L, "KEY_PRESS code=%d", event->key_code);
		break;
	case JIVE_EVENT_KEY_HOLD:
		lua_pushfstring(L, "KEY_HOLD code=%d", event->key_code);
		break;
		
	case JIVE_EVENT_MOUSE_DOWN:
		lua_pushfstring(L, "MOUSE_DOWN x=%d,y=%d", event->mouse_x, event->mouse_y);
		break;
	case JIVE_EVENT_MOUSE_UP:
		lua_pushfstring(L, "MOUSE_UP x=%d,y=%d", event->mouse_x, event->mouse_y);
		break;
	case JIVE_EVENT_MOUSE_PRESS:
		lua_pushfstring(L, "MOUSE_PRESS x=%d,y=%d", event->mouse_x, event->mouse_y);
		break;
	case JIVE_EVENT_MOUSE_HOLD:
		lua_pushfstring(L, "MOUSE_HOLD x=%d,y=%d", event->mouse_x, event->mouse_y);
		break;
    
	case JIVE_EVENT_WINDOW_PUSH:
		lua_pushstring(L, "WINDOW_PUSH");
		break;
	case JIVE_EVENT_WINDOW_POP:
		lua_pushstring(L, "WINDOW_POP");
		break;
	case JIVE_EVENT_WINDOW_ACTIVE:
		lua_pushstring(L, "WINDOW_ACTIVE");
		break;
	case JIVE_EVENT_WINDOW_INACTIVE:
		lua_pushstring(L, "WINDOW_INACTIVE");
		break;
		
	case JIVE_EVENT_SHOW:
		lua_pushstring(L, "SHOW");
		break;
	case JIVE_EVENT_HIDE:
		lua_pushstring(L, "HIDE");
		break;
	case JIVE_EVENT_FOCUS_GAINED:
		lua_pushstring(L, "FOCUS_GAINED");
		break;
	case JIVE_EVENT_FOCUS_LOST:
		lua_pushstring(L, "FOCUS_LOST");
		break;
		
	default:
		break;
	}
	luaL_addvalue(&buf);
	
	luaL_addstring(&buf, ")");
	luaL_pushresult(&buf);

	return 1;
}

