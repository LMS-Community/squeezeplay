/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#if defined(WIN32)

#include <winsock2.h>

typedef SOCKET socket_t;
#define CLOSESOCKET(s) closesocket(s)
#define SHUT_WR SD_SEND
#define SOCKETERROR WSAGetLastError()

#else

typedef int socket_t;
#define CLOSESOCKET(s) close(s)
#define INVALID_SOCKET (-1)
#define SOCKETERROR errno

#endif


#define STREAMBUF_SIZE (3 * 1024 * 1024)

static u8_t streambuf_buf[STREAMBUF_SIZE];
static struct fifo streambuf_fifo;
static size_t streambuf_lptr = 0;
static bool_t streambuf_loop = FALSE;
static bool_t streambuf_streaming = FALSE;
static u64_t streambuf_bytes_received = 0;

/* streambuf filter, used to parse metadata */
static streambuf_filter_t streambuf_filter;
static streambuf_filter_t streambuf_next_filter;

static bool_t streambuf_copyright;

/* shoutcast metadata state */
static u32_t icy_meta_interval;
static s32_t icy_meta_remaining;

struct chunk {
	u8_t *buf;
	size_t len;
};

static void proxy_chunk (u8_t *buf, size_t size, lua_State *L)
{
	if (L && size) {
		struct chunk *chunk;
		/*
		 * Send chunk to proxy clients
		 *
		 * Relies on this being sent before wrap-around occurs
		 * which is ensured by Playback.lua not scheduling any more reads
		 * on the stream until the queued chunk (or, initially, chunks)
		 * has been written to all proxy clients.
		 *
		 * At the start of a stream, there may be up to 3 queued chunks:
		 * 	1. the header
		 * 	2. the remains of the initial read up until fifo wrap-around
		 * 	3. the remains of the initial read after fifo wrap-around
		 */
		/*  */
		lua_getfield(L, 2, "_proxyQueueSegment");
		lua_pushvalue(L, 2);
		chunk = lua_newuserdata(L, sizeof(*chunk));
		chunk->buf = buf;
		chunk->len = size;
		lua_call(L, 2, 0);
	}
}

size_t streambuf_get_size(void) {
	return STREAMBUF_SIZE;
}


size_t streambuf_get_freebytes(void) {
	size_t n;

	fifo_lock(&streambuf_fifo);

	n = fifo_bytes_free(&streambuf_fifo);

	fifo_unlock(&streambuf_fifo);

	return n;
}


size_t streambuf_get_usedbytes(void) {
	size_t n;

	fifo_lock(&streambuf_fifo);

	n = fifo_bytes_used(&streambuf_fifo);

	fifo_unlock(&streambuf_fifo);

	return n;
}

size_t streambuf_fast_usedbytes(void) {
	ASSERT_FIFO_LOCKED(&streambuf_fifo);

	return fifo_bytes_used(&streambuf_fifo);
}

/* returns true if the stream is still open but cannot yet supply the requested bytes */
bool_t streambuf_would_wait_for(size_t bytes) {
	size_t n;
	
	if (!streambuf_streaming) {
		return FALSE;
	}

	fifo_lock(&streambuf_fifo);

	n = fifo_bytes_used(&streambuf_fifo);

	fifo_unlock(&streambuf_fifo);

	return n < bytes;
}

void streambuf_get_status(size_t *size, size_t *usedbytes, u32_t *bytesL, u32_t *bytesH) {

	fifo_lock(&streambuf_fifo);

	*size = STREAMBUF_SIZE;
	*usedbytes = fifo_bytes_used(&streambuf_fifo);
	*bytesL = streambuf_bytes_received & 0xFFFFFFFF;
	*bytesH = streambuf_bytes_received >> 32;

	fifo_unlock(&streambuf_fifo);
}


void streambuf_flush(void) {
	fifo_lock(&streambuf_fifo);

	streambuf_fifo.rptr = 0;
	streambuf_fifo.wptr = 0;

	fifo_unlock(&streambuf_fifo);
}


static void streambuf_feedL(u8_t *buf, size_t size, lua_State *L) {
	size_t n;

	fifo_lock(&streambuf_fifo);

	streambuf_streaming = TRUE;

	streambuf_bytes_received += size;

	while (size) {
		n = fifo_bytes_until_wptr_wrap(&streambuf_fifo);

		if (n > size) {
			n = size;
		}

		memcpy(streambuf_buf + streambuf_fifo.wptr, buf, n);

		proxy_chunk(streambuf_buf + streambuf_fifo.wptr, n, L);

		fifo_wptr_incby(&streambuf_fifo, n);
		buf  += n;
		size -= n;
	}

	fifo_unlock(&streambuf_fifo);
}

void streambuf_feed(u8_t *buf, size_t size) {
	streambuf_feedL(buf, size, 0);
}

ssize_t streambuf_feed_fd(int fd, lua_State *L) {
	ssize_t n, size;

	fifo_lock(&streambuf_fifo);

	streambuf_streaming = TRUE;

	size = fifo_bytes_free(&streambuf_fifo);
	if (size < 4096) {
		fifo_unlock(&streambuf_fifo);
		return -ENOSPC; /* no space */
	}

	n = fifo_bytes_until_wptr_wrap(&streambuf_fifo);
	if (n > size) {
		n = size;
	}

	n = recv(fd, streambuf_buf + streambuf_fifo.wptr, n, 0);
	if (n < 0) {
		streambuf_streaming = FALSE;

		fifo_unlock(&streambuf_fifo);
		return -SOCKETERROR;
	}
	else if (n == 0) {
		streambuf_streaming = FALSE;
	}
	else {
		proxy_chunk(streambuf_buf + streambuf_fifo.wptr, n, L);

		fifo_wptr_incby(&streambuf_fifo, n);

		streambuf_bytes_received += n;
	}

	fifo_unlock(&streambuf_fifo);
	return n;
}


size_t streambuf_fast_read(u8_t *buf, size_t min, size_t max, bool_t *streaming) {
	size_t sz, w;

	ASSERT_FIFO_LOCKED(&streambuf_fifo);

	if (streaming) {
		*streaming = streambuf_streaming;
	}

	sz = fifo_bytes_used(&streambuf_fifo);
	if (sz < min) {
		return 0; /* underrun */
	}

	if (sz > max) {
		sz = max;
	}

	w = fifo_bytes_until_rptr_wrap(&streambuf_fifo);
	if (w < sz) {
		sz = w;
	}

	memcpy(buf, streambuf_buf + streambuf_fifo.rptr, sz);
	fifo_rptr_incby(&streambuf_fifo, sz);

	fifo_signal(&streambuf_fifo);

	if ((streambuf_fifo.rptr == streambuf_fifo.wptr) && streambuf_loop) {
		streambuf_fifo.rptr = streambuf_lptr;
	}

	return sz;
}


size_t streambuf_read(u8_t *buf, size_t min, size_t max, bool_t *streaming) {
	ssize_t n;

	fifo_lock(&streambuf_fifo);

	if (streambuf_filter) {
		/* filters are called with the streambuf locked */
		n = streambuf_filter(buf, min, max, streaming);

		if (n < 0) {
			/* filter returned an error */
			current_decoder_state |= DECODE_STATE_ERROR;
			n = 0;
		}
	}
	else {
		n = streambuf_fast_read(buf, min, max, streaming);
	}

	fifo_unlock(&streambuf_fifo);

	return n;
}


void streambuf_filter_lock(void)
{
	fifo_lock(&streambuf_fifo);
}


void streambuf_filter_unlock(void)
{
	fifo_unlock(&streambuf_fifo);
}


bool_t streambuf_is_copyright() {
	return streambuf_copyright;
}


void streambuf_set_copyright() {
	streambuf_copyright = TRUE;
}


void streambuf_set_streaming(bool_t is_streaming) {
	streambuf_streaming = is_streaming;
}


void streambuf_set_filter(streambuf_filter_t filter) {
	fifo_lock(&streambuf_fifo);

	streambuf_next_filter = filter;

	fifo_unlock(&streambuf_fifo);
}


ssize_t streambuf_icy_filter(u8_t *buf, size_t min, size_t max, bool_t *streaming) {
	size_t avail, r, n = 0;
	
	/* streambuf is locked */

	/* icy is only used with the mp3 decoder, it always uses min=0.
	 * let's use this to make this code simpler.
	 */
	assert(min == 0);

	avail = fifo_bytes_used(&streambuf_fifo);
	while (avail && n < max) {
		if (icy_meta_remaining > 0) {
			/* we're waiting for the metadata */
			r = icy_meta_remaining;
			if (r > max - n) {
				r = max - n;
			}

			r = streambuf_fast_read(buf, 0, r, streaming);

			buf += r;
			n += r;
			icy_meta_remaining -= r;

		}
		else if (icy_meta_remaining == 0) {
			/* we're reading the metadata length byte */
			u8_t len;

			r = streambuf_fast_read(&len, 1, 1, NULL);
			assert(r == 1);

			icy_meta_remaining = -16 * len;
			if (!icy_meta_remaining) {
				/* it's a zero length metadata, reset to the next interval */
				icy_meta_remaining = icy_meta_interval;
			}
		}
		else {
			/* we're reading the metadata */
			u8_t *icy_buf;
			size_t icy_len = -icy_meta_remaining;

			if (avail < icy_len) {
				/* wait for more data */
				break;
			}

			icy_buf = alloca(icy_len);
			r = streambuf_fast_read(icy_buf, icy_len, icy_len, NULL);
			assert(r == icy_len);
			LOG_DEBUG(log_audio_decode, "got icy metadata: %s", (char *) icy_buf);

			decode_queue_metadata(SHOUTCAST, icy_buf, icy_len);

			icy_meta_remaining = icy_meta_interval;
		}

		avail = fifo_bytes_used(&streambuf_fifo);
	}

	return n;
}


bool_t streambuf_is_icy()
{
	return streambuf_filter == streambuf_icy_filter;
}


struct stream {
	socket_t fd;
	int num_crlf;

	/* save http headers or body */
	u8_t *body;
	int body_len;
};


static int stream_load_loopL(lua_State *L) {
	int fd;
	ssize_t n, len;
	char *filename;

	/*
	 * 1: self
	 * 2: file
	 */

	filename = alloca(PATH_MAX);
	if (!squeezeplay_find_file(lua_tostring(L, 2), filename)) {
		LOG_ERROR(log_audio_decode, "Can't find image %s\n", lua_tostring(L, 2));
		return 0;
	}


	if ((fd = open(filename, O_RDONLY)) < 0) {
		LOG_ERROR(log_audio_decode, "Can't open %s", lua_tostring(L, 2));
		return 0;
	}

	fifo_lock(&streambuf_fifo);

	streambuf_lptr = streambuf_fifo.wptr;
	streambuf_loop = TRUE;

	n = fifo_bytes_free(&streambuf_fifo);
	if ((len = read(fd, streambuf_buf + streambuf_fifo.wptr, n)) < 0) {
		goto read_err;
	}
	fifo_wptr_incby(&streambuf_fifo, len);

	n = fifo_bytes_free(&streambuf_fifo);
	if (n) {
		if ((n = read(fd, streambuf_buf + streambuf_fifo.wptr, n)) < 0) {
			goto read_err;
		}
		fifo_wptr_incby(&streambuf_fifo, n);
		len += n;
	}

	streambuf_streaming = FALSE;
	streambuf_bytes_received = len;
	streambuf_filter = streambuf_next_filter;
	streambuf_next_filter = NULL;

	fifo_unlock(&streambuf_fifo);
	close(fd);

	return 0;

 read_err:
	fifo_unlock(&streambuf_fifo);
	close(fd);

	return 0;
}


static int stream_connectL(lua_State *L) {

	/*
	 * 1: self
	 * 2: server_ip
	 * 3: server_port
	 */

	struct sockaddr_in serv_addr;
	struct stream *stream;
	int flags;
	int err;
	socket_t fd;

	/* Server address and port */
	memset(&serv_addr, 0, sizeof(serv_addr));
	if (lua_type(L, 2) == LUA_TSTRING) {
		serv_addr.sin_addr.s_addr = inet_addr(luaL_checkstring(L, 2));
	}
	else {
		serv_addr.sin_addr.s_addr = htonl(luaL_checkinteger(L, 2));
	}
	serv_addr.sin_port = htons(luaL_checkinteger(L, 3));
	serv_addr.sin_family = AF_INET;


	LOG_DEBUG(log_audio_decode, "streambuf connect %s:%d", inet_ntoa(serv_addr.sin_addr), ntohs(serv_addr.sin_port));

	/* Create socket */
	fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd == INVALID_SOCKET) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(SOCKETERROR));
		return 2;
	}

	/* Make socket non-blocking */
#if defined(WIN32)
	{
		u_long iMode = 0;
		flags = ioctlsocket(fd, FIONBIO, &iMode);
	}
#else
	flags = fcntl(fd, F_GETFL, 0);
	flags |= O_NONBLOCK;
	fcntl(fd, F_SETFL, flags);
#endif

	/* Connect socket */
	err = connect(fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr));
	if (err != 0
#if !defined(WIN32)
		&&  SOCKETERROR != EINPROGRESS
#endif
		) {
		CLOSESOCKET(fd);

		lua_pushnil(L);
		lua_pushstring(L, strerror(SOCKETERROR));
		return 2;
	}

	/* Stream object */
	stream = lua_newuserdata(L, sizeof(struct stream));

	memset(stream, 0, sizeof(*stream));
	stream->fd = fd;

	luaL_getmetatable(L, "squeezeplay.stream");
	lua_setmetatable(L, -2);

	fifo_lock(&streambuf_fifo);

	streambuf_loop = FALSE;
	streambuf_bytes_received = 0;
	streambuf_copyright = FALSE;
	streambuf_filter = streambuf_next_filter;
	streambuf_next_filter = NULL;

	fifo_unlock(&streambuf_fifo);

	return 1;
}


static int stream_disconnectL(lua_State *L) {
	struct stream *stream;

	/*
	 * 1: self
	 */

	stream = lua_touserdata(L, 1);

	if (stream->body) {
		free(stream->body);
		stream->body = NULL;
		stream->body_len = 0;
	}

	if (stream->fd) {
		CLOSESOCKET(stream->fd);
		stream->fd = 0;
	}

	return 0;
}


static int stream_flushL(lua_State *L) {
	streambuf_flush();
	return 0;
}


static int stream_getfdL(lua_State *L) {
	struct stream *stream;

	/*
	 * 1: self
	 */

	stream = lua_touserdata(L, 1);

	if (stream->fd > 0) {
		lua_pushinteger(L, stream->fd);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}


static int stream_readL(lua_State *L) {
	struct stream *stream;
	u8_t buf[1024];
	u8_t *buf_ptr, *body_ptr;
	size_t header_len;
	ssize_t n;

	/*
	 * 1: Stream (self)
	 * 2: Playback (self)
	 */

	stream = lua_touserdata(L, 1);


	/* shortcut, just read to streambuf */
	if (stream->num_crlf == 4) {
		n = streambuf_feed_fd(stream->fd, L);
		if (n == 0) {
			/* closed */
			lua_pushboolean(L, FALSE);
			return 1;
		}

		if (n == -ENOSPC) {
			lua_pushinteger(L, 0);
			return 1;
		}

		if (n < 0) {
			CLOSESOCKET(stream->fd);

			lua_pushnil(L);
			lua_pushstring(L, strerror(n));
			return 2;

		}

		lua_pushinteger(L, n);
		return 1;
	}

	/* read buffer, but we must not overflow the stream fifo */
	n = streambuf_get_freebytes();
	if (n > (ssize_t)sizeof(buf)) {
		n = sizeof(buf);
	}

	n = recv(stream->fd, buf, sizeof(buf), 0);

	/* socket closed */
	if (n == 0) {
		lua_pushboolean(L, FALSE);
		return 1;
	}

	/* socket error */
	if (n < 0) {
		// XXXX do we need to handle timeout here?
		CLOSESOCKET(stream->fd);

		lua_pushnil(L);
		lua_pushstring(L, strerror(SOCKETERROR));
		return 2;
	}

	buf_ptr = buf;


	/* read http header */
	if (stream->num_crlf < 4) {
		stream->body = realloc(stream->body, stream->body_len + n);
		body_ptr = stream->body + stream->body_len;
		stream->body_len += n;

		while (n) {
			*body_ptr++ = *buf_ptr;

			if (*buf_ptr == '\n' || *buf_ptr == '\r') {
				stream->num_crlf++;
			}
			else {
				stream->num_crlf = 0;
			}

			buf_ptr++;
			n--;

			if (stream->num_crlf == 4) {
				header_len = body_ptr - stream->body;

				//LOG_DEBUG(log_audio_decode, "headers %d %*s\n", header_len, header_len, stream->body);

				/* Send headers to SqueezeCenter */
				lua_getfield(L, 2, "_streamHttpHeaders");
				lua_pushvalue(L, 2);
				lua_pushlstring(L, (char *)stream->body, header_len);
				lua_call(L, 2, 0);

				/* do not free the header here - leave it to disconnect -
				 * so that it can be used by the proxy code
				 */

				/* Send headers to proxy clients */
				proxy_chunk(stream->body, header_len, L);

				break;
			}
		}
	}

	/* we need to loop when playing sound effects, so we need to remember where the stream starts */
	streambuf_lptr = streambuf_fifo.wptr;

	/* feed remaining buffer */
	streambuf_feedL(buf_ptr, n, L);

	lua_pushboolean(L, TRUE);
	return 1;
}


static int stream_writeL(lua_State *L) {
	struct stream *stream;
	const char *header;
	ssize_t n;
	size_t len;

	/*
	 * 1: Stream (self)
	 * 2: Playback (self)
	 * 3: header
	 */

	stream = lua_touserdata(L, 1);
	header = lua_tolstring(L, 3, &len);

	while (len > 0) {
		n = send(stream->fd, header, len, 0);

		if (n < 0) {
			CLOSESOCKET(stream->fd);

			lua_pushnil(L);
			lua_pushstring(L, strerror(SOCKETERROR));
			return 2;
		}

		len -= n;
	}

	/*
	if (shutdown(stream->fd, SHUT_WR) != 0) {
		CLOSESOCKET(stream->fd);

		lua_pushnil(L);
		lua_pushstring(L, strerror(SOCKETERROR));
		return 2;
	}
	*/

	lua_pushboolean(L, TRUE);
	return 1;
}


static int stream_proxyWriteL(lua_State *L) {
	struct stream *stream;
	struct chunk *chunk;
	ssize_t n;
	size_t len, offset;

	/*
	 * 1: Stream (self)
	 * 2: Proxy stream
	 * 3: chunk
	 * 4: offset
	 */

	stream = lua_touserdata(L, 2);
	chunk = lua_touserdata(L, 3);
	offset = lua_tointeger(L, 4);

	len = chunk->len - offset;
	n = send(stream->fd, chunk->buf + offset, len,
#ifdef MSG_NOSIGNAL
										MSG_NOSIGNAL
#else
										0
#endif
										);
	if (n < 0) {
		if (errno != EAGAIN) {
			lua_pushnil(L);
			lua_pushstring(L, strerror(SOCKETERROR));
			return 2;
		}
	} else if ((size_t)n < len) {
		offset += n;
	} else {
		/* wrote it all */
		lua_pushnil(L);
		return 1;
	}
	lua_pushinteger(L, offset);
	return 1;
}


/* feed data from a lua string into the streambuf fifo */
static int stream_feedfromL(lua_State *L) {
	struct stream *stream;
	u8_t *data;
	size_t len, n;

	/*
	 * 1: Stream (self)
	 * 2: string to enqueue to streambuf
	 */

	n = streambuf_get_freebytes();

	if (n == 0) {
		lua_pushinteger(L, 0);
		return 1;
	}

	stream = lua_touserdata(L, 1);
	data = (u8_t*)lua_tolstring(L, 2, &len);

	if (n > len) {
		n = len;
	}

	streambuf_feed(data, n);

	lua_pushinteger(L, n);
	return 1;
}


/* read data from the stream socket into a lua string */
static int stream_readtoL(lua_State *L) {
	struct stream *stream;
	char buf[4094];
	int n;
	/*
	 * 1: Stream (self)
	 */

	stream = lua_touserdata(L, 1);

	n = recv(stream->fd, buf, sizeof(buf), 0);	

	if (n > 0) {
		lua_pushlstring(L, buf, n);
		return 1;
	} else if (n == -1 && errno == EAGAIN) {
		lua_pushnil(L);
		return 1;
	} else {
		CLOSESOCKET(stream->fd);
		lua_pushnil(L);
		lua_pushstring(L, strerror(SOCKETERROR));
		return 2;
	}
}


/* read bytes from the streaming socket and discard - used by network test to measure network throughput*/
static int stream_readtonullL(lua_State *L) {
	struct stream *stream;
	char buf[4094];
	int n;
	/*
	 * 1: Stream (self)
	 */

	stream = lua_touserdata(L, 1);

	n = recv(stream->fd, buf, sizeof(buf), 0);	

	if (n > 0) {
		fifo_lock(&streambuf_fifo);
		streambuf_bytes_received += n;
		fifo_unlock(&streambuf_fifo);
		lua_pushinteger(L, n);
		return 1;
	} else if (n == -1 && errno == EAGAIN) {
		lua_pushinteger(L, 0);
		return 1;
	} else {
		CLOSESOCKET(stream->fd);
		lua_pushnil(L);
		lua_pushstring(L, strerror(n));
		return 2;
	}
}


static int stream_setstreamingL(lua_State *L) {
	/*
	 * 1: Stream (self)
	 * 1: Boolean steaming state, used by lua protocol handlers to set streaming state
	 */
	streambuf_streaming = lua_toboolean(L, 2);

	return 0;
}


static int stream_mark_loopL(lua_State *L) {
	fifo_lock(&streambuf_fifo);

	streambuf_loop = TRUE;

	fifo_unlock(&streambuf_fifo);

	return 0;
}


static int stream_icy_metaintervalL(lua_State *L) {
	/*
	 * 1: Stream (self)
	 * 2: meta interval
	 */

	fifo_lock(&streambuf_fifo);

	streambuf_filter = streambuf_icy_filter;

	icy_meta_interval = lua_tointeger(L, 2);
	icy_meta_remaining = icy_meta_interval;

	fifo_unlock(&streambuf_fifo);

	return 0;
}


static const struct luaL_Reg stream_f[] = {
	{ "connect", stream_connectL },
	{ "flush", stream_flushL },
	{ "loadLoop", stream_load_loopL },
	{ "markLoop", stream_mark_loopL },
	{ "icyMetaInterval", stream_icy_metaintervalL },
	{ "proxyWrite", stream_proxyWriteL },
	{ NULL, NULL }
};

static const struct luaL_Reg stream_m[] = {
	{ "__gc", stream_disconnectL },
	{ "disconnect", stream_disconnectL },
	{ "getfd", stream_getfdL },
	{ "read", stream_readL },
	{ "write", stream_writeL },
	{ "feedFromLua", stream_feedfromL },
	{ "readToLua", stream_readtoL },
	{ "readToNull", stream_readtonullL },
	{ "setStreaming", stream_setstreamingL },
	{ NULL, NULL }
};


int luaopen_streambuf(lua_State *L) {
	fifo_init(&streambuf_fifo, STREAMBUF_SIZE, false);

	/* stream methods */
	luaL_newmetatable(L, "squeezeplay.stream");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, NULL, stream_m);

	/* register lua functions */
	luaL_register(L, "squeezeplay.stream", stream_f);

	return 0;
}
