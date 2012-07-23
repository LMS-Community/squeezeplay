/*
 * $Id: json_tokener.c,v 1.19 2006/01/30 23:07:57 mclark Exp $
 *
 * Copyright (c) 2004, 2005 Metaparadigm Pte. Ltd.
 * Michael Clark <michael@metaparadigm.com>
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the MIT license. See COPYING for details.
 *
 */

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "bits.h"
#include "json_tokener.h"


#if !HAVE_STRNCASECMP && defined(_MSC_VER)
  /* MSC has the version as _strnicmp */
# define strncasecmp _strnicmp
#elif !HAVE_STRNCASECMP
# error You do not have strncasecmp on your system.
#endif /* HAVE_STRNCASECMP */


static char *json_hex_chars = "0123456789abcdef";
static char *json_number_chars = "0123456789.+-eE";

static int json_tokener_do_parse(struct json_tokener *this);

int json_tokener_parse(lua_State *L)
{
  struct json_tokener tok;
  int err;

  tok.L = L;
  tok.source = lua_tostring(L, -1);
  tok.pos = 0;
  //tok.pb = printbuf_new();
  err = json_tokener_do_parse(&tok);
  //printbuf_free(tok.pb);
  return err;
}

#if !HAVE_STRNDUP
/* CAW: compliant version of strndup() */
char* strndup(const char* str, size_t n)
{
	if(str) {
  	    size_t len = strlen(str);
		size_t nn = min(len,n);
		char* s = (char*)malloc(sizeof(char) * (nn + 1));

		if(s) {
		   memcpy(s, str, nn);
		   s[nn] = '\0';
		}

		return s;
	}

	return NULL;
}
#endif

static int json_tokener_do_parse(struct json_tokener *this)
{
  enum json_tokener_state state, saved_state;
  enum json_tokener_error err = json_tokener_success;
  char quote_char = 0;
  int deemed_double = 0, start_offset = 0;
  size_t len;
  char c;

  state = json_tokener_state_eatws;
  saved_state = json_tokener_state_start;

  do {
    c = this->source[this->pos];

    //printf("state is %d c %d (%c)\n", state, c, c);
    switch(state) {

    case json_tokener_state_eatws:
      if(isspace(c)) {
	this->pos++;
      } else if(c == '/') {
	state = json_tokener_state_comment_start;
	start_offset = this->pos++;
      } else {
	state = saved_state;
      }
      break;

    case json_tokener_state_start:
      switch(c) {
      case '{':
	state = json_tokener_state_eatws;
	saved_state = json_tokener_state_object;
	lua_newtable(this->L);
	this->pos++;
	break;
      case '[':
	state = json_tokener_state_eatws;
	saved_state = json_tokener_state_array;
	lua_newtable(this->L);
	this->pos++;
	break;
      case 'N':
      case 'n':
	state = json_tokener_state_null;
	start_offset = this->pos++;
	break;
      case '"':
      case '\'':
	quote_char = c;
	luaL_buffinit(this->L, &(this->B));
	//printbuf_reset(this->pb);
	state = json_tokener_state_string;
	start_offset = ++this->pos;
	break;
      case 'T':
      case 't':
      case 'F':
      case 'f':
	state = json_tokener_state_boolean;
	start_offset = this->pos++;
	break;
#if defined(__GNUC__)
	  case '0' ... '9':
#else
	  case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
#endif
      case '-':
	deemed_double = 0;
	state = json_tokener_state_number;
	start_offset = this->pos++;
	break;
      default:
	err = json_tokener_error_parse_unexpected;
	goto out;
      }
      break;

    case json_tokener_state_finish:
      goto out;

    case json_tokener_state_null:
      if(strncasecmp("null", this->source + start_offset,
		     this->pos - start_offset))
	return -json_tokener_error_parse_null;
      if(this->pos - start_offset == 4) {
	lua_getglobal(this->L, "json");
	lua_getfield(this->L, -1, "null");
	lua_remove(this->L, -2);
	//lua_pushnil(this->L);
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else {
	this->pos++;
      }
      break;

    case json_tokener_state_comment_start:
      if(c == '*') {
	state = json_tokener_state_comment;
      } else if(c == '/') {
	state = json_tokener_state_comment_eol;
      } else {
	err = json_tokener_error_parse_comment;
	goto out;
      }
      this->pos++;
      break;

    case json_tokener_state_comment:
      if(c == '*') state = json_tokener_state_comment_end;
      this->pos++;
      break;

    case json_tokener_state_comment_eol:
      if(c == '\n') {
	// eat comments
	state = json_tokener_state_eatws;
      }
      this->pos++;
      break;

    case json_tokener_state_comment_end:
      if(c == '/') {
	// eat comments
	state = json_tokener_state_eatws;
      } else {
	state = json_tokener_state_comment;
      }
      this->pos++;
      break;

    case json_tokener_state_string:
      if(c == quote_char) {
	luaL_addlstring(&(this->B), this->source + start_offset,
			this->pos - start_offset);
	luaL_pushresult(&(this->B));
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else if(c == '\\') {
	saved_state = json_tokener_state_string;
	state = json_tokener_state_string_escape;
      }
      this->pos++;
      break;

    case json_tokener_state_string_escape:
      switch(c) {
      case '"':
      case '/':
      case '\\':
	luaL_addlstring(&(this->B), this->source + start_offset,
			this->pos - start_offset - 1);
	start_offset = this->pos++;
	state = saved_state;
	break;
      case 'b':
      case 'f':
      case 'n':
      case 'r':
      case 't':
	luaL_addlstring(&(this->B), this->source + start_offset,
			this->pos - start_offset - 1);
	if(c == 'b') luaL_addchar(&(this->B), '\b');
	else if(c == 'f') luaL_addchar(&(this->B), '\f');
	else if(c == 'n') luaL_addchar(&(this->B), '\n');
	else if(c == 'r') luaL_addchar(&(this->B), '\r');
	else if(c == 't') luaL_addchar(&(this->B), '\t');
	start_offset = ++this->pos;
	state = saved_state;
	break;
      case 'u':
	luaL_addlstring(&(this->B), this->source + start_offset,
			this->pos - start_offset - 1);
	start_offset = ++this->pos;
	state = json_tokener_state_escape_unicode;
	break;
      default:
	err = json_tokener_error_parse_string;
	goto out;
      }
      break;

    case json_tokener_state_escape_unicode:
      if(strchr(json_hex_chars, tolower(c))) {
	this->pos++;
	if(this->pos - start_offset == 4) {
	  unsigned char utf_out[3];
	  unsigned int ucs_char =
	    (hexdigit(*(this->source + start_offset)) << 12) +
	    (hexdigit(*(this->source + start_offset + 1)) << 8) +
	    (hexdigit(*(this->source + start_offset + 2)) << 4) +
	    hexdigit(*(this->source + start_offset + 3));
	  if (ucs_char < 0x80) {
	    utf_out[0] = ucs_char;
	    luaL_addlstring(&(this->B), (char *)utf_out, 1);
	  } else if (ucs_char < 0x800) {
	    utf_out[0] = 0xc0 | (ucs_char >> 6);
	    utf_out[1] = 0x80 | (ucs_char & 0x3f);
	    luaL_addlstring(&(this->B), (char *)utf_out, 2);
	  } else {
	    utf_out[0] = 0xe0 | (ucs_char >> 12);
	    utf_out[1] = 0x80 | ((ucs_char >> 6) & 0x3f);
	    utf_out[2] = 0x80 | (ucs_char & 0x3f);
	    luaL_addlstring(&(this->B), (char *)utf_out, 3);
	  }
	  start_offset = this->pos;
	  state = saved_state;
	}
      } else {
	err = json_tokener_error_parse_string;
	goto out;
      }
      break;

    case json_tokener_state_boolean:
      if(strncasecmp("true", this->source + start_offset,
		 this->pos - start_offset) == 0) {
	if(this->pos - start_offset == 4) {
	  lua_pushboolean(this->L, 1);
	  saved_state = json_tokener_state_finish;
	  state = json_tokener_state_eatws;
	} else {
	  this->pos++;
	}
      } else if(strncasecmp("false", this->source + start_offset,
			this->pos - start_offset) == 0) {
	if(this->pos - start_offset == 5) {
	  lua_pushboolean(this->L, 0);
	  saved_state = json_tokener_state_finish;
	  state = json_tokener_state_eatws;
	} else {
	  this->pos++;
	}
      } else {
	err = json_tokener_error_parse_boolean;
	goto out;
      }
      break;

    case json_tokener_state_number:
      if(!c || !strchr(json_number_chars, c)) {
	int numi;
	double numd;
	char *tmp = strndup(this->source + start_offset,
			    this->pos - start_offset);
	if(!deemed_double && sscanf(tmp, "%d", &numi) == 1) {
	    lua_pushnumber(this->L, numi);
	} else if(deemed_double && sscanf(tmp, "%lf", &numd) == 1) {
	    lua_pushnumber(this->L, numd);
	} else {
	  free(tmp);
	  err = json_tokener_error_parse_number;
	  goto out;
	}
	free(tmp);
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else {
	if(c == '.' || c == 'e' || c == 'E') deemed_double = 1;
	this->pos++;
      }
      break;

    case json_tokener_state_array:
      if(c == ']') {
	this->pos++;
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else {
	err = json_tokener_do_parse(this);
	if (err < 0) {
	  goto out;
	}
	len = lua_objlen(this->L, -2);
	lua_pushnumber(this->L, len + 1);
	lua_insert(this->L, -2);
	lua_settable(this->L, -3);
	saved_state = json_tokener_state_array_sep;
	state = json_tokener_state_eatws;
      }
      break;

    case json_tokener_state_array_sep:
      if(c == ']') {
	this->pos++;
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else if(c == ',') {
	this->pos++;
	saved_state = json_tokener_state_array;
	state = json_tokener_state_eatws;
      } else {
	return -json_tokener_error_parse_array;
      }
      break;

    case json_tokener_state_object:
      state = json_tokener_state_object_field_start;
      start_offset = this->pos;
      break;

    case json_tokener_state_object_field_start:
      if(c == '}') {
	this->pos++;
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else if (c == '"' || c == '\'') {
	luaL_buffinit(this->L, &(this->B));
	quote_char = c;
	state = json_tokener_state_object_field;
	start_offset = ++this->pos;
      } else {
	err = json_tokener_error_parse_object;
	goto out;
      }
      break;

    case json_tokener_state_object_field:
      if(c == quote_char) {
	luaL_addlstring(&(this->B), this->source + start_offset,
			this->pos - start_offset);
	luaL_pushresult(&(this->B));
	saved_state = json_tokener_state_object_field_end;
	state = json_tokener_state_eatws;
      } else if(c == '\\') {
	saved_state = json_tokener_state_object_field;
	state = json_tokener_state_string_escape;
      }
      this->pos++;
      break;

    case json_tokener_state_object_field_end:
      if(c == ':') {
	this->pos++;
	saved_state = json_tokener_state_object_value;
	state = json_tokener_state_eatws;
      } else {
	return -json_tokener_error_parse_object;
      }
      break;

    case json_tokener_state_object_value:
      err = json_tokener_do_parse(this);
      if (err < 0) {
	goto out;
      }
      lua_settable(this->L, -3);
      saved_state = json_tokener_state_object_sep;
      state = json_tokener_state_eatws;
      break;

    case json_tokener_state_object_sep:
      if(c == '}') {
	this->pos++;
	saved_state = json_tokener_state_finish;
	state = json_tokener_state_eatws;
      } else if(c == ',') {
	this->pos++;
	saved_state = json_tokener_state_object;
	state = json_tokener_state_eatws;
      } else {
	err = json_tokener_error_parse_object;
	goto out;
      }
      break;

    }
  } while(c);

  if(state != json_tokener_state_finish &&
     saved_state != json_tokener_state_finish)
    err = json_tokener_error_parse_eof;

 out:
  if(err == json_tokener_success) {
    return 0;
  }

  lua_pushfstring(this->L,
		  "json_tokener_do_parse: error=%d state=%d char=%c pos=%d\n",
		  err, state, c, this->pos);
  lua_error(this->L);
  return -1;
}
