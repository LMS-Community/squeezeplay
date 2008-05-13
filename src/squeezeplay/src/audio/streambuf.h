/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


extern size_t streambuf_get_size(void);

extern size_t streambuf_get_freebytes(void);

extern size_t streambuf_get_usedbytes(void);

extern void streambuf_mark_loop(void);

extern void streambuf_clear_loop(void);

extern bool_t streambuf_is_looping(void);

extern void streambuf_flush(void);

extern size_t streambuf_read(u8_t *buf, size_t min, size_t max, bool_t *streaming);

extern int streambuf_openL(lua_State *L);

extern int streambuf_closeL(lua_State *L);

extern int streambuf_flushL(lua_State *L);

extern int streambuf_getfdL(lua_State *L);

extern void streambuf_feed(u8_t *buf, size_t size);

extern size_t streambuf_feed_fd(int fd);

extern int streambuf_readL(lua_State *L);

extern int luaopen_streambuf(lua_State *L);
