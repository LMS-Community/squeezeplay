
#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

#include "json_tokener.h"

// define to \n for debugging output
#define NL ""


/* Define LUAJSON_API for dll exports on windows */
#ifndef LUAJSON_API
#define LUAJSON_API
#endif


static void l_json_encode_string(lua_State *L, int pos, luaL_Buffer *B) {
	size_t len;
	const char *str = lua_tolstring(L, pos, &len);

	unsigned int i;
	for (i=0; i<len; i++) {
		switch (str[i]) {
		case '"':
			luaL_addstring(B, "\\\"");
			break;
		case '\\':
			luaL_addstring(B, "\\\\");
			break;
		case '/':
			luaL_addstring(B, "\\/");
			break;
		case '\b':
			luaL_addstring(B, "\\b");
			break;
		case '\f':
			luaL_addstring(B, "\\f");
			break;
		case '\n':
			luaL_addstring(B, "\\n");
			break;
		case '\r':
			luaL_addstring(B, "\\r");
			break;
		case '\t':
			luaL_addstring(B, "\\t");
			break;

		default:
			luaL_addchar(B, str[i]);			
		}
	}
}


static void l_json_encode_value(lua_State *L, int pos, luaL_Buffer *B) {

	switch (lua_type(L, pos)) {
	case LUA_TNIL:
		luaL_addstring(B, "null");
		break;

	case LUA_TNUMBER: {
		const char *num;

		lua_pushvalue(L, pos); // work on a copy of the number
		num = lua_tostring(L, -1);
		// FIXME any other special cases?
		if (strcmp(num, "inf") == 0) {
			luaL_addstring(B, "23456789012E666");
		}
		else {
			luaL_addstring(B, num);
		}
		lua_pop(L, 1);
		break;
	}

	case LUA_TBOOLEAN:
		if (lua_toboolean(L, pos)) {
			luaL_addstring(B, "true");
		}
		else {
			luaL_addstring(B, "false");
		}
		break;

	case LUA_TSTRING:
		luaL_addchar(B, '"');
		l_json_encode_string(L, pos, B);
		luaL_addchar(B, '"');
		break;

	case LUA_TTABLE: {
		int type = 0;
		int arrayidx = 0;

		lua_pushnil(L); /* first key */
		while (lua_next(L, pos) != 0) {
			/* push key-value pair to stack base */
			lua_insert(L, 1);
			lua_insert(L, 1);

			if (type == 0) {
				if (lua_type(L, 1) == LUA_TNUMBER) {
					type = 1; /* array */
					luaL_addstring(B, "[" NL);
				}
				else {
					type = 2; /* object */
					luaL_addstring(B, "{" NL);
				}
			}
			else {
				luaL_addstring(B, "," NL);
			}

			if (type == 2) {
				/* output key */
				l_json_encode_value(L, 1, B);
				luaL_addstring(B, ":");
			}
			else {
				/* Bug 15329, there must be a bug in the Lua API, we don't seem to get nil array values via
				   lua_next. This hack checks for missing array indices which we assume are nil values. The
				   while loop is necessary in case 2 nil values are sequential.
				   TODO: handle when final array value is nil
				*/
				arrayidx++;
				while (lua_tonumber(L, 1) != arrayidx) {
					luaL_addstring(B, "null,");
					arrayidx++;
				}
			}
			
			/* output value */
			l_json_encode_value(L, 2, B);

			/* restore key to stack top */
			lua_pushvalue(L, 1);
			lua_remove(L, 1);

			/* pop value */
			lua_remove(L, 1);
		}

		switch (type) {
		case 0: /* empty */
			// we don't know if this is an array or object
			luaL_addstring(B, "[]");
			break;

		case 1: /* array */
			luaL_addstring(B, NL "]");
			break;

		case 2: /* object */
			luaL_addstring(B, NL "}");
			break;
		}
		break;
	}

	case LUA_TUSERDATA:
		/* special json.null value? */
		lua_getglobal(L, "json");
		lua_getfield(L, -1, "null");
		if (lua_equal(L, pos, -1)) {
			lua_pop(L, 2);
			luaL_addstring(B, "null");
			break;
		}
		/* fall through */

	case LUA_TFUNCTION:
	case LUA_TTHREAD:
	case LUA_TLIGHTUSERDATA:
		lua_pushstring(L, "Cannot encode function, userdata or thread to json");
		lua_error(L);
		break;
	}
}


static int l_json_encode(lua_State *L) {
	luaL_Buffer B;

	luaL_checkany(L, -1);

	luaL_buffinit(L, &B);
	l_json_encode_value(L, lua_gettop(L), &B);
	luaL_pushresult(&B);
	return 1;
}

static int l_json_decode(lua_State *L) {
	int err;

	luaL_checkstring(L, -1);

	err = json_tokener_parse(L);
	if (err < 0) {
		printf("got err %d\n", err);
		return 0;
	}
	return 1;
}

static int l_json_null_string(lua_State *L) {
	lua_pushstring(L, "null");
	return 1;
}

static const struct luaL_Reg jsonlib[] = {
	{ "decode", l_json_decode },
	{ "encode", l_json_encode },
	{ NULL, NULL }
};

LUAJSON_API int luaopen_json(lua_State *L) {
	luaL_register(L, "json", jsonlib);

	lua_newuserdata(L, 1);

	lua_getglobal(L, "json");
	lua_pushvalue(L, -2);
	lua_setfield(L, -2, "null");

	lua_newtable(L);
	lua_pushcfunction(L, l_json_null_string);
	lua_setfield(L, -2, "__tostring");

	lua_setmetatable(L, -2);

	return 1;
}

