/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/mqueue.h"
#include "audio/fifo.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#define DECODE_MAX_INTERVAL 100

#define DECODE_MQUEUE_SIZE 512

#define DECODE_METADATA_SIZE 128

/* decoder thread */
static SDL_Thread *decode_thread;


/* current decoder state */
u32_t current_decoder_state = 0;
u32_t current_audio_state = 0;


/* state variables for the current track */
u32_t decode_num_tracks_started = 0;
u32_t decode_elapsed_samples = 0;
bool_t decode_first_buffer = FALSE;
u32_t current_sample_rate = 44100;
size_t skip_ahead_bytes = 0;
int add_silence_ms = 0;


/* decoder fifo used to store decoded samples */
u8_t decode_fifo_buf[DECODE_FIFO_SIZE];
struct fifo decode_fifo;


/* decoder mqueue */
struct mqueue decode_mqueue;
static Uint32 decode_mqueue_buffer[DECODE_MQUEUE_SIZE / sizeof(Uint32)];


/* meta data mqueue */
struct decode_metadata *decode_metadata;


/* audio instance */
struct decode_audio *decode_audio;


/* decoder instance */
static struct decode_module *decoder;
static void *decoder_data;


/* installed decoders */
static struct decode_module *all_decoders[] = {
	&decode_tones,
	&decode_pcm,
	&decode_flac,
	&decode_mad,
	&decode_vorbis,
#ifdef _WIN32
	&decode_wma_win,
#endif
};


static void decode_resume_handler(void) {
	int start_interval;

	start_interval = mqueue_read_u32(&decode_mqueue) - SDL_GetTicks();
	mqueue_read_complete(&decode_mqueue);
	
	if (start_interval < 0) {
		start_interval = 0;
	}
	
	DEBUG_TRACE("decode_resume_handler start_interval=%d", start_interval);

	fifo_lock(&decode_fifo);

	if (start_interval) {
		add_silence_ms = start_interval;
	}

	if (decoder) {
		current_decoder_state |= DECODE_STATE_RUNNING;
	}

	if (!fifo_empty(&decode_fifo)) {
		current_audio_state = DECODE_STATE_RUNNING;
		decode_audio->resume();
	}

	DEBUG_TRACE("resume decode state: %x audio state %x", current_decoder_state, current_audio_state);

	fifo_unlock(&decode_fifo);
}


static void decode_pause_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_pause_handler interval=%d", interval);

	if (interval) {
		add_silence_ms = interval;
	} else {
		current_decoder_state &= ~DECODE_STATE_RUNNING;
		current_audio_state &= ~DECODE_STATE_RUNNING;
		decode_audio->pause();
	}
	DEBUG_TRACE("pause decode state: %x audio state %x", current_decoder_state, current_audio_state);
}


static void decode_skip_ahead_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_skip_ahead_handler interval=%d", interval);
	
	skip_ahead_bytes = SAMPLES_TO_BYTES((u32_t)((interval * current_sample_rate) / 1000));
}


static void decode_stop_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_stop_handler");

	current_decoder_state = 0;
	current_audio_state = 0;

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_first_buffer = FALSE;
	decode_num_tracks_started = 0;
	decode_output_end();

	streambuf_flush();
}


static void decode_flush_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_flush_handler");

	current_decoder_state = 0;

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_first_buffer = FALSE;
	decode_output_flush();
}


static void decode_start_handler(void) {
	Uint32 decoder_id, transition_type, transition_period, replay_gain, output_threshold, polarity_inversion;
	Uint32 i, num_params;
	Uint8 params[DECODER_MAX_PARAMS];

	decoder_id = mqueue_read_u32(&decode_mqueue);
	transition_type = mqueue_read_u32(&decode_mqueue);
	transition_period = mqueue_read_u32(&decode_mqueue);
	replay_gain = mqueue_read_u32(&decode_mqueue);
	output_threshold = mqueue_read_u32(&decode_mqueue);
	polarity_inversion = mqueue_read_u32(&decode_mqueue);

	num_params = mqueue_read_u32(&decode_mqueue);
	if (num_params > DECODER_MAX_PARAMS) {
		num_params = DECODER_MAX_PARAMS;
	}
	for (i = 0; i < num_params; i++) {
		params[i] = mqueue_read_u8(&decode_mqueue);
	}
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_start_handler decoder=%x num_params=%d", decoder_id, num_params);

	for (i = 0; i < sizeof(all_decoders); i++) {
		if (all_decoders[i]->id == decoder_id) {
			decoder = all_decoders[i];
			decoder_data = decoder->start(params, num_params);
			break;
		}
	}

	decode_first_buffer = TRUE;
	// XXXX decode_set_output_threshold(output_threshold);
	decode_output_set_transition(transition_type, transition_period);
	decode_output_set_track_gain(replay_gain);
	decode_set_track_polarity_inversion(polarity_inversion);

	decode_output_begin();
}


static void decode_song_ended_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	DEBUG_TRACE("decode_song_ended_handler");

	decode_output_song_ended();
}


static Uint32 decode_timer_interval(void) {
	size_t used;

	if (decoder) {
		used = decode_output_percent_used();
		if (used > 80) {
			return DECODE_MAX_INTERVAL;
		} else if (used > 50) {
			return DECODE_MAX_INTERVAL / 2;
		}
		return decoder->period(decoder_data);
	}
	return DECODE_MAX_INTERVAL;
}


static int decode_thread_execute(void *unused) {
	DEBUG_TRACE("decode_thread_execute");

	while (true) {
		Uint32 timeout; // XXXX timer wrap around
		mqueue_func_t handler;

		timeout = SDL_GetTicks() + decode_timer_interval();
		//DEBUG_TRACE("timeout %d\n", timeout);

		while ((handler = mqueue_read_request(&decode_mqueue, timeout))) {
			DEBUG_TRACE("handling message");
			handler();
		}

		// XXXX new track started

		// XXXX check decoder state
		if (decoder && (current_decoder_state & DECODE_STATE_RUNNING)) {
			//DEBUG_TRACE("decode callback outbuf=%d", fifo_bytes_used(decode_fifo_rptr, decode_fifo_wptr, DECODE_FIFO_SIZE));
			decoder->callback(decoder_data);
		}

		// XXXX visualizer

		// XXXX buffer underrun
	}

	return 0;
}

/*
 * stream metadata interface
 */
void decode_queue_metadata(struct decode_metadata *metadata) {
	fifo_lock(&decode_fifo);

	if (decode_metadata) {
		DEBUG_TRACE("Dropped metadata");
		free(decode_metadata);
	}

	metadata->timestamp = SDL_GetTicks();
	metadata->fullness = fifo_bytes_used(&decode_fifo);

	decode_metadata = metadata;

	fifo_unlock(&decode_fifo);
}


static int decode_stream_metadata(lua_State *L) {
	/*
	 * 1: self
	 */

	fifo_lock(&decode_fifo);

	if (!decode_metadata) {
		fifo_unlock(&decode_fifo);
		return 0;
	}

	lua_newtable(L);

	lua_pushinteger(L, decode_metadata->type);
	lua_setfield(L, 2, "type");

	lua_pushinteger(L, decode_metadata->timestamp);
	lua_setfield(L, 2, "timestamp");

	lua_pushinteger(L, decode_metadata->fullness);
	lua_setfield(L, 2, "fullness");

	lua_pushlstring(L, (char *) &decode_metadata->data, decode_metadata->len);
	lua_setfield(L, 2, "metadata");

	free(decode_metadata);
	decode_metadata = NULL;

	fifo_unlock(&decode_fifo);

	return 1;
}



/*
 * lua decoder interface
 */

static int decode_resume(lua_State *L) {
	Uint32 start_jiffies;

	/* stack is:
	 * 1: self
	 * 2: start_jiffies
	 */

	start_jiffies = (Uint32) luaL_optinteger(L, 2, 0);
	DEBUG_TRACE("decode_resume start_jiffies=%d", start_jiffies);

	if (mqueue_write_request(&decode_mqueue, decode_resume_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, start_jiffies);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped resume message");
	}

	return 0;
}


static int decode_pause(lua_State *L) {
	Uint32 interval_ms;

	/* stack is:
	 * 1: self
	 * 2: start_jiffies
	 */

	interval_ms = (Uint32) luaL_optinteger(L, 2, 0);
	DEBUG_TRACE("decode_pause interval_ms=%d", interval_ms);

	if (mqueue_write_request(&decode_mqueue, decode_pause_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, interval_ms);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped pause message");
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
	DEBUG_TRACE("decode_skip_ahead interval_ms=%d", interval_ms);

	if (mqueue_write_request(&decode_mqueue, decode_skip_ahead_handler, sizeof(Uint32))) {
		mqueue_write_u32(&decode_mqueue, interval_ms);
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped skip_ahead message");
	}

	return 0;
}


static int decode_stop(lua_State *L) {
	/* stack is:
	 * 1: self
	 * 2: flush
	 */

	DEBUG_TRACE("decode_stop");

	if (mqueue_write_request(&decode_mqueue, decode_stop_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped start message");
	}

	return 0;
}


static int decode_flush(lua_State *L) {
	/* stack is:
	 * 1: self
	 */

	DEBUG_TRACE("decode_flush");

	if (mqueue_write_request(&decode_mqueue, decode_flush_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped flush message");
	}

	return 0;
}


static int decode_start(lua_State *L) {
	int num_params, i;

	DEBUG_TRACE("decode_start");

	/* stack is:
	 * 1: self
	 * 2: decoder
	 * 3: transition_type
	 * 4: transition_period
	 * 5: reply_gain
	 * 6: output_threshold
	 * 7: polarity_inversion
	 * 8: params...
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

		num_params = lua_gettop(L) - 7;
		mqueue_write_u32(&decode_mqueue, num_params);
		for (i = 0; i < num_params; i++) {
			mqueue_write_u8(&decode_mqueue, (Uint8) luaL_optinteger(L, 8 + i, 0));
		}
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped start message");
	}

	return 0;
}


static int decode_song_ended(lua_State *L) {
	/* stack is:
	 * 1: self
	 */

	DEBUG_TRACE("decode_sond_ended");

	if (mqueue_write_request(&decode_mqueue, decode_song_ended_handler, 0)) {
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		DEBUG_TRACE("Full message queue, dropped song ended message");
	}

	return 0;
}


static int decode_status(lua_State *L) {
	size_t size, usedbytes;
	u32_t bytesL, bytesH;
	u64_t elapsed, delay;

	lua_newtable(L);

	fifo_lock(&decode_fifo);

	lua_pushinteger(L, fifo_bytes_used(&decode_fifo));
	lua_setfield(L, -2, "outputFull");

	lua_pushinteger(L, decode_fifo.size);
	lua_setfield(L, -2, "outputSize");
	

	elapsed = decode_elapsed_samples;
	delay = decode_audio->delay ? decode_audio->delay() : 0;
	if (elapsed > delay) {
		elapsed -= delay;
	}
	elapsed = (elapsed * 1000) / current_sample_rate;

	lua_pushinteger(L, (u32_t)elapsed);
	lua_setfield(L, -2, "elapsed");
	
	/* get jiffies here so they correlate with "elapsed" as closely as possible */
	lua_pushinteger(L, (u32_t)SDL_GetTicks());
	lua_setfield(L, -2, "elapsed_jiffies");
	
	lua_pushinteger(L, decode_num_tracks_started);
	lua_setfield(L, -2, "tracksStarted");

	if (decoder) {
		lua_pushinteger(L, decoder->id);
		lua_setfield(L, -2, "decoder");
	}

	fifo_unlock(&decode_fifo);


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

	lua_pushinteger(L, current_audio_state);
	lua_setfield(L, -2, "audioState");

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

	decode_audio->gain(lgain, rgain);

	return 0;
}

static const struct luaL_Reg decode_f[] = {
	{ "resume", decode_resume },
	{ "pause", decode_pause },
	{ "skipAhead", decode_skip_ahead },
	{ "stop", decode_stop },
	{ "flush", decode_flush },
	{ "start", decode_start },
	{ "songEnded", decode_song_ended },
	{ "status", decode_status },
	{ "streamMetadata", decode_stream_metadata },
	{ "audioEnable", decode_audio_enable },
	{ "audioGain", decode_audio_gain },
	{ NULL, NULL }
};


int luaopen_decode(lua_State *L) {

	/* register sample playback */
	decode_sample_init(L);

	/* initialise audio output */
#ifdef HAVE_LIBASOUND
	decode_audio = &decode_alsa;
#endif
#ifdef HAVE_LIBPORTAUDIO
	if (!decode_audio) {
		decode_audio = &decode_portaudio;
	}
#endif
	if (!decode_audio) {
		/* no audio support */
		DEBUG_ERROR("No audio support");
		return 0;
	}

	if (!decode_audio->init()) {
		DEBUG_ERROR("Failed to init audio");
		return 0;
	}

	fifo_init(&decode_fifo, DECODE_FIFO_SIZE);

	mqueue_init(&decode_mqueue, decode_mqueue_buffer, sizeof(decode_mqueue_buffer));

	/* start decoder thread */
	decode_thread = SDL_CreateThread(decode_thread_execute, NULL);

	/* register lua functions */
	luaL_register(L, "squeezeplay.decode", decode_f);

	/* register sample playback */
	decode_sample_init(L);

	return 0;
}

