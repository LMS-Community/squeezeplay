/* 
   This module provides the C side of the rtmp implementation - see also jive.audio.Rtmp.lua

   The module implements a subset of the Adobe RTMP protocol as specified by:
    http://www.adobe.com/devnet/rtmp/pdf/rtmp_specification_1.0.pdf

   (c) Adrian Smith (Triode), 2009, 2010, 2011, triode1@btinternet.com

   The protocol state machine and all packet processing is now implemented in C to improve performance and resource demands.
   The remaining lua code is used to create serialised rtmp request packets which are passed to the C protocol implementation.

   The implementation makes the following assumptions:

   1) streams use a streamingId of 1 (it ignores the streamingId inside the amf0 _result reponse to a createStream message)
   2) only implements single byte chunk headers (chunk id < 63)
   3) timestamps are not send in any packets sent to the server (they are always set to 0)
   
*/

#include "jive.h"
#include "audio/streambuf.h"

#if defined(WIN32)

#include <winsock2.h>

typedef SOCKET socket_t;
#define CLOSESOCKET(s) closesocket(s)
#define SOCKETERROR WSAGetLastError()

#else

typedef int socket_t;
#define CLOSESOCKET(s) close(s)
#define SOCKETERROR errno

#endif

extern LOG_CATEGORY *log_audio_decode;

struct stream {
	socket_t fd;
	// other stuff we don't use
};

#define min(x, y) ((x) < (y) ? (x) : (y))

#define INCACHE_SLOTS      8 // slots for caching state for concurrent active rtmp chunk channels - set to be higher than seen, which is 5
#define BUFFER_UNTIL_TS 4500 // on stream start only transition to playing state after this timestamp, avoids startup rebuffer

typedef enum { STREAM_OK, STREAM_END, STREAM_ERROR } stream_status; 

typedef enum {
	RTMP_IDLE = 0, RTMP_AWAIT_S0 = 1, RTMP_AWAIT_S1 = 2, RTMP_AWAIT_S2 = 3, 
	RTMP_SENT_CONNECT = 4, RTMP_SENT_CREATE_STREAM = 5, RTMP_SENT_FC_SUBSCRIBE = 6, RTMP_SENT_PLAY = 7,
	RTMP_BUFFERING = 8, RTMP_PLAYING = 9
} rtmp_state;

static const char *rtmp_state_name[] = {
	"idle", "awaitS0", "awaitS1", "awaitS2", "sentConnect", "sentCreateStream", "sentFCSubscribe", "sentPlay",
	"Buffering", "Playing"
};

static rtmp_state state = RTMP_IDLE;
static u8_t *hs_token = NULL;
static unsigned recv_chunksize;
static unsigned recv_bytes;
static unsigned next_ack;
static unsigned ack_wind;

struct {
	u8_t buf[4096*16];
	u8_t *pos;
	unsigned len;
} inbuf;

struct incache_entry {
	unsigned chan;
	u8_t type;
	u8_t *buf;
	unsigned len;
	unsigned rem;
	unsigned ts;
	unsigned dts;
};

static struct incache_entry incache[INCACHE_SLOTS];

void change_state(rtmp_state new) {
	int i;
	LOG_INFO(log_audio_decode, "rtmp state: %s -> %s", rtmp_state_name[state], rtmp_state_name[new]);
	state = new;
	// if moving to idle reinit state
	if (state == RTMP_IDLE) {
		inbuf.pos = inbuf.buf;
		inbuf.len = 0;
		recv_chunksize = 128;
		recv_bytes = 0;
		next_ack   = 20480;
		ack_wind   = 20480;
		for (i = 0; i < INCACHE_SLOTS; i++) {
			if (incache[i].buf) {
				free(incache[i].buf);
			}
		}
		memset(incache, 0, sizeof(struct incache_entry) * INCACHE_SLOTS);
	}
}

// busywaiting send used to send outbound packets
// it is assumed these are normally smaller than sndbuf so this does not stall
void _send(socket_t s, u8_t *buf, size_t len) {
	int n, stalled = 0;
	while (len > 0) {
		n = send(s, buf, len, 0);
		if (n >= 0) {
			len -= n;
			buf += n;
		} else if (SOCKETERROR == EAGAIN || SOCKETERROR == EWOULDBLOCK) {
			++stalled;
			if (stalled % 10 == 9) {
				LOG_ERROR(log_audio_decode, "stalled writing, count: %d", stalled);
			}
		} else {
			LOG_ERROR(log_audio_decode, "problem writing, error: %s", strerror(SOCKETERROR));
			break;
		}
	}
}

// send rtmp packets fragmenting if necessary
// assume all packets have a t0 header (no header compression)
void send_rtmp(socket_t s, u8_t *buf, size_t len) {
	u8_t header0 = *buf;
	
	if (len >= 12) {

		// first 12 bytes are the t0 header
		_send(s, buf, 12);
		buf += 12;
		len -= 12;

		while (len > 0) {
			// fragment into chunks of 128 bytes
			size_t chunklen = min(len, 128);
			_send(s, buf, chunklen);
			buf += chunklen;
			len -= chunklen;

			// add fragment header if more
			if (len > 0) {
				u8_t header = header0 | 0xc0;
				_send(s, &header, 1);
			}
		}

	} else {
		LOG_ERROR(log_audio_decode, "packet too short");
	}
}

int send_handshakeL(lua_State *L) {
	struct stream *stream;
	u8_t *ptr;
	int i;

	stream = lua_touserdata(L, 1);

	// reset rtmp state
	change_state(RTMP_IDLE);

	if (!hs_token) {
		hs_token = malloc(1528);
	}

	for (i = 0, ptr = hs_token; i < 1528; ++i) {
		*ptr++ = rand() % 256;
	}

	// c0
	_send(stream->fd, (u8_t*)"\x03", 1);
	// c1 header
	_send(stream->fd, (u8_t*)"\x00\x00\x00\x00\x00\x00\x00\x00", 8);
	// c1 token
	_send(stream->fd, hs_token, 1528);

	change_state(RTMP_AWAIT_S0);

	lua_pushboolean(L, TRUE);
	return 1;
}

bool rtmp_packet_exists(lua_State *L, const char *name) {
	bool exists;

	lua_getglobal(L,    "jive");
	lua_getfield(L, -1, "audio");
	lua_getfield(L, -1, "Rtmp");
	lua_getfield(L, -1, "rtmpMessages");
	lua_getfield(L, -1, name);

	exists = lua_isstring(L, -1);

	lua_pop(L, 5);

	return exists;
}

void send_rtmp_packet(lua_State *L, const char *name) {
	struct stream *stream = lua_touserdata(L, 1);;
	u8_t *packet;
	size_t len;

	// get preformatted packets from lua
	lua_getglobal(L,    "jive");
	lua_getfield(L, -1, "audio");
	lua_getfield(L, -1, "Rtmp");
	lua_getfield(L, -1, "rtmpMessages");
	lua_getfield(L, -1, name);

	if (lua_isstring(L, -1)) {
		LOG_INFO(log_audio_decode, "sending %s packet", name);
		packet = (u8_t *)lua_tolstring(L, -1, &len);
		send_rtmp(stream->fd, packet, len);
	} else {
		LOG_INFO(log_audio_decode, "can't find rtmp packet: %s", name);
	}

	lua_pop(L, 5);
}

// rtmp packet handlers - return false for error to force stream close

// receive chunk size handler
stream_status messageType1(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	recv_chunksize = *(buf) << 24 |*(buf+1) << 16 | *(buf+2) << 8 | *(buf+3);
	LOG_INFO(log_audio_decode, "message type 1 - set recv chunk size to: %d", recv_chunksize);
	return STREAM_OK;
}

// abort channel handler
stream_status messageType2(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	LOG_INFO(log_audio_decode, "message type 2 - abort for chunk channel: %d", entry->chan);
	if (entry->buf) {
		free(entry->buf);
	}
	memset(entry, 0, sizeof(struct incache_entry));
	return STREAM_OK;
}

// ack received handler
stream_status messageType3(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	LOG_INFO(log_audio_decode, "message type 3 - ack received");
	return STREAM_OK;
}

// user control message handler
stream_status messageType4(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	unsigned event = *(buf) << 8 | *(buf+1);
	u8_t *data = buf + 2;
	switch (event) {
	case 0: LOG_INFO(log_audio_decode, "message type 4 - user control message event 0: Stream Begin"); break;
	case 1: LOG_INFO(log_audio_decode, "message type 4 - user control message event 1: EOF - exiting"); 
		return STREAM_END;
		break;
	case 2: LOG_INFO(log_audio_decode, "message type 4 - user control message event 2: Stream Dry"); break;
	case 4: LOG_INFO(log_audio_decode, "message type 4 - user control message event 4: Stream Is Recorded"); break;
	case 6: 
		LOG_INFO(log_audio_decode, "message type 4 - user control message event 6: Ping Request - sending response");
		{
			struct stream *stream = lua_touserdata(L, 1);
			u8_t *packet_template, packet[18];
			
			packet_template = (u8_t *)
				"\x02"             // chan 2, format 0
				"\x00\x00\x00"     // timestamp (null)
				"\x00\x00\x06"     // length [data should be 4 bytes]
				"\x04"             // type 0x04
				"\x00\x00\x00\x00" // streamId 0
				"\x00\x07"         // event type 7
				"\x00\x00\x00\x00";// (overwrite with data - 4 bytes)
			
			memcpy(packet, packet_template, 18);
			memcpy(packet + 14, data, 4);
			
			send_rtmp(stream->fd, packet, 18);
		}
		break;

	default: LOG_DEBUG(log_audio_decode, "message type 4 - user control message event %d: ignored", event);
	}
	return STREAM_OK;
}

// window ack size handler
stream_status messageType5(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	unsigned window = *(buf) << 24 |*(buf+1) << 16 | *(buf+2) << 8 | *(buf+3);
	LOG_INFO(log_audio_decode, "message type 5 - window ack size: %d - ignored", window);
	return STREAM_OK;
}

// set window size handler
stream_status messageType6(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	struct stream *stream = lua_touserdata(L, 1);
	unsigned window = *(buf) << 24 |*(buf+1) << 16 | *(buf+2) << 8 | *(buf+3);
	unsigned limit  = *(buf+4);
	u8_t *packet_template, packet[16];

	// send window ack packet
	LOG_INFO(log_audio_decode, "message type 6 - set peer BW: %d limit type: %d", window, limit);

	packet_template = (u8_t *)
		"\x02"             // chan 2, format 0
		"\x00\x00\x00"     // timestamp (null)
		"\x00\x00\x04"     // length
		"\x05"             // type 0x05
		"\x00\x00\x00\x00" // streamId 0
		"\x00\x00\x00\x00";// (overwrite with window)

	memcpy(packet, packet_template, 16);
	// buf[0-3] is window - copy it
	memcpy(packet+12, buf, 4);
	send_rtmp(stream->fd, packet, 16);

	ack_wind = window / 2;
	return STREAM_OK;
}

// audio packet handler
stream_status messageType8(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	int n = streambuf_get_freebytes();
	
	if (*buf == 0xAF) {
		static u8_t adts[7]; // adts static header, set by aac config
		
		if (*(buf + 1) == 0x01) {
			// AAC audio
			u8_t header[7];
			unsigned framesize = entry->len - 2 + 7;
			memcpy(header, adts, 7);
			header[3] |= ((framesize >> 11) & 0x03);
			header[4] |= ((framesize >>  3) & 0xFF);
			header[5] |= ((framesize <<  5) & 0xE0);
			// LOG_DEBUG(log_audio_decode, "aac audio data: %d timestamp: %d", framesize, entry->ts);
			if (n > framesize) {
				streambuf_feed(header, 7);
				streambuf_feed(buf + 2, entry->len - 2);
			} else {
				LOG_ERROR(log_audio_decode, "panic - not enough space in streambuf - case not handled by implementation");
				return STREAM_ERROR;
			}
			
		} else if (*(buf + 1) == 0x00) {
			// AAC config
			unsigned profile  = 1; // hard coded, ignore config
			unsigned sr_index = ((*(buf+2) << 8 | *(buf+3)) & 0x0780) >> 7;
			unsigned channels = (*(buf+3) & 0x78) >> 3;
			LOG_INFO(log_audio_decode, "aac config: profile: %d sr_index: %d channels: %d", profile, sr_index, channels);
			adts[0] = 0xFF;
			adts[1] = 0xF9;
			adts[2] = ((profile << 6) & 0xC0) | ((sr_index << 2) & 0x3C) | ((channels >> 2) & 0x1);
			adts[3] = ((channels << 6) & 0xC0);
			adts[4] = 0x00;
			adts[5] = ((0x7FF >> 6) & 0x1F);
			adts[6] = ((0x7FF << 2) & 0xFC);
		}
		
	} else if ((*buf & 0xF0) == 0x20) {
		// MP3 audio
		// LOG_DEBUG(log_audio_decode, "mp3 audio data: %d timestamp: %d", entry->len - 1, entry->ts);
		if (n >= entry->len - 1) {
			streambuf_feed(buf + 1, entry->len - 1);
		} else {
			LOG_ERROR(log_audio_decode, "panic - not enough space in streambuf - case not handled by implementation");
			return STREAM_ERROR;
		}
	}
	
	if (state < RTMP_PLAYING) {

		bool send_start = false;

		if (state < RTMP_BUFFERING) {
			if (!rtmp_packet_exists(L, "live")) {
				send_start = true;
			} else {
				change_state(RTMP_BUFFERING);
			}
		}

		if (state == RTMP_BUFFERING && entry->ts > BUFFER_UNTIL_TS) {
			send_start = true;
		}

		if (send_start) {
			// send streamStartEvent to start playback
			lua_getglobal(L,    "jive");
			lua_getfield(L, -1, "audio");
			lua_getfield(L, -1, "Rtmp");
			lua_getfield(L, -1, "streamStartEvent");
			if (lua_pcall(L, 0, 0, 0) != 0) {
				LOG_ERROR(log_audio_decode, "error running streamStartEvent: %s\n", lua_tostring(L, -1));
			}
			change_state(RTMP_PLAYING);
		}
	}

	return STREAM_OK;
}

// metadata handler
stream_status messageType18(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	LOG_INFO(log_audio_decode, "message type 18 - meta");

	// send to server for debug
	lua_getglobal(L,    "jive");
	lua_getfield(L, -1, "audio");
	lua_getfield(L, -1, "Rtmp");
	lua_getfield(L, -1, "sendMeta");
	lua_pushlstring(L, (const char *)buf, entry->len);
	if (lua_pcall(L, 1, 0, 0) != 0) {
		LOG_ERROR(log_audio_decode, "error running sendMeta: %s\n", lua_tostring(L, -1));
	}
	return STREAM_OK;
}

// helper for messageType20 which returns true if string exists anywhere within buf
bool bufmatch(u8_t *buf, size_t len, const char *string) {
	unsigned i, string_len, match = 0;
	string_len = strlen(string);
	for (i = 0; i < len; i++) {
		if (*buf++ == string[match]) {
			match++;
		} else {
			match = 0;
		}
		if (match == string_len) {
			return true;
		}
	}
	return false;
}

// message type 20
stream_status messageType20(lua_State *L, u8_t *buf, struct incache_entry *entry) {
	LOG_INFO(log_audio_decode, "message type 20");

	// send packet to server for debug
	lua_getglobal(L,    "jive");
	lua_getfield(L, -1, "audio");
	lua_getfield(L, -1, "Rtmp");
	lua_getfield(L, -1, "sendMeta");
	lua_pushlstring(L, (const char *)buf, entry->len);
	if (lua_pcall(L, 1, 0, 0) != 0) {
		LOG_ERROR(log_audio_decode, "error running sendMeta: %s\n", lua_tostring(L, -1));
	}

	if (bufmatch(buf, entry->len, "_result")) {

		if (state == RTMP_SENT_CONNECT) {

			LOG_INFO(log_audio_decode, "sending createStream");
			send_rtmp_packet(L, "create");
			change_state(RTMP_SENT_CREATE_STREAM);

		} else if (state == RTMP_SENT_CREATE_STREAM) {

			if (rtmp_packet_exists(L, "subscribe")) {

				LOG_INFO(log_audio_decode, "sending FCSubscribe");
				send_rtmp_packet(L, "subscribe");
				change_state(RTMP_SENT_FC_SUBSCRIBE);

			} else {

				LOG_INFO(log_audio_decode, "sending play");
				send_rtmp_packet(L, "play");
				change_state(RTMP_SENT_PLAY);

			}
		}

	} else if (bufmatch(buf, entry->len, "_error")) {

		LOG_WARN(log_audio_decode, "stream error");
		return STREAM_ERROR;
		
	} else if (bufmatch(buf, entry->len, "onFCSubscribe")) {
		
		LOG_INFO(log_audio_decode, "sending play");
		send_rtmp_packet(L, "play");
		change_state(RTMP_SENT_PLAY);
		
	} else if (bufmatch(buf, entry->len, "onStatus")) {
		
		LOG_INFO(log_audio_decode, "onStatus");

		if (bufmatch(buf, entry->len, "NetStream.Play.Complete") ||
			bufmatch(buf, entry->len, "NetStream.Play.Stop")) {
			
			LOG_INFO(log_audio_decode, "stream ended - closing stream");
			
			return STREAM_END;
		}	
		
		if (bufmatch(buf, entry->len, "NetStream.Failed") ||
			bufmatch(buf, entry->len, "NetStream.Play.Failed") ||
			bufmatch(buf, entry->len, "NetStream.Play.StreamNotFound") ||
			bufmatch(buf, entry->len, "NetConnection.Connect.InvalidApp")) {
			
			LOG_WARN(log_audio_decode, "error status received - closing stream");
			
			return STREAM_ERROR;
		}	
	}

	return STREAM_OK;
}

int readL(lua_State *L) {
	struct stream *stream;
	bool readmore = true;
	/*
	 * 1: Stream (self)
	 * 2: Playback (self)
	 */

	stream = lua_touserdata(L, 1);

	// shuffle existing data in inbuf to start
	if (inbuf.len) {
		memcpy(inbuf.buf, inbuf.pos, inbuf.len);
		inbuf.pos = inbuf.buf;
	}

	while (readmore) {

		size_t len;
		readmore = false;

		// shuffle to the start if only using second half of buffer (i.e. don't do each loop)
		if (inbuf.len && inbuf.pos - inbuf.buf > sizeof(inbuf.buf) / 2) {
			memcpy(inbuf.buf, inbuf.pos, inbuf.len);
			inbuf.pos = inbuf.buf;
		}

		len = recv(stream->fd, inbuf.pos + inbuf.len, sizeof(inbuf.buf) - (inbuf.pos - inbuf.buf + inbuf.len), 0);
		
		if (len == -1) {
			if (SOCKETERROR == EAGAIN) {
				if (inbuf.len == 0) {
					lua_pushinteger(L, 0);
					return 1;
				}
			} else {
				LOG_ERROR(log_audio_decode, "socket closed, %s", strerror(SOCKETERROR));
				CLOSESOCKET(stream->fd);
				streambuf_set_streaming(FALSE);
				lua_pushnil(L);
				lua_pushstring(L, strerror(SOCKETERROR));
				return 2;
			}
		} else {
			inbuf.len  += len;
			recv_bytes += len;
		}

		// handshake phase
		if (state < RTMP_SENT_CONNECT) {
			
			if (state == RTMP_AWAIT_S0 && inbuf.len >= 1 && *inbuf.pos == 0x03) {
				inbuf.pos += 1;
				inbuf.len -= 1;
				change_state(RTMP_AWAIT_S1);
			}
			
			if (state == RTMP_AWAIT_S1 && inbuf.len >= 1536) {
				_send(stream->fd, inbuf.pos, 4);
				_send(stream->fd, (unsigned char *) "\x00\x00\x00\x00", 4);
				_send(stream->fd, inbuf.pos + 8, 1528);
				inbuf.pos += 1536;
				inbuf.len -= 1536;
				change_state(RTMP_AWAIT_S2);				
			}
			
			if (state == RTMP_AWAIT_S2 && inbuf.len >= 1536) {
				if (hs_token && !strncmp((char *)(inbuf.pos + 8), (char *) hs_token, 1528)) {
					free(hs_token);
					hs_token = NULL;
					inbuf.pos += 1536;
					inbuf.len -= 1536;
					send_rtmp_packet(L, "connect");
					change_state(RTMP_SENT_CONNECT);
				} else {
					LOG_ERROR(log_audio_decode, "bad handshake token");
					CLOSESOCKET(stream->fd);
					streambuf_set_streaming(FALSE);
					lua_pushnil(L);
					lua_pushstring(L, "bad handshake token");
					return 2;
				}
			}
		}
		
		// connected phase
		if (state >= RTMP_SENT_CONNECT && inbuf.len > 0) {
			
			unsigned chan = *inbuf.pos & 0x3f;
			unsigned fmt  = (*inbuf.pos & 0xc0) >> 6;
			u8_t *dpos = NULL;
			bool reasembled = false;
			struct incache_entry *entry;
			int i;
			char *error = NULL;

			// find or create a cache entry for this chan in the incache
			for (i = 0; i < INCACHE_SLOTS; i++) {
				entry = &incache[i];
				if (chan == entry->chan) {
					break;
				} else if (!entry->chan) {
					entry->chan = chan;
					break;
				}
			}

			if (i == INCACHE_SLOTS) {
				error = "run out of incache slots";
			} else if (chan == 0 || chan == 1) {
				error = "rtmp chan > 63 - not supported";
			}

			if (error) {
				LOG_ERROR(log_audio_decode, "%s", error);
				CLOSESOCKET(stream->fd);
				lua_pushnil(L);
				lua_pushstring(L, error);
				return 2;
			}

			if (fmt == 0 && inbuf.len >= 12) {

				int t0len = (*(inbuf.pos+4) << 16) | (*(inbuf.pos+5) << 8) | *(inbuf.pos+6);
				int read  = min(t0len, recv_chunksize) + 12;
				
				if (inbuf.len >= read) {
					entry->type = *(inbuf.pos + 7);
					entry->len  = t0len;
					entry->ts   = (*(inbuf.pos+1) << 16) | (*(inbuf.pos+2) << 8) | *(inbuf.pos+3);
					if (t0len == read - 12) {
						dpos = inbuf.pos + 12;
					} else {
						if (entry->buf) free(entry->buf);
						entry->buf  = malloc(t0len);
						memcpy(entry->buf, inbuf.pos + 12, read - 12);
						entry->rem  = t0len + 12 - read;
					}
					inbuf.pos += read;
					inbuf.len -= read;
					readmore = true;
				}
				
			} else if (fmt == 1 && inbuf.len >= 8) {

				int t1len = (*(inbuf.pos+4) << 16) | (*(inbuf.pos+5) << 8) | *(inbuf.pos+6);
				int read  = min(t1len, recv_chunksize) + 8;
				
				if (inbuf.len >= read) {
					entry->type = *(inbuf.pos + 7);
					entry->len  = t1len;
					entry->dts  = (*(inbuf.pos+1) << 16) | (*(inbuf.pos+2) << 8) | *(inbuf.pos+3);
					entry->ts   += entry->dts;
					if (t1len == read - 8) {
						dpos  = inbuf.pos + 8;
					} else {
						if (entry->buf) free(entry->buf);
						entry->buf  = malloc(t1len);
						memcpy(entry->buf, inbuf.pos + 8, read - 8);
						entry->rem  = t1len + 8 - read;
					}
					inbuf.pos += read;
					inbuf.len -= read;
					readmore = true;
				}
				
			} else if (fmt == 2 && entry->type) {
				
				int t2len = entry->len;
				int read  = min(t2len, recv_chunksize) + 4;
				
				if (inbuf.len >= read) {
					entry->dts  = (*(inbuf.pos+1) << 16) | (*(inbuf.pos+2) << 8) | *(inbuf.pos+3);
					entry->ts   += entry->dts;
					if (t2len == read - 4) {
						dpos  = inbuf.pos + 4;
					} else {
						if (entry->buf) free(entry->buf);
						entry->buf  = malloc(t2len);
						memcpy(entry->buf, inbuf.pos + 4, read - 4);
						entry->rem  = t2len + 4 - read;
					}
					inbuf.pos += read;
					inbuf.len -= read;
					readmore = true;
				}
				
			} else if (fmt == 3 && entry->rem) {
				
				int read  = min(entry->rem, recv_chunksize) + 1;
				
				if (inbuf.len >= read) {
					// add to existing fragment
					memcpy(entry->buf + entry->len - entry->rem, inbuf.pos + 1, read - 1);
					entry->rem -= (read - 1);
					if (!entry->rem) {
						reasembled = true;
					}
					inbuf.pos += read;
					inbuf.len -= read;

					readmore = true;
				}
				
			} else if (fmt == 3 && entry->type) {
				
				int t3len = entry->len;
				int read  = min(t3len, recv_chunksize) + 1;
				
				if (inbuf.len >= read) {
					entry->ts += entry->dts;
					if (t3len == read - 1) {
						dpos = inbuf.pos + 1;
					} else {
						if (entry->buf) free(entry->buf);
						entry->buf  = malloc(t3len);
						memcpy(entry->buf, inbuf.pos + 1, read - 1);
						entry->rem  = t3len + 1 - read;
					}
					inbuf.pos += read;
					inbuf.len -= read;

					readmore = true;
				}
			}
			
			if (dpos || reasembled) {
				u8_t *buf = dpos ? dpos : entry->buf;
				stream_status status;

				switch(entry->type) {
				case  1: status = messageType1(L, buf, entry); break;
				case  2: status = messageType2(L, buf, entry); break;
				case  3: status = messageType3(L, buf, entry); break;
				case  4: status = messageType4(L, buf, entry); break;
				case  5: status = messageType5(L, buf, entry); break;
				case  6: status = messageType6(L, buf, entry); break;
				case  8: status = messageType8(L, buf, entry); break;
				case 18: status = messageType18(L, buf, entry); break;
				case 20: status = messageType20(L, buf, entry); break;
				default:
					status = STREAM_OK;
					LOG_DEBUG(log_audio_decode, "unhandled rtmp packet type: %d", entry->type);
				}

				if (status != STREAM_OK) {

					CLOSESOCKET(stream->fd);
					streambuf_set_streaming(FALSE);

					if (status == STREAM_END) {
						LOG_INFO(log_audio_decode, "end of stream");
						lua_pushboolean(L, FALSE);
						return 1;
					} else if (status == STREAM_ERROR) {
						LOG_WARN(log_audio_decode, "stream error - closing stream");
						lua_pushnil(L);
						lua_pushstring(L, "stream error - closing stream");
						return 2;
					}
				}
			}
		}

		if (recv_bytes > next_ack) {
			u8_t *packet_template, packet[16];

			LOG_DEBUG(log_audio_decode, "sending ack: %u", recv_bytes);

			// send ack packet
			packet_template = (u8_t *)
				"\x02"             // chan 2, format 0
				"\x00\x00\x00"     // timestamp (null)
				"\x00\x00\x04"     // length
				"\x03"             // type 0x03
				"\x00\x00\x00\x00" // streamId 0
				"\x00\x00\x00\x00";// (overwrite with recv_bytes)

			memcpy(packet, packet_template, 16);
			*(packet+12) = (recv_bytes & 0xFF000000) >> 24;
			*(packet+13) = (recv_bytes & 0x00FF0000) >> 16;
			*(packet+14) = (recv_bytes & 0x0000FF00) >>  8;
			*(packet+15) = (recv_bytes & 0x000000FF);

			send_rtmp(stream->fd, packet, 16);
			next_ack += ack_wind;
		}
	}

	lua_pushinteger(L, 1);
	return 1;
}

static const struct luaL_Reg rtmp_f [] = {
	{ "sendHandshake", send_handshakeL },
	{ "read", readL },
 	{ NULL, NULL }
};

int luaopen_rtmp (lua_State *L) {
	luaL_register(L, "rtmp", rtmp_f);
	return 1;
}
