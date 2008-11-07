/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


/* The start point of the last track */
static bool_t check_start_point = FALSE;
static size_t track_start_point = 0;

/* Has the audio output been initialized? */
static bool_t output_started = FALSE;

/* Track transition information */
static u32_t decode_transition_type = 0;
static u32_t decode_transition_period = 0;

static bool_t crossfade_started;
static size_t crossfade_ptr;
static fft_fixed transition_gain;
static fft_fixed transition_gain_step;
static u32_t transition_sample_step;
static u32_t transition_samples_in_step;


#define TRANSITION_NONE         0x0
#define TRANSITION_CROSSFADE    0x1
#define TRANSITION_FADE_IN      0x2
#define TRANSITION_FADE_OUT     0x4

/* Transition steps per second should be a common factor
 * of all supported sample rates.
 */
#define TRANSITION_STEPS_PER_SECOND 10
#define TRANSITION_MINIMUM_SECONDS 1


/* Per-track gain (ReplayGain) */
static fft_fixed track_gain = FIXED_ONE;
static sample_t track_clip_range[2] = { SAMPLE_MAX, SAMPLE_MIN };
static s32_t track_inversion[2] = { 1, 1 };


void decode_output_begin(void) {
	// XXXX fifo mutex

	decode_audio->start();

	if (output_started) {
		return;
	}

	output_started = TRUE;

	decode_fifo.rptr = 0;
	decode_fifo.wptr = 0;
}


void decode_output_end(void) {
	// XXXX fifo mutex

	output_started = FALSE;

	decode_audio->stop();

	crossfade_started = FALSE;
	transition_gain_step = 0;
	decode_elapsed_samples = 0;
}


void decode_output_flush(void) {
	// XXXX fifo mutex

	if (check_start_point) {
		decode_fifo.wptr = track_start_point;
	}
	else {
		decode_fifo.rptr = decode_fifo.wptr;

		/* abort audio playback */
		decode_audio->stop();
	}
}


bool_t decode_check_start_point(void) {
	bool_t reached_start_point;
	long track_start_offset;

	if (!check_start_point) {
		/* We are past the start point */
		return false;
	}
	
	/* We mark the start point of a track in the decode FIFO. This function
	 * tells us whether we've played past that point.
	 */
	if (decode_fifo.wptr > track_start_point) {
		reached_start_point = ((decode_fifo.rptr > track_start_point) &&
			(decode_fifo.rptr <= decode_fifo.wptr));
	}
	else {
		reached_start_point = ((decode_fifo.rptr > track_start_point) ||
			(decode_fifo.rptr <= decode_fifo.wptr));
	}

	if (!reached_start_point) {
		/* We have not reached the start point */
		return false;
	}
	
	track_start_offset = decode_fifo.rptr - track_start_point;
	if (track_start_offset < 0) {
		track_start_offset += DECODE_FIFO_SIZE;
	}

	/* Past the start point */
	check_start_point = FALSE;
	decode_num_tracks_started++;
	decode_elapsed_samples = BYTES_TO_SAMPLES(track_start_offset);

	return true;
}


/* Apply track gain and polarity inversion
 */
static void volume_get_clip_range(fft_fixed gain, sample_t clip_range[2]) {
	if (gain > FIXED_ONE) {
		clip_range[0] = (sample_t)(SAMPLE_MAX / fixed_to_double(gain));
		clip_range[1] = (sample_t)(SAMPLE_MIN / fixed_to_double(gain));
	}
	else {
		clip_range[0] = SAMPLE_MAX;
		clip_range[1] = SAMPLE_MIN;
	}
}


static inline sample_t volume_mul(sample_t sample, fft_fixed gain, sample_t clip_range[2]) {
	if (sample > clip_range[0]) {
		return SAMPLE_MAX;
	}
	if (sample < clip_range[1]) {
		return SAMPLE_MIN;
	}

	return fixed_mul(gain, sample);
}


static void decode_apply_track_gain(sample_t *buffer, int nsamples) {
	int s;

	if (track_gain == FIXED_ONE
	    && track_inversion[0] == 1
	    && track_inversion[1] == 1) {
		return;
	}

	for (s = 0; s < nsamples; s++) {
		*buffer = track_inversion[0] * volume_mul(*buffer, track_gain, track_clip_range);
		buffer++;
		*buffer = track_inversion[1] * volume_mul(*buffer, track_gain, track_clip_range);
		buffer++;
	}
}


/* Determine whether we have enough audio in the output buffer to do
 * a transition. Start at the requested transition interval and go
 * down till we find an interval that we have enough audio for.
 */
static fft_fixed determine_transition_interval(int sample_rate, u32_t transition_period, size_t *nbytes) {
	size_t bytes_used, sample_step_bytes;
	fft_fixed interval, interval_step;

	bytes_used = fifo_bytes_used(&decode_fifo);
	*nbytes = SAMPLES_TO_BYTES(TRANSITION_MINIMUM_SECONDS * sample_rate);
	if (bytes_used < *nbytes) {
		return 0;
	}

	*nbytes = SAMPLES_TO_BYTES(transition_period * sample_rate);
	transition_sample_step = sample_rate / TRANSITION_STEPS_PER_SECOND;
	sample_step_bytes = SAMPLES_TO_BYTES(transition_sample_step);

	interval = s32_to_fixed(transition_period);
	interval_step = fixed_div(FIXED_ONE, TRANSITION_STEPS_PER_SECOND);

	while (bytes_used < (*nbytes + sample_step_bytes)) {
		*nbytes -= sample_step_bytes;
		interval -= interval_step;
	}

	return interval;
}

/* How many bytes till we're done with the transition.
 */
static size_t decode_transition_bytes_remaining(size_t ptr) {
	return (ptr >= decode_fifo.wptr) ? (ptr - decode_fifo.wptr) : (decode_fifo.wptr - ptr + decode_fifo.size);
}


/* Called to fade out the already decoded track. Depending on how
 * much of the track is left, we apply gain in place.
 */
static void decode_fade_out(void) {
	size_t nbytes, ptr;
	fft_fixed interval;

	fifo_lock(&decode_fifo);

	interval = determine_transition_interval(current_sample_rate, decode_transition_period, &nbytes);

	DEBUG_TRACE("Starting FADEOUT over %d seconds, requiring %d bytes", fixed_to_s32(interval), (unsigned int)nbytes);

	if (!interval) {
		return;
	}

	ptr = decode_fifo.wptr;
	decode_fifo.wptr = (nbytes <= decode_fifo.wptr) ? (decode_fifo.wptr - nbytes) : (decode_fifo.wptr - nbytes + decode_fifo.size);

	transition_gain_step = fixed_div(FIXED_ONE, fixed_mul(interval, s32_to_fixed(TRANSITION_STEPS_PER_SECOND)));
	transition_gain = FIXED_ONE;
	transition_sample_step = current_sample_rate / TRANSITION_STEPS_PER_SECOND;
	transition_samples_in_step = 0;

	while (decode_fifo.wptr != ptr) {
		size_t s, bytes_read, samples_read, wrap, bytes_remaining;
		sample_t *sptr;

		bytes_read = SAMPLES_TO_BYTES(transition_sample_step - transition_samples_in_step);
		wrap = fifo_bytes_until_wptr_wrap(&decode_fifo);
		bytes_remaining = decode_transition_bytes_remaining(ptr);

		if (bytes_remaining < wrap) {
			wrap = bytes_remaining;
		}

		if (bytes_read > wrap) {
			bytes_read = wrap;
		}

		samples_read = BYTES_TO_SAMPLES(bytes_read);

		sptr = (sample_t *)(void *)(decode_fifo_buf + decode_fifo.wptr);
		for (s = 0; s < samples_read * 2; s++) {
			*sptr = fixed_mul(transition_gain, *sptr);
			sptr++;
		}

		fifo_wptr_incby(&decode_fifo, bytes_read);

		transition_samples_in_step += samples_read;
		while (transition_gain && transition_samples_in_step >= transition_sample_step) {
			transition_samples_in_step -= transition_sample_step;
			transition_gain -= transition_gain_step;
		}
	}

	fifo_unlock(&decode_fifo);
}


/* Called to copy samples to the decode fifo when we are doing
 * a transition - crossfade or fade in. This method applies gain
 * to both the new signal and the one that's already in the fifo.
 */
static void decode_transition_copy_bytes(sample_t *buffer, size_t nbytes) {
	sample_t sample, *sptr;
	int nsamples, s;
	size_t bytes_read;
	fft_fixed in_gain, out_gain;

	while (nbytes) {
		bytes_read = SAMPLES_TO_BYTES(transition_sample_step - transition_samples_in_step);

		if (bytes_read > nbytes) {
			bytes_read = nbytes;
		}

		nsamples = BYTES_TO_SAMPLES(bytes_read);

		sptr = (sample_t *)(void *)(decode_fifo_buf + decode_fifo.wptr);

		in_gain = transition_gain;
		out_gain = FIXED_ONE - in_gain;

		if (crossfade_started) {
			for (s=0; s<nsamples * 2; s++) {
				sample = fixed_mul(out_gain, *sptr);
				sample += fixed_mul(in_gain, *buffer++);
				*sptr++ = sample;
			}
		}
		else {
			for (s=0; s<nsamples * 2; s++) {
				*sptr++ = fixed_mul(in_gain, *buffer++);
			}
		}

		fifo_wptr_incby(&decode_fifo, bytes_read);
		nbytes -= bytes_read;

		transition_samples_in_step += nsamples;
		while (transition_samples_in_step >= transition_sample_step) {
			transition_samples_in_step -= transition_sample_step;
			transition_gain += transition_gain_step;
		}
	}
}


void decode_output_samples(sample_t *buffer, u32_t nsamples, int sample_rate,
			   bool_t copyright_asserted) {
	size_t bytes_out;

	/* Some decoders can pass no samples at the start of the track. Stop
	 * early, otherwise we may send the track start event at the wrong
	 * time.
	 */
	if (nsamples == 0) {
		return;
	}

	// XXXX full port from ip3k

	fifo_lock(&decode_fifo);

	if (decode_first_buffer) {
		crossfade_started = FALSE;
		track_start_point = decode_fifo.wptr;
		
		if (decode_transition_type & TRANSITION_CROSSFADE) {
			size_t crossfadeBytes;

			/* We are being asked to do a crossfade. Find out
			 * if it is possible.
			 */
			fft_fixed interval = determine_transition_interval(sample_rate, decode_transition_period, &crossfadeBytes);

			if (interval) {
				DEBUG_TRACE("Starting CROSSFADE over %d seconds, requiring %d bytes", fixed_to_s32(interval), (unsigned int)crossfadeBytes);

				/* Buffer position to stop crossfade */
				crossfade_ptr = decode_fifo.wptr;

				/* Buffer position to start crossfade */
				decode_fifo.wptr = (crossfadeBytes <= decode_fifo.wptr) ? (decode_fifo.wptr - crossfadeBytes) : (decode_fifo.wptr - crossfadeBytes + decode_fifo.size);

				/* Gain steps */
				transition_gain_step = fixed_div(FIXED_ONE, fixed_mul(interval, s32_to_fixed(TRANSITION_STEPS_PER_SECOND)));
				transition_gain = 0;
				transition_samples_in_step = 0;

				crossfade_started = TRUE;
				track_start_point = decode_fifo.wptr;
			}
			/* 
			 * else there aren't enough leftover samples from the
			 * previous track, so abort the transition.
			 */
		}
		else if (decode_transition_type & TRANSITION_FADE_IN) {
			/* The transition is a fade in. */

			DEBUG_TRACE("Starting FADE_IN over %d seconds", decode_transition_period);

			/* Gain steps */
			transition_gain_step = fixed_div(FIXED_ONE, s32_to_fixed(decode_transition_period * TRANSITION_STEPS_PER_SECOND));
			transition_gain = 0;
			transition_sample_step = sample_rate / TRANSITION_STEPS_PER_SECOND;
			transition_samples_in_step = 0;
		}

		current_sample_rate = sample_rate;

		check_start_point = TRUE;
		decode_first_buffer = FALSE;
	}

	decode_apply_track_gain(buffer, nsamples);

	bytes_out = SAMPLES_TO_BYTES(nsamples);

	while (bytes_out) {
		size_t wrap, bytes_write, bytes_remaining;

		/* The size of the output write is limied by the
		 * space untill our fifo wraps.
		 */
		wrap = fifo_bytes_until_wptr_wrap(&decode_fifo);

		/* When crossfading limit the output write to the
		 * end of the transition.
		 */
		if (crossfade_started) {
			bytes_remaining = decode_transition_bytes_remaining(crossfade_ptr);
			if (bytes_remaining < wrap) {
				wrap = bytes_remaining;
			}
		}

		bytes_write = bytes_out;
		if (bytes_write > wrap) {
			bytes_write = wrap;
		}

		if (transition_gain_step) {
			decode_transition_copy_bytes(buffer, bytes_write);

			if ((crossfade_started && decode_fifo.wptr == crossfade_ptr)
			    || transition_gain >= FIXED_ONE) {
				DEBUG_TRACE("Completed transition");

				transition_gain_step = 0;
				crossfade_started = FALSE;
			}
		}
		else {
			memcpy(decode_fifo_buf + decode_fifo.wptr, buffer, bytes_write);
			fifo_wptr_incby(&decode_fifo, bytes_write);
		}

		buffer += (bytes_write / sizeof(sample_t));
		bytes_out -= bytes_write;
	}

	fifo_unlock(&decode_fifo);
}


// XXXX is this really buffer_size, or number_samples?
bool_t decode_output_can_write(u32_t buffer_size, u32_t sample_rate) {
	size_t freebytes;

	// XXXX full port from ip3k
	
	fifo_lock(&decode_fifo);

	freebytes = fifo_bytes_free(&decode_fifo);

	fifo_unlock(&decode_fifo);

	if (freebytes >= buffer_size) {
		return TRUE;
	}

	return FALSE;
}

u32_t decode_output_percent_used(void) {
	size_t usedbytes;
	size_t freebytes;

	fifo_lock(&decode_fifo);

	usedbytes = fifo_bytes_free(&decode_fifo);
	freebytes = fifo_bytes_free(&decode_fifo);

	fifo_unlock(&decode_fifo);

	return (usedbytes * 100) / (usedbytes + freebytes);
}


/* This removes padding samples from the buffer (for gapless mp3 playback). */
void decode_output_remove_padding(u32_t nsamples, u32_t sample_rate) {
#if 0
	int numerator, denominator;
	u32_t resampled_rate;
#endif
	size_t buffer_size;

	buffer_size = SAMPLES_TO_BYTES(nsamples);

#if 0
	// XXXX full port from ip3k
	u32_t resampled_rate = decode_output_scaled_samplerate(sample_rate, &numerator, &denominator);
	if (numerator != 1) {
		buffer_size /= numerator;
	}
	buffer_size *= denominator;
#endif

	DEBUG_TRACE("Removing %d bytes padding from buffer", (unsigned int)buffer_size);

	fifo_lock(&decode_fifo);

	/* have we already started playing the padding? */
	if (fifo_bytes_used(&decode_fifo) <= buffer_size) {
		fifo_unlock(&decode_fifo);

		DEBUG_TRACE("- already playing padding");
		return;
	}

	if (decode_fifo.wptr < buffer_size) {
		decode_fifo.wptr += decode_fifo.size - buffer_size;
	}
	else {
		decode_fifo.wptr -= buffer_size;
	}

	fifo_unlock(&decode_fifo);
}


int decode_output_samplerate(void) {
	return current_sample_rate;
}


void decode_output_song_ended(void) {
	if (decode_transition_type & TRANSITION_FADE_OUT
	    && decode_transition_period
	    && current_audio_state & DECODE_STATE_RUNNING) {
		decode_fade_out();
	}
}


void decode_output_set_transition(u32_t type, u32_t period) {
	if (!period) {
		decode_transition_type = TRANSITION_NONE;
		return;
	}

	decode_transition_period = period;

	switch (type - '0') {
	case 0:
		decode_transition_type = TRANSITION_NONE;
		break;
	case 1:
		decode_transition_type = TRANSITION_CROSSFADE;
		break;
	case 2:
		decode_transition_type = TRANSITION_FADE_IN;
		break;
	case 3:
		decode_transition_type = TRANSITION_FADE_OUT;
		break;
	case 4:
		decode_transition_type = TRANSITION_FADE_IN | TRANSITION_FADE_OUT;

		/* Halve the period for fade in/fade out */
		decode_transition_period >>= 1;
		break;
	}
}


void decode_output_set_track_gain(u32_t replay_gain) {
	track_gain = (replay_gain) ? replay_gain : FIXED_ONE;

	DEBUG_TRACE("Track gain %d", track_gain);

	volume_get_clip_range(track_gain, track_clip_range);

	DEBUG_TRACE("Track clip range %x %x", track_clip_range[0], track_clip_range[1]);
}


void decode_set_track_polarity_inversion(u8_t inversion) {
	DEBUG_TRACE("Polarity inversion %d", inversion);

	track_inversion[0] = (inversion & POLARITY_INVERSION_LEFT) ? -1 : 1;
	track_inversion[1] = (inversion & POLARITY_INVERSION_RIGHT) ? -1 : 1;
}
