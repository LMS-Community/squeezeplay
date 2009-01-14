/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#ifndef AUDIO_DECODE_PRIV
#define AUDIO_DECODE_PRIV

#include "audio/fifo.h"


/* Audio sample, 32-bits.
 */
typedef s32_t sample_t;

#define SAMPLE_MAX (sample_t)0x7FFFFFFF
#define SAMPLE_MIN (sample_t)0x80000000


#define DECODER_MAX_PARAMS 32


/* Decode interface */
struct decode_module {
	u32_t id;
	char *name;
	void *(*start)(u8_t *params, u32_t num_params);
	void (*stop)(void *data);
	u32_t (*period)(void *data);
	bool_t (*callback)(void *data);
};


/* Built-in decoders */
extern struct decode_module decode_tones;
extern struct decode_module decode_pcm;
extern struct decode_module decode_flac;
extern struct decode_module decode_mad;
extern struct decode_module decode_vorbis;
#ifdef _WIN32
extern struct decode_module decode_wma_win;
#endif


/* Private decoder api */
extern u32_t current_decoder_state;
extern u32_t current_audio_state;

extern bool_t decode_output_can_write(u32_t buffer_size, u32_t sample_rate);

extern u32_t decode_output_percent_used(void);

extern void decode_output_samples(sample_t *buffer, u32_t samples, int sample_rate);

extern void decode_output_remove_padding(u32_t nsamples, u32_t sample_rate);

extern int decode_output_samplerate(void);

extern void decode_output_song_ended(void);

extern void decode_output_set_transition(u32_t type, u32_t period);

extern void decode_output_set_track_gain(u32_t replay_gain);

extern void decode_set_track_polarity_inversion(u8_t inversion);


/* Audio output api */
struct decode_audio {
	int (*init)(lua_State *L);
	void (*start)(void);
	void (*pause)(void);
	void (*resume)(void);
	void (*stop)(void);
	u32_t (*delay)(void);
	void (*gain)(s32_t lgain, s32_t rgain);
	void (*info)(unsigned int *rate_max);
};

extern struct decode_audio decode_alsa;
extern struct decode_audio decode_portaudio;
extern struct decode_audio *decode_audio;


/* Decode output api */
extern void decode_output_begin(void);
extern void decode_output_end(void);
extern void decode_output_flush(void);
extern bool_t decode_check_start_point(void);


/* Sample playback api (sound effects) */
extern int decode_sample_init(lua_State *L);
extern void decode_sample_mix(Uint8 *buffer, size_t buflen);


/* Internal state */

#define DECODE_FIFO_SIZE (10 * 2 * 44100 * sizeof(sample_t)) 
#define SAMPLES_TO_BYTES(n)  (2 * (n) * sizeof(sample_t))
#define BYTES_TO_SAMPLES(n)  ((n) / (2 * sizeof(sample_t)))

/* State variables for the current track */
extern u32_t decode_num_tracks_started;
extern u32_t decode_elapsed_samples;
extern bool_t decode_first_buffer;
extern u32_t current_sample_rate;
extern size_t skip_ahead_bytes;
extern int add_silence_ms;

/* The fifo used to store decoded samples */
extern u8_t decode_fifo_buf[DECODE_FIFO_SIZE];
extern struct fifo decode_fifo;

/* Decode message queue */
extern struct mqueue decode_mqueue;


#endif // AUDIO_DECODE_PRIV
