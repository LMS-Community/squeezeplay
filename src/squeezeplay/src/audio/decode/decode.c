/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
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

#define DECODE_MAX_INTERVAL 100

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
static void *packet_data = NULL;
static size_t packet_len = 0;


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


static void decode_resume_decoder_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	current_decoder_state = DECODE_STATE_RUNNING;
	LOG_DEBUG(log_audio_decode, "resume_decoder decode state: %x audio state %x", current_decoder_state, current_audio_state);
}


static void decode_resume_audio_handler(void) {
	int start_interval;

	start_interval = mqueue_read_u32(&decode_mqueue) - SDL_GetTicks();
	mqueue_read_complete(&decode_mqueue);
	
	if (start_interval < 0) {
		start_interval = 0;
	}
	
	LOG_DEBUG(log_audio_decode, "decode_resume_audio_handler start_interval=%d", start_interval);

	fifo_lock(&decode_fifo);

	if (start_interval) {
		add_silence_ms = start_interval;
	}

	if (!fifo_empty(&decode_fifo)) {
		current_audio_state = DECODE_STATE_RUNNING;
		if (decode_audio) {
			decode_audio->resume();
		}
	}

	fifo_unlock(&decode_fifo);

	LOG_DEBUG(log_audio_decode, "resume_audio decode state: %x audio state %x", current_decoder_state, current_audio_state);
}


static void decode_pause_audio_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_pause_handler interval=%d", interval);

	fifo_lock(&decode_fifo);

	if (interval) {
		add_silence_ms = interval;
	} else {
		current_audio_state &= ~DECODE_STATE_RUNNING;
		if (decode_audio) {
			decode_audio->pause();
		}
	}

	fifo_unlock(&decode_fifo);

	LOG_DEBUG(log_audio_decode, "pause_audio decode state: %x audio state %x", current_decoder_state, current_audio_state);
}


static void decode_skip_ahead_handler(void) {
	Uint32 interval;

	interval = mqueue_read_u32(&decode_mqueue);
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_skip_ahead_handler interval=%d", interval);
	
	skip_ahead_bytes = SAMPLES_TO_BYTES((u32_t)((interval * current_sample_rate) / 1000));
}


static void decode_stop_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_stop_handler");

	fifo_lock(&decode_fifo);

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

	fifo_unlock(&decode_fifo);
}


static void decode_flush_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_flush_handler");

	fifo_lock(&decode_fifo);

	current_decoder_state = 0;

	if (decoder) {
		decoder->stop(decoder_data);

		decoder = NULL;
		decoder_data = NULL;
	}

	decode_first_buffer = FALSE;
	decode_output_flush();

	fifo_unlock(&decode_fifo);
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

	fifo_lock(&decode_fifo);

	decoder_data = decoder->start(params, num_params);

	decode_first_buffer = TRUE;
	// XXXX decode_set_output_threshold(output_threshold);
	decode_output_set_transition(transition_type, transition_period);
	decode_output_set_track_gain(replay_gain);
	decode_set_track_polarity_inversion(polarity_inversion);

	decode_output_begin();

	fifo_unlock(&decode_fifo);
}


static void decode_song_ended_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	LOG_DEBUG(log_audio_decode, "decode_song_ended_handler");

	fifo_lock(&decode_fifo);

	decode_output_song_ended();

	fifo_unlock(&decode_fifo);
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
	int decode_watchdog;

	LOG_DEBUG(log_audio_decode, "decode_thread_execute");

	decode_watchdog = watchdog_get();

	while (true) {
		Uint32 timeout; // XXXX timer wrap around
		mqueue_func_t handler;

		watchdog_keepalive(decode_watchdog, 1);

		timeout = SDL_GetTicks() + decode_timer_interval();
		//LOG_DEBUG(log_audio_decode, "timeout %d\n", timeout);

		while ((handler = mqueue_read_request(&decode_mqueue, timeout))) {
			LOG_DEBUG(log_audio_decode, "handling message");
			handler();
		}

		// XXXX new track started

		// XXXX check decoder state
		if (decoder && (current_decoder_state & DECODE_STATE_RUNNING)) {
			//LOG_DEBUG(log_audio_decode, "decode callback outbuf=%d", fifo_bytes_used(decode_fifo_rptr, decode_fifo_wptr, DECODE_FIFO_SIZE));
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
void decode_queue_metadata(enum metadata_type type, u8_t *metadata, size_t metadata_len) {
	char *buf;

	buf = malloc(metadata_len + 4);
	strncpy(buf, "META", 4);
	memcpy(buf + 4, metadata, metadata_len);

	decode_queue_packet(buf, metadata_len + 4);
	/* decode_queue_packet will free buf */
}


void decode_queue_packet(void *data, size_t len) {
	fifo_lock(&decode_fifo);

	if (packet_data) {
		/* if this happens often we need to implement a queue */
		LOG_ERROR(log_audio_decode, "dropped queued packet");
		free(packet_data);
	}

	packet_data = data;
	packet_len = len;

	fifo_unlock(&decode_fifo);
}


static int decode_dequeue_packet(lua_State *L) {
	/*
	 * 1: self
	 */

	fifo_lock(&decode_fifo);

	if (!packet_data) {
		fifo_unlock(&decode_fifo);
		return 0;
	}

	lua_newtable(L);

	lua_pushlstring(L, (const char *)packet_data, 4);
	lua_setfield(L, 2, "opcode");

	lua_pushlstring(L, (const char *)packet_data + 4, packet_len - 4);
	lua_setfield(L, 2, "data");

	free(packet_data);
	packet_data = NULL;

	fifo_unlock(&decode_fifo);

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
		mqueue_write_complete(&decode_mqueue);
	}
	else {
		LOG_DEBUG(log_audio_decode, "Full message queue, dropped start message");
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
	u32_t bytesL, bytesH;
	u64_t elapsed, delay, output;

	lua_newtable(L);

	fifo_lock(&decode_fifo);

	lua_pushinteger(L, fifo_bytes_used(&decode_fifo));
	lua_setfield(L, -2, "outputFull");

	lua_pushinteger(L, decode_fifo.size);
	lua_setfield(L, -2, "outputSize");

	if (current_sample_rate) {
		output = fifo_bytes_used(&decode_fifo);
		output = (BYTES_TO_SAMPLES(output) * 1000) / current_sample_rate;
	}
	else {
		output = 0;
	}
	lua_pushinteger(L, (u32_t)output);
	lua_setfield(L, -2, "outputTime");

	if (current_sample_rate) {
		elapsed = decode_elapsed_samples;
		delay = (decode_audio && decode_audio->delay) ? decode_audio->delay() : 0;
		if (elapsed > delay) {
			elapsed -= delay;
		}
		elapsed = (elapsed * 1000) / current_sample_rate;
	}
	else {
		elapsed = 0;
	}
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

	if (decode_audio) {
		decode_audio->gain(lgain, rgain);
	}

	return 0;
}

#define VUMETER_DEFAULT_SAMPLE_WINDOW 4 * 1024

static int decode_vumeter(lua_State *L) {
	u32_t sample_accumulator[2];
	sample_t *ptr;
	size_t samples_until_wrap;
	s16_t sample;
	s32_t sample_sq;
	size_t i, num_samples;

	num_samples = luaL_optinteger(L, 2, VUMETER_DEFAULT_SAMPLE_WINDOW);

	sample_accumulator[0] = 0;
	sample_accumulator[1] = 0;

	fifo_lock(&decode_fifo);

	if (current_audio_state & DECODE_STATE_RUNNING) {
		ptr = (sample_t *)(void *)(decode_fifo_buf + decode_fifo.rptr);
		samples_until_wrap = BYTES_TO_SAMPLES(fifo_bytes_until_rptr_wrap(&decode_fifo));

		for (i=0; i<num_samples; i++) {
			sample = (*ptr++) >> 24;
			sample_sq = sample * sample;
			sample_accumulator[0] += sample_sq;

			sample = (*ptr++) >> 24;
			sample_sq = sample * sample;
			sample_accumulator[1] += sample_sq;

			samples_until_wrap -= 2;
			if (samples_until_wrap <= 0) {
				ptr = (sample_t *)(void *)decode_fifo_buf;
			}
		}
	}

	fifo_unlock(&decode_fifo);

	sample_accumulator[0] /= num_samples;
	sample_accumulator[1] /= num_samples;

	lua_newtable(L);
	lua_pushinteger(L, sample_accumulator[0]);
	lua_rawseti(L, -2, 1);
	lua_pushinteger(L, sample_accumulator[1]);
	lua_rawseti(L, -2, 2);

	return 1;
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
		unsigned int rate_max;

		decode_audio->info(&rate_max);

		lua_getfield(L, 2, "capability");
		lua_pushvalue(L, 2);
		lua_pushstring(L, "MaxSampleRate");
		lua_pushinteger(L, rate_max);
		lua_call(L, 3, 0);
	}

	return 0;
}


static int decode_audio_open(lua_State *L) {

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
		lua_pushnil(L);
		lua_pushstring(L, "No audio support");
		return 2;
	}

	if (!decode_audio->init(L)) {
		/* audio init failed */
		decode_audio = NULL;

		lua_pushnil(L);
		lua_pushstring(L, "Error in audio init");
		return 2;
	}

	/* start decoder thread */
	if (!decode_thread) {
		decode_thread = SDL_CreateThread(decode_thread_execute, NULL);
	}

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
	{ "songEnded", decode_song_ended },
	{ "status", decode_status },
	{ "dequeuePacket", decode_dequeue_packet },
	{ "audioEnable", decode_audio_enable },
	{ "audioGain", decode_audio_gain },
	{ "vumeter", decode_vumeter },
	{ NULL, NULL }
};


int luaopen_decode(lua_State *L) {

	/* define loggers */
	log_audio_decode = LOG_CATEGORY_GET("audio.decode");
	log_audio_codec = LOG_CATEGORY_GET("audio.codec");
	log_audio_output = LOG_CATEGORY_GET("audio.output");

	/* register sample playback */
	decode_sample_init(L);

	fifo_init(&decode_fifo, DECODE_FIFO_SIZE);

	mqueue_init(&decode_mqueue, decode_mqueue_buffer, sizeof(decode_mqueue_buffer));

	/* register lua functions */
	luaL_register(L, "squeezeplay.decode", decode_f);

	/* register sample playback */
	decode_sample_init(L);

#ifdef WITH_SPPRIVATE
	luaopen_spprivate(L);
#endif

	return 0;
}

