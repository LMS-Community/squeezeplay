/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#ifndef AUDIO_DECODE_PRIV
#define AUDIO_DECODE_PRIV

#include "audio/fifo.h"
#include "audio/fixed_math.h"


extern LOG_CATEGORY *log_audio_decode;
extern LOG_CATEGORY *log_audio_codec;
extern LOG_CATEGORY *log_audio_output;


/* Audio sample, 32-bits. */
typedef s32_t sample_t;

#define SAMPLE_MAX (sample_t)0x7FFFFFFF
#define SAMPLE_MIN (sample_t)0x80000000

static inline sample_t sample_clip(sample_t a, sample_t b) {
	s64_t s = a + b;

	if (s < SAMPLE_MIN) {
		return SAMPLE_MIN;
	} else if (s > SAMPLE_MAX) {
		return SAMPLE_MAX;
	}
	else {
		return s;
	}
}


/* Effect sample, 16-bits. */
typedef s16_t effect_t;


#define DECODER_MAX_PARAMS 32


/* Decode interface */
struct decode_module {
	u32_t id;
	char *name;
	/* start the decode, params is from SC */
	void *(*start)(u8_t *params, u32_t num_params);
	/* stop and free the decode */
	void (*stop)(void *data);
	/* max samples to be written to output buffer */
	size_t (*samples)(void *data);
	/* callback to decode samples to output buffer */
	bool_t (*callback)(void *data);
};


/* todo: fix win32 alac compile */
/* Built-in decoders */ 
extern struct decode_module decode_tones;
extern struct decode_module decode_pcm;
extern struct decode_module decode_flac;
extern struct decode_module decode_mad;
extern struct decode_module decode_vorbis;
#ifdef _WIN32
extern struct decode_module decode_wma_win;
#else
extern struct decode_module decode_alac;
#endif
#ifdef WITH_SPPRIVATE
extern struct decode_module decode_wma;
extern struct decode_module decode_aac;
#endif


/* Private decoder api */
extern u32_t current_decoder_state;

extern void decode_keepalive(int ticks);

extern u32_t decode_output_percent_used(void);

extern void decode_output_samples(sample_t *buffer, u32_t samples, int sample_rate);

extern int decode_output_samplerate(void);

extern void decode_output_song_ended(void);

extern void decode_output_set_transition(u32_t type, u32_t period);

extern void decode_output_set_track_gain(u32_t replay_gain);

extern void decode_set_track_polarity_inversion(u8_t inversion);


/* Audio output backends */
struct decode_audio_func {
	int (*init)(lua_State *L);
	void (*start)(void);
	void (*pause)(void);
	void (*resume)(void);
	void (*stop)(void);
};

struct decode_audio {
	struct decode_audio_func *f;

	/* fifo locks: playback state, track state, sync state */
	struct fifo fifo;

	/* playback state */
	bool_t running;
	u32_t state;
	s32_t lgain, rgain;
	s32_t capture_lgain, capture_rgain;
	u32_t set_sample_rate;

	u32_t sync_elapsed_samples;
	u32_t sync_elapsed_timestamp;

	/* track state */
	bool_t check_start_point;
	size_t track_start_point;
	bool_t track_copyright;
	u32_t track_sample_rate;
	u32_t elapsed_samples;
	u32_t num_tracks_started;
	
	/* sync state */
	size_t skip_ahead_bytes;
	int add_silence_ms;

	/* effect_fifo locks: effect_gain */
	struct fifo effect_fifo;
	fft_fixed effect_gain;

	/* device info */
	u32_t max_rate;
};

extern struct decode_audio *decode_audio;

#define decode_audio_lock() fifo_lock(&(decode_audio->fifo))
#define decode_audio_unlock() fifo_unlock(&(decode_audio->fifo))

#define ASSERT_AUDIO_LOCKED() ASSERT_FIFO_LOCKED(&(decode_audio->fifo))

/* Audio output backends */
extern struct decode_audio_func decode_alsa;
extern struct decode_audio_func decode_portaudio;


/* Decode output api */
extern void decode_init_buffers(void *buf, bool_t prio_inherit);
extern void decode_output_begin(void);
extern void decode_output_end(void);
extern void decode_output_flush(void);
extern bool_t decode_check_start_point(void);
extern void decode_mix_effects(void *outputBuffer, size_t framesPerBuffer, int sample_width, int output_sample_rate);


/* Sample playback api (sound effects) */
extern int decode_sample_init(lua_State *L);
extern void decode_sample_fill_buffer(void);


/* Internal state */

#define SAMPLES_TO_BYTES(n)  (2 * (n) * sizeof(sample_t))
#define BYTES_TO_SAMPLES(n)  ((n) / (2 * sizeof(sample_t)))

/* State variables for the current track */
extern bool_t decode_first_buffer;


/* The fifo used to store decoded samples */
#define DECODE_FIFO_SIZE (10 * 2 * 44100 * sizeof(sample_t)) 
extern u8_t *decode_fifo_buf;

#define EFFECT_FIFO_SIZE (1 * 1 * 44100 * sizeof(effect_t))
extern u8_t *effect_fifo_buf;

#define DECODE_AUDIO_BUFFER_SIZE (sizeof(struct decode_audio) + DECODE_FIFO_SIZE + EFFECT_FIFO_SIZE)

/* Decode message queue */
extern struct mqueue decode_mqueue;


#endif // AUDIO_DECODE_PRIV
