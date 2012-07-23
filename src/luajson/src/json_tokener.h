/*
 * $Id: json_tokener.h,v 1.9 2006/01/30 23:07:57 mclark Exp $
 *
 * Copyright (c) 2004, 2005 Metaparadigm Pte. Ltd.
 * Michael Clark <michael@metaparadigm.com>
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the MIT license. See COPYING for details.
 *
 */

#ifndef _json_tokener_h_
#define _json_tokener_h_

#include "lua.h"
#include "lauxlib.h"

enum json_tokener_error {
	json_tokener_success,
	json_tokener_error_parse_unexpected,
	json_tokener_error_parse_null,
	json_tokener_error_parse_boolean,
	json_tokener_error_parse_number,
	json_tokener_error_parse_array,
	json_tokener_error_parse_object,
	json_tokener_error_parse_string,
	json_tokener_error_parse_comment,
	json_tokener_error_parse_eof
};

enum json_tokener_state {
	json_tokener_state_eatws, // 0
	json_tokener_state_start, // 1
	json_tokener_state_finish, // 2
	json_tokener_state_null, // 3
	json_tokener_state_comment_start, // 4
	json_tokener_state_comment, // 5
	json_tokener_state_comment_eol, // 6
	json_tokener_state_comment_end, // 7
	json_tokener_state_string, // 8
	json_tokener_state_string_escape, // 9
	json_tokener_state_escape_unicode, // 10
	json_tokener_state_boolean, // 11
	json_tokener_state_number, // 12
	json_tokener_state_array, // 13
	json_tokener_state_array_sep, // 14
	json_tokener_state_object, // 15
	json_tokener_state_object_field_start, // 16
	json_tokener_state_object_field, // 17
	json_tokener_state_object_field_end, // 18
	json_tokener_state_object_value, // 19
	json_tokener_state_object_sep // 20
};

struct json_tokener
{
	lua_State *L;
	const char *source;
	int pos;
	luaL_Buffer B;
};

extern int json_tokener_parse(lua_State *L);

#endif
