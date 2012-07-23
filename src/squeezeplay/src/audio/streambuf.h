/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


/* streambuf filter, used to parse metadata */
typedef ssize_t (*streambuf_filter_t)(u8_t *buf, size_t min, size_t max, bool_t *streaming);


/* Stream metadata */

enum metadata_type {
	SHOUTCAST = 0,
	WMA_GUID = 1,
	VORBIS_META = 2,
};

extern void decode_queue_metadata(enum metadata_type type, u8_t *metadata, size_t metadata_len);

extern void decode_queue_packet(void *data, size_t len);

/* Stream buffer */

extern size_t streambuf_get_size(void);

extern size_t streambuf_get_freebytes(void);

extern size_t streambuf_get_usedbytes(void);

extern size_t streambuf_fast_usedbytes(void);

extern bool_t streambuf_would_wait_for(size_t bytes);

extern void streambuf_get_status(size_t *size, size_t *usedbytes, u32_t *bytesL, u32_t *bytesH);

extern void streambuf_flush(void);

extern void streambuf_feed(u8_t *buf, size_t size);

/* the mutex should be locked when using fast read */
extern size_t streambuf_fast_read(u8_t *buf, size_t min, size_t max, bool_t *streaming);

extern size_t streambuf_read(u8_t *buf, size_t min, size_t max, bool_t *streaming);

extern ssize_t streambuf_feed_fd(int fd, lua_State *L);

extern bool_t streambuf_is_copyright();

extern void streambuf_set_copyright();

extern void streambuf_set_filter(streambuf_filter_t filter);

extern bool_t streambuf_is_icy();

extern int luaopen_streambuf(lua_State *L);
