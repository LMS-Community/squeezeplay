/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/mqueue.h"
#include "audio/fifo.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef WITH_SPPRIVATE
extern int luaopen_spprivate(lua_State *L);
#endif

#define DECODE_MAX_INTERVAL 500
#define DECODE_WAIT_INTERVAL 100

#define DECODE_MQUEUE_SIZE 512

#define DECODE_METADATA_SIZE 128

/* loggers */
LOG_CATEGORY *log_audio_decode;
LOG_CATEGORY *log_audio_codec;
LOG_CATEGORY *log_audio_output;


/* decoder thread */
static SDL_Thread *decode_thread = NULL;


/* current decoder state */
u32_t current_decoder_state = 0;
int decode_watchdog = -1;


/* state variables for the current track */
bool_t decode_first_buffer = FALSE;


/* decoder fifo used to store decoded samples */
u8_t *decode_fifo_buf;


/* decoder mqueue */
struct mqueue decode_mqueue;
static Uint32 decode_mqueue_buffer[DECODE_MQUEUE_SIZE / sizeof(Uint32)];


/* meta data mqueue */
struct mqueue metadata_mqueue;
static Uint32 metadata_mqueue_buffer[DECODE_MQUEUE_SIZE / sizeof(Uint32)];

static size_t wma_guid_len;
static u8_t *wma_guid;


/* audio instance */
struct decode_audio *decode_audio;


/* decoder instance */
static struct decode_module *decoder;
static void *decoder_data;



/* installed decoders */
static struct decode_module *all_decoders[] = {
	/* in order of perference */
#ifdef _WIN32
	&decode_wma_win,
#else
	&decode_alac,
#endif
#ifdef WITH_SPPRIVATE
	&decode_wma,
	&decode_aac,
#endif
	&decode_vorbis,
	&decode_flac,
	&decode_pcm,
	&decode_mad,
};


static inline void debug_fullness(void)
{
	if (IS_LOG_PRIORITY(log_audio_decode, LOG_PRIORITY_DEBUG)) {
		size_t size, usedbytes;
		u32_t bytesL, bytesH;
		float dfull, ofull;

		decode_audio_lock();

		streambuf_get_status(&size, &usedbytes, &bytesL, &bytesH);
		dfull = (float)(usedbytes * 100) / (float)size;
		ofull = (float)(fifo_bytes_used(&decode_audio->fifo) * 100) / (float)decode_audio->fifo.size;
		
		LOG_DEBUG(log_audio_decode, "fullness: %d / %d | %0.2f%% / %0.2f%%",
			usedbytes, fifo_bytes_used(&decode_audio->fifo), 
			dfull, ofull);
		decode_audio_unlock();
	}
}


static void decode_resume_decoder_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	current_decoder_state = DECODE_STATE_RUNNING;
	LOG_DEBUG(log_audio_decode, "resume_decoder decode state: %x audio state %x", current_decoder_state, decode_audio->state);
	debug_fullness();
}


static void decode_resume_audio_handler(void) {
	int start_interval = 0;
	Uint32 start_jiffies;

	start_jiffies = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);
	
	if (start_jiffies) {
		start_interval = start_jiffies - jive_jiffies();
	}
	
	LOG_DEBUG(log_audio_decode, "decode_resume_audio_handler start_interval=%d", start_interval);
	debug_fullness();

	decode_audio_lock();

	if (start_interval) {
		decode_audio->add_silence_ms = start_interval;
	}

	if (((decode_audio->state & (DECODE_STATE_RUNNING | DECODE_STATE_AUTOSTART)) == 0)) {
		decode_audio->state = DECODE_STATE_AUTOSTART;
		decode_audio->f->resume();
	}

	decode_audio_unlock();

	LOG_DEBUG(log_audio_decode, "resume_audio decode state: %x audio state %x", current_decoder_state, decode_audio->state);
}


static void decode_pause_audio_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_pause_handler interval=%d", interval);

	decode_audio_lock();

	if (interval) {
		decode_audio->add_silence_ms = interval;
	} else {
		if ((decode_audio->state & DECODE_STATE_RUNNING) != 0) {
			decode_audio->state &= ~DECODE_STATE_RUNNING;
			decode_audio->f->pause();
		}
	}

	decode_audio_unlock();

	LOG_DEBUG(log_audio_decode, "pause_audio decode state: %x audio state %x", current_decoder_state, decode_audio->state);
}


static void decode_skip_ahead_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_skip_ahead_handler interval=%d", interval);

	decode_audio_lock();

	decode_audio->skip_ahead_bytes = SAMPLES_TO_BYTES((u32_t)((interval * decode_audio->track_sample_rate) / 1000));

	decode_audio_unlock();
}


static void decode_stop_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_stop_handler");

	decode_audio_lock();

	current_decoder_state = 0;
	decode_audio->state = 0;

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_audio->num_tracks_started = 0;
	decode_first_buffer = FALSE;
	decode_output_end();

	decode_audio_unlock();
}


static void decode_flush_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_flush_handler");

	decode_audio_lock();

	current_decoder_state = 0;

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_first_buffer = FALSE;
	decode_output_flush();

	decode_audio_unlock();
}


static void decode_start_handler(void) {
	Uint32 decoder_id, transition_type, transition_period, replay_gain;
	Uint32 output_threshold, polarity_inversion, output_channels;
	Uint32 i, num_params;
	Uint8 params[DECODER_MAX_PARAMS];

	decoder_id = mqueue_read_u32(&decode_mqueue);
	transition_type = mqueue_read_u32(&decode_mqueue);
	transition_period = mqueue_read_u32(&decode_mqueue);
	replay_gain = mqueue_read_u32(&decode_mqueue);
	output_threshold = mqueue_read_u32(&decode_mqueue);
	polarity_inversion = mqueue_read_u32(&decode_mqueue);
	output_channels = mqueue_read_u32(&decode_mqueue);

	num_params = mqueue_read_u32(&decode_mqueue);
	if (num_params > DECODER_MAX_PARAMS) {
		num_params = DECODER_MAX_PARAMS;
	}
	for (i = 0; i < num_params; i++) {
		params[i] = mqueue_read_u8(&decode_mqueue);
	}
	mqueue_read_complete(&decode_mqueue);

	for (i=0; i<(sizeof(all_decoders)/sizeof(struct decode_module *)); i++) {
		if (all_decoders[i]->id == decoder_id) {
			decoder = all_decoders[i];
			break;
		}
	}

	if (!decoder) {
		LOG_ERROR(log_audio_decode, "unknown decoder %x\n", decoder_id);
		return;
	}

	LOG_INFO(log_audio_decode, "init decoder %s", decoder->name);

	decode_first_buffer = TRUE;
	decode_output_set_transition(transition_type, transition_period);
	decode_output_set_track_gain(replay_gain);
	decode_set_track_polarity_inversion(polarity_inversion);
	decode_set_output_channels(output_channels);

	decoder_data = decoder->start(params, num_params);

	decode_audio_lock();
	decode_audio->output_threshold = output_threshold;
	decode_output_begin();
	decode_audio_unlock();
}


static void decode_capture_handler(void) {
	Uint32 loopback;

	loopback = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_capture_handler");

	decode_audio_lock();

	if (loopback) {
		decode_audio->state |= DECODE_STATE_LOOPBACK;
	}
	else {
		decode_audio->state &= ~DECODE_STATE_LOOPBACK;
	}

	decode_audio_unlock();

}


static void decode_song_ended_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_song_ended_handler");

	decode_audio_lock();

	decode_output_song_ended();

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_audio_unlock();
}


/* returns true if decode can run */
static bool_t decode_timer_interval(u32_t *delay) {
	size_t free_bytes, used_bytes, max_samples;
	u32_t state, sample_rate;

	if (!decoder || (current_decoder_state & (DECODE_STATE_RUNNING|DECODE_STATE_ERROR)) != DECODE_STATE_RUNNING) {
		*delay = DECODE_MAX_INTERVAL;

		return false;
	}

	/* Small delay if the stream empty but still streaming? */
	/* special case for flac as it has a minimum number of bytes before the decoder processes anything */
	if (streambuf_would_wait_for(decoder == &decode_flac ? DECODE_MINIMUM_BYTES_FLAC : DECODE_MINIMUM_BYTES_OTHER)) {
		*delay = DECODE_WAIT_INTERVAL;
		
		return false;
	}

	/* Variable delay based on output buffer fullness */
	max_samples = decoder->samples(decoder_data);

	decode_audio_lock();
	state = decode_audio->state;
	sample_rate = decode_audio->track_sample_rate;
	free_bytes = fifo_bytes_free(&decode_audio->fifo);
	used_bytes = fifo_bytes_used(&decode_audio->fifo);
	decode_audio_unlock();

	if (SAMPLES_TO_BYTES(max_samples) < free_bytes) {
		*delay = 0;

		return true;
	}
	else {
		*delay = ((max_samples * 1000) / sample_rate) + 1; /* ms */

		/* don't decode for every buffer, do it every other one */
		*delay *= 2;

		return false;
	}
}


void decode_keepalive(int ticks) {
	watchdog_keepalive(decode_watchdog, 1);
}


static int decode_thread_execute(void *unused) {
	int decode_debug;

	LOG_DEBUG(log_audio_decode, "decode_thread_execute");

	decode_watchdog = watchdog_get();

	decode_debug = getenv("SQUEEZEPLAY_DECODE_DEBUG") != NULL;

	while (true) {
		mqueue_func_t handler;
		u32_t delay;
		bool_t can_decode;

		/* XXXX 30 seconds for testing */
		watchdog_keepalive(decode_watchdog, 3);

		can_decode = decode_timer_interval(&delay);
		while ((handler = mqueue_read_request(&decode_mqueue, delay))) {
			// for debugging race conditions
			//sleep(2);

			handler();

			can_decode = decode_timer_interval(&delay);
		}

		if (can_decode && decoder
		    && (current_decoder_state & DECODE_STATE_RUNNING)) {
			decoder->callback(decoder_data);

			/* Additional debugging enabled with an environment
			 * variable, used to track decoder performance.
			 */
			if (decode_debug) {
				size_t decode_size, decode_full;
				size_t output_full, output_size;
				double dbuf, obuf;
				u64_t elapsed;
				u32_t bytesl, bytesh;

				decode_audio_lock();
				output_full = fifo_bytes_used(&decode_audio->fifo);
				output_size = decode_audio->fifo.size;

				if (decode_audio->track_sample_rate) {
					elapsed = decode_audio->elapsed_samples;
					elapsed = (elapsed * 1000) / decode_audio->track_sample_rate;
				}
				else {
					elapsed = 0;
				}
				decode_audio_unlock();

				streambuf_get_status(&decode_size, &decode_full, &bytesl, &bytesh);

				dbuf = (decode_full * 100) / (double)decode_size;
				obuf = (output_full * 100) / (double)output_size;


				printf("elapsed:%llu buffers: %0.1f%%/%0.1f%%\n", (long long unsigned int)elapsed, dbuf, obuf);
			}
		}

		decode_sample_fill_buffer();
	}

	return 0;
}


/*
 * stream metadata interface
 */
int decode_set_wma_guid(lua_State *L)
{
	size_t guid_len;
	const u8_t *guid;

	/*
	 * 1: self
	 * 2: guid_len
	 * 3: guid
	 */

	guid_len = lua_tointeger(L, 2);
	guid = (const u8_t *) lua_tostring(L, 3);

	if (wma_guid) {
		free(wma_guid);
	}

	wma_guid_len = guid_len;
	wma_guid = malloc(guid_len);
	if (!wma_guid) {
		return 0;
	}

	memcpy(wma_guid, guid, guid_len);

	return 0;
}


void decode_queue_metadata(enum metadata_type type, u8_t *metadata, size_t metadata_len) {
	char *buf;

	if (type == WMA_GUID) {
		size_t i;
		bool_t match = false;

		if (wma_guid_len == 0) {
			return;
		}

		if (wma_guid_len == 0xFFFF) {
			/* for debugging */
			match = true;
		}

		for (i=0; i<wma_guid_len; i+=16) {
			if (memcmp(wma_guid+i, metadata, 16) == 0) {
				match = true;
			}
		}

		if (!match) {
			return;
		}
	}

	buf = alloca(metadata_len + 4);
	strncpy(buf, "META", 4);
	memcpy(buf + 4, metadata, metadata_len);

	decode_queue_packet(buf, metadata_len + 4);
}


void decode_queue_packet(void *data, size_t len) {
	if (mqueue_write_request(&metadata_mqueue, (void *)1, sizeof(Uint32) + len)) {
		mqueue_write_u32(&metadata_mqueue, len);
		mqueue_write_array(&metadata_mqueue, data, len);
		mqueue_write_complete(&metadata_mqueue);
	}
	else {
		LOG_ERROR(log_audio_decode, "dropped queued packet");
	}
}


static int decode_dequeue_packet(lua_State *L) {
	void *data;
	size_t len;

	/*
	 * 1: self
	 */

	if (!mqueue_read_request(&metadata_mqueue, 0)) {
		return 0;
	}

	len = mqueue_read_u32(&metadata_mqueue);
	data = alloca(len);
	mqueue_read_array(&metadata_mqueue, data, len);
	mqueue_read_complete(&metadata_mqueue);

	lua_newtable(L);

	lua_pushlstring(L, (const char *)data, 4);
	lua_setfield(L, 2, "opcode");

	lua_pushlstring(L, (const char *)data + 4, len - 4);
	lua_setfield(L, 2, "data");

	return 1;
}



/*
 * lua decoder interface
 */
static int decode_resume_decoder(lua_State *L) {

	/* stack is:
	 * 1: self
	 */

	LOG_DEBUG(log_audio_decode, "decode_resume_decoder");

	if (mqueue_write_request(&decode_mqueue, decode_resume_decoder_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped resume message");
	}

	return 0;
}

static int decode_resume_audio(lua_State *L) {
	Uint32 start_jiffies;

	/* stack is:
	 * 1: self
	 * 2: start_jiffies
	 */

	start_jiffies = (Uint32) luaL_optinteger(L, 2, 0);
	LOG_DEBUG(log_audio_decode, "decode_resume_audio start_jiffies=%d", start_jiffies);

	if (mqueue_write_request(&decode_mqueue, decode_resume_audio_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, start_jiffies);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped resume message");
	}

	return 0;
}


static int decode_pause_audio(lua_State *L) {
	Uint32 interval_ms;

	/* stack is:
	 * 1: self
	 * 2: start_jiffies
	 */

	interval_ms = (Uint32) luaL_optinteger(L, 2, 0);
	LOG_DEBUG(log_audio_decode, "decode_pause_audio interval_ms=%d", interval_ms);

	if (mqueue_write_request(&decode_mqueue, decode_pause_audio_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, interval_ms);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped pause message");
	}

	return 0;
}


static int decode_skip_ahead(lua_State *L) {
	Uint32 interval_ms;

	/* stack is:
	 * 1: self
	 * 2: start_jiffies
	 */

	interval_ms = (Uint32) luaL_optinteger(L, 2, 0);
	LOG_DEBUG(log_audio_decode, "decode_skip_ahead interval_ms=%d", interval_ms);

	if (mqueue_write_request(&decode_mqueue, decode_skip_ahead_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, interval_ms);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped skip_ahead message");
	}

	return 0;
}


static int decode_stop(lua_State *L) {
	/* stack is:
	 * 1: self
	 * 2: flush
	 */

	LOG_DEBUG(log_audio_decode, "decode_stop");

	if (mqueue_write_request(&decode_mqueue, decode_stop_handler, 0)) {
		decode_audio_lock();
		decode_audio->state |= DECODE_STATE_STOPPING;
		decode_audio_unlock();

		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped stop message");
	}

	return 0;
}


static int decode_flush(lua_State *L) {
	/* stack is:
	 * 1: self
	 */

	LOG_DEBUG(log_audio_decode, "decode_flush");

	if (mqueue_write_request(&decode_mqueue, decode_flush_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped flush message");
	}

	return 0;
}


static int decode_start(lua_State *L) {
	int num_params, i;

	LOG_DEBUG(log_audio_decode, "decode_start");

	/* stack is:
	 * 1: self
	 * 2: decoder
	 * 3: transition_type
	 * 4: transition_period
	 * 5: reply_gain
	 * 6: output_threshold
	 * 7: polarity_inversion
	 * 8: output_channels
	 * 9: params...
	 */

	/* Reset the decoder state in calling thread to avoid potential
	 * race condition - we may incorrectly report a decoder underrun
	 * if we wait till the decoder thread resets it.
	 */
	current_decoder_state = 0;

	if (mqueue_write_request(&decode_mqueue, decode_start_handler, 0)) {
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 2, 0)); /* decoder */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 3, 0)); /* transition_type */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 4, 0)); /* transition_period */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 5, 0)); /* replay_gain */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 6, 0)); /* output_threshold */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 7, 0)); /* polarity_inversion */
		mqueue_write_u32(&decode_mqueue, (Uint32) luaL_optinteger(L, 8, 0)); /* output_channels */
		
		num_params = lua_gettop(L) - 8;
		mqueue_write_u32(&decode_mqueue, num_params);
		for (i = 0; i < num_params; i++) {
			mqueue_write_u8(&decode_mqueue, (Uint8) luaL_optinteger(L, 9 + i, 0));
		}
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped start message");
	}

	return 0;
}


static int decode_capture(lua_State *L) {
	Uint32 loopback;

	/* stack is:
	 * 1: self
	 * 2: loopback
	 */

	loopback = (Uint32) lua_toboolean(L, 2);
	LOG_DEBUG(log_audio_decode, "decode_capture loopback=%d", loopback);

	if (mqueue_write_request(&decode_mqueue, decode_capture_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, loopback);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped start message");
	}

	return 0;
}


static int decode_song_ended(lua_State *L) {
	/* stack is:
	 * 1: self
	 */

	LOG_DEBUG(log_audio_decode, "decode_sond_ended");

	if (mqueue_write_request(&decode_mqueue, decode_song_ended_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped song ended message");
	}

	return 0;
}


static int decode_status(lua_State *L) {
	size_t size, usedbytes;
	u32_t bytesL, bytesH, elapsed_jiffies;
	u64_t elapsed, output;

	if (!decode_audio) {
		return 0;
	}

	lua_newtable(L);

	decode_audio_lock();

	lua_pushinteger(L, fifo_bytes_used(&decode_audio->fifo));
	lua_setfield(L, -2, "outputFull");

	lua_pushinteger(L, decode_audio->fifo.size);
	lua_setfield(L, -2, "outputSize");

	if (decode_audio->track_sample_rate) {
		output = fifo_bytes_used(&decode_audio->fifo);
		output = (BYTES_TO_SAMPLES(output) * 1000) / decode_audio->track_sample_rate;
	}
	else {
		output = 0;
	}
	lua_pushinteger(L, (u32_t)output);
	lua_setfield(L, -2, "outputTime");

	elapsed_jiffies = jive_jiffies();

	if (decode_audio->track_sample_rate) {
		if (decode_audio->sync_elapsed_timestamp) {
			/* elapsed is sync adjusted */
			elapsed = decode_audio->sync_elapsed_samples;

		}
		else {
			/* no sync adjustment */
			elapsed = decode_audio->elapsed_samples;
		}

		elapsed = (elapsed * 1000) / decode_audio->track_sample_rate;

		if ((decode_audio->state & DECODE_STATE_RUNNING) &&
			decode_audio->sync_elapsed_timestamp &&
			elapsed_jiffies > decode_audio->sync_elapsed_timestamp)
		{
			elapsed += (elapsed_jiffies - decode_audio->sync_elapsed_timestamp);
		}
	}
	else {
		elapsed = 0;
	}
	lua_pushinteger(L, (u32_t)elapsed);
	lua_setfield(L, -2, "elapsed");
	
	lua_pushinteger(L, elapsed_jiffies);
	lua_setfield(L, -2, "elapsed_jiffies");
	
	lua_pushinteger(L, decode_audio->num_tracks_started);
	lua_setfield(L, -2, "tracksStarted");

	if (decoder) {
		lua_pushinteger(L, decoder->id);
		lua_setfield(L, -2, "decoder");
	}

	lua_pushinteger(L, decode_audio->state);
	lua_setfield(L, -2, "audioState");

	decode_audio_unlock();


	streambuf_get_status(&size, &usedbytes, &bytesL, &bytesH);

	lua_pushinteger(L, size);
	lua_setfield(L, -2, "decodeSize");

	lua_pushinteger(L, usedbytes);
	lua_setfield(L, -2, "decodeFull");

	lua_pushinteger(L, bytesL);
	lua_setfield(L, -2, "bytesReceivedL");

	lua_pushinteger(L, bytesH);
	lua_setfield(L, -2, "bytesReceivedH");

	lua_pushinteger(L, current_decoder_state);
	lua_setfield(L, -2, "decodeState");

	return 1;
}

static int decode_audio_enable(lua_State *L) {
	int enable;

	enable = lua_toboolean(L, 2);

	// FIXME

	return 0;
}

static int decode_audio_gain(lua_State *L) {
	s32_t lgain, rgain;

	lgain = lua_tointeger(L, 2);
	rgain = lua_tointeger(L, 3);

	if (decode_audio) {
		decode_audio_lock();
		decode_audio->lgain = lgain;
		decode_audio->rgain = rgain;
		decode_audio_unlock();
	}

	return 0;
}

static int decode_capture_gain(lua_State *L) {
	s32_t lgain, rgain;

	lgain = lua_tointeger(L, 2);
	rgain = lua_tointeger(L, 3);

	if (decode_audio) {
		decode_audio_lock();
		decode_audio->capture_lgain = lgain;
		decode_audio->capture_rgain = rgain;
		decode_audio_unlock();
	}

	return 0;
}

static int decode_init_audio(lua_State *L) {
	size_t i;

	/* stack is:
	 * 1: decode
	 * 2: slimproto
	 */

	/* register codecs */
	for (i=0; i<(sizeof(all_decoders)/sizeof(struct decode_module *)); i++) {
		char *tmp, *ptr;

		if (!all_decoders[i]->name) {
			continue;
		}

		tmp = strdup(all_decoders[i]->name);

		ptr = strtok(tmp, ",");
		while (ptr) {
			lua_getfield(L, 2, "capability");
			lua_pushvalue(L, 2);
			lua_pushstring(L, ptr);
			lua_call(L, 2, 0);

			ptr = strtok(NULL, ",");
		}

		free(tmp);
	}

	/* max sample rate */
	if (decode_audio) {
		u32_t max_rate;

		decode_audio_lock();
		max_rate = decode_audio->max_rate;
		decode_audio_unlock();

		lua_getfield(L, 2, "capability");
		lua_pushvalue(L, 2);
		lua_pushstring(L, "MaxSampleRate");
		lua_pushinteger(L, max_rate);
		lua_call(L, 3, 0);
	}

	/* tell SC that our play-points are accurate, unless configuration says otherwise */
	{
		unsigned int accuratePlayPoints;

		lua_getfield(L, 2, "accuratePlayPoints");
		accuratePlayPoints = luaL_optinteger(L, -1, 1);
		lua_pop(L, 1);

		if (accuratePlayPoints) {
			lua_getfield(L, 2, "capability");
			lua_pushvalue(L, 2);
			lua_pushstring(L, "AccuratePlayPoints");
			lua_call(L, 2, 0);
		}
	}

	return 0;
}


static int decode_audio_open(lua_State *L) {
	struct decode_audio_func *f = NULL;

	if (decode_audio || decode_thread) {
		/* already initialized */
		lua_pushboolean(L, 1);
		return 1;
	}

	/* initialise audio output */
#ifdef HAVE_LIBASOUND
	f = &decode_alsa;
#endif
#ifdef HAVE_LIBPORTAUDIO
	if (!f) {
		f = &decode_portaudio;
	}
#endif
#ifdef HAVE_NULLAUDIO
	f = &decode_null;
#endif
	if (!f) {
		/* no audio support */
		lua_pushnil(L);
		lua_pushstring(L, "No audio support");
		return 2;
	}

	/* audio initialization */
	if (!f->init(L)) {
		/* audio init failed */
		lua_pushnil(L);
		lua_pushstring(L, "Error in audio init");
		return 2;
	}

	assert(decode_audio);
	assert(decode_fifo_buf);

	decode_audio->f = f;

	/* start decoder thread */
	mqueue_init(&decode_mqueue, decode_mqueue_buffer, sizeof(decode_mqueue_buffer));
	mqueue_init(&metadata_mqueue, metadata_mqueue_buffer, sizeof(metadata_mqueue_buffer));

	decode_thread = SDL_CreateThread(decode_thread_execute, NULL);

	lua_pushboolean(L, 1);
	return 1;
}


static const struct luaL_Reg decode_f[] = {
	{ "open", decode_audio_open },
	{ "initAudio", decode_init_audio },
	{ "resumeDecoder", decode_resume_decoder },
	{ "resumeAudio", decode_resume_audio },
	{ "pauseAudio", decode_pause_audio },
	{ "skipAhead", decode_skip_ahead },
	{ "stop", decode_stop },
	{ "flush", decode_flush },
	{ "start", decode_start },
	{ "capture", decode_capture },
	{ "songEnded", decode_song_ended },
	{ "status", decode_status },
	{ "dequeuePacket", decode_dequeue_packet },
	{ "setGuid", decode_set_wma_guid },
	{ "audioEnable", decode_audio_enable },
	{ "audioGain", decode_audio_gain },
	{ "captureGain", decode_capture_gain },
	{ "vumeter", decode_vumeter },
	{ "spectrum_init", decode_spectrum_init },
	{ "spectrum", decode_spectrum },
	{ NULL, NULL }
};


int luaopen_decode(lua_State *L) {

	/* define loggers */
	log_audio_decode = LOG_CATEGORY_GET("audio.decode");
	log_audio_codec = LOG_CATEGORY_GET("audio.codec");
	log_audio_output = LOG_CATEGORY_GET("audio.output");

	/* register lua functions */
	luaL_register(L, "squeezeplay.decode", decode_f);

	/* register sample playback */
	decode_sample_init(L);

#ifdef WITH_SPPRIVATE
	luaopen_spprivate(L);
#endif

	return 0;
}

