/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#if defined(WIN32)
#include <winsock2.h>
#endif

/* Track transition information */
static u32_t decode_transition_type = 0;
static u32_t decode_transition_period = 0;

static bool_t crossfade_started;
static size_t crossfade_ptr;
static fft_fixed transition_gain;
static fft_fixed transition_gain_step;
static u32_t transition_sample_step;
static u32_t transition_samples_in_step;


/* Per-track gain (ReplayGain) */
static fft_fixed track_gain = FIXED_ONE;
static sample_t track_clip_range[2] = { SAMPLE_MAX, SAMPLE_MIN };

/* Polarity inversion */
static s32_t track_inversion[2] = { 1, 1 };

/* Output channels */
static u8_t output_channels = 0;

/* Upload tests */
static int upload_fd = 0;


static void upload_close(void) {
	if (upload_fd) {
		close(upload_fd);
		upload_fd = 0;
	}
}


static bool_t upload_open(void) {
	struct sockaddr_in serv_addr;
	char *upload_addr;
	int err;

	upload_addr = getenv("SQUEEZEPLAY_UPLOAD");
	if (!upload_addr || streambuf_is_copyright()) {
		return FALSE;
	}

	upload_close();

	/* Server address and port */
	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_addr.s_addr = inet_addr(upload_addr);
	serv_addr.sin_port = htons(9001);
	serv_addr.sin_family = AF_INET;

	LOG_INFO(log_audio_decode, "uploading pcm to %s:%d", inet_ntoa(serv_addr.sin_addr), ntohs(serv_addr.sin_port));

	/* Create socket */
	upload_fd = socket(AF_INET, SOCK_STREAM, 0);
	if (upload_fd < 0) {
		LOG_WARN(log_audio_decode, "socket failed (%s)", strerror(errno));
	}

	/* Connect socket */
	err = connect(upload_fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr));
	if (err < 0) {
		LOG_WARN(log_audio_decode, "connect failed (%s)", strerror(errno));
		upload_close();
	}

	return TRUE;
}

static bool_t upload_samples(sample_t *buffer, u32_t nsamples) {
	ssize_t n, len;

	if (!upload_fd) {
		return FALSE;
	}

	len = SAMPLES_TO_BYTES(nsamples);
	while (len) {
		n = send(upload_fd, buffer, len, 0);
		if (n < 0) {
			LOG_WARN(log_audio_decode, "send failed (%s)", strerror(errno));
			upload_close();
			break;
		}

		len -= n;
	}

	return TRUE;
}


void decode_output_begin(void) {
	/* call with the decode fifo locked */

	ASSERT_AUDIO_LOCKED();

	if (decode_audio) {
		decode_audio->f->start();
	}
}


void decode_output_end(void) {
	/* call with the decode fifo locked */

	ASSERT_AUDIO_LOCKED();

	decode_audio->fifo.rptr = 0;
	decode_audio->fifo.wptr = 0;

	if (decode_audio) {
		decode_audio->f->stop();
	}

	crossfade_started = FALSE;
	transition_gain_step = 0;
	decode_audio->elapsed_samples = 0;
	decode_audio->sync_elapsed_timestamp = 0;
}


void decode_output_flush(void) {
	/* call with the decode fifo locked */

	ASSERT_AUDIO_LOCKED();

	if (decode_audio->check_start_point) {
		decode_audio->fifo.wptr = decode_audio->track_start_point;
	}
	else {
		decode_audio->fifo.rptr = decode_audio->fifo.wptr;

		/* abort audio playback */
		if (decode_audio) {
			decode_audio->f->stop();
		}
	}
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

/* How many bytes till we're done with the transition.
 */
static inline size_t decode_transition_bytes_remaining(size_t ptr) {
	ASSERT_AUDIO_LOCKED();

	return (ptr >= decode_audio->fifo.wptr) ? (ptr - decode_audio->fifo.wptr) : (decode_audio->fifo.wptr - ptr + decode_audio->fifo.size);
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

	ASSERT_AUDIO_LOCKED();

	while (nbytes) {
		bytes_read = SAMPLES_TO_BYTES(transition_sample_step - transition_samples_in_step);

		if (bytes_read > nbytes) {
			bytes_read = nbytes;
		}

		nsamples = BYTES_TO_SAMPLES(bytes_read);

		sptr = (sample_t *)(void *)(decode_fifo_buf + decode_audio->fifo.wptr);

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

		fifo_wptr_incby(&decode_audio->fifo, bytes_read);
		nbytes -= bytes_read;

		transition_samples_in_step += nsamples;
		while (transition_samples_in_step >= transition_sample_step) {
			transition_samples_in_step -= transition_sample_step;
			transition_gain += transition_gain_step;
		}
	}
}


void decode_output_samples(sample_t *buffer, u32_t nsamples, int sample_rate) {
	size_t bytes_out;

	/* Some decoders can pass no samples at the start of the track. Stop
	 * early, otherwise we may send the track start event at the wrong
	 * time.
	 */
	if (nsamples == 0) {
		return;
	}

	// XXXX full port from ip3k

	decode_audio_lock();

	if (decode_first_buffer) {
		LOG_DEBUG(log_audio_decode, "first buffer sample_rate=%d", sample_rate);

		upload_open();

		crossfade_started = FALSE;
		decode_audio->track_start_point = decode_audio->fifo.wptr;
		
		if (decode_transition_type & TRANSITION_CROSSFADE) {
			size_t crossfadeBytes;
			fft_fixed interval;

			if (decode_transition_type & TRANSITION_IMMEDIATE) {
				size_t wanted = SAMPLES_TO_BYTES(decode_transition_period * decode_audio->track_sample_rate);
				size_t used = fifo_bytes_used(&decode_audio->fifo);

				if (used > wanted) {
					size_t skip = used - wanted;
					if (skip > decode_audio->fifo.wptr) decode_audio->fifo.wptr += decode_audio->fifo.size;
					decode_audio->fifo.wptr -= skip;
				}
			}

			/* We are being asked to do a crossfade. Find out
			 * if it is possible.
			 */
			interval = determine_transition_interval(sample_rate, decode_transition_period, &crossfadeBytes);

			if (interval) {
				LOG_DEBUG(log_audio_decode, "Starting CROSSFADE over %d seconds, requiring %d bytes", fixed_to_s32(interval), (unsigned int)crossfadeBytes);

				/* Buffer position to stop crossfade */
				crossfade_ptr = decode_audio->fifo.wptr;

				/* Buffer position to start crossfade */
				if (crossfadeBytes > decode_audio->fifo.wptr) decode_audio->fifo.wptr += decode_audio->fifo.size;
				decode_audio->fifo.wptr -= crossfadeBytes;

				/* Gain steps */
				transition_gain_step = fixed_div(FIXED_ONE, fixed_mul(interval, s32_to_fixed(TRANSITION_STEPS_PER_SECOND)));
				transition_gain = 0;
				transition_sample_step = sample_rate / TRANSITION_STEPS_PER_SECOND;
				transition_samples_in_step = 0;

				crossfade_started = TRUE;
				decode_audio->track_start_point = decode_audio->fifo.wptr;
			}
			/* 
			 * else there aren't enough leftover samples from the
			 * previous track, so abort the transition.
			 */
		}
		else if (decode_transition_type & TRANSITION_FADE_IN) {
			/* The transition is a fade in. */

			LOG_DEBUG(log_audio_decode, "Starting FADE_IN over %d seconds", decode_transition_period);

			/* Gain steps */
			transition_gain_step = fixed_div(FIXED_ONE, s32_to_fixed(decode_transition_period * TRANSITION_STEPS_PER_SECOND));
			transition_gain = 0;
			transition_sample_step = sample_rate / TRANSITION_STEPS_PER_SECOND;
			transition_samples_in_step = 0;
		}

		decode_audio->track_copyright = streambuf_is_copyright();
		decode_audio->track_sample_rate = sample_rate;

		decode_audio->check_start_point = TRUE;
		decode_first_buffer = FALSE;
	}

	if (upload_samples(buffer, nsamples)) {
		decode_audio_unlock();
		return;
	}
	
	/* If output_channels is set, copy left samples to right, or vice versa */
	if (output_channels) {
		unsigned int i;
		if (output_channels & OUTPUT_CHANNEL_LEFT) {
			for (i = 0; i < nsamples * 2; i += 2) {
				buffer[i+1] = buffer[i];
			}
		}
		else {
			for (i = 0; i < nsamples * 2; i += 2) {
				buffer[i] = buffer[i+1];
			}
		}
	}

	decode_apply_track_gain(buffer, nsamples);

	bytes_out = SAMPLES_TO_BYTES(nsamples);

	while (bytes_out) {
		size_t wrap, bytes_write, bytes_remaining;

		/* The size of the output write is limied by the
		 * space untill our fifo wraps.
		 */
		wrap = fifo_bytes_until_wptr_wrap(&decode_audio->fifo);

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

			if ((crossfade_started && decode_audio->fifo.wptr == crossfade_ptr)
			    || transition_gain >= FIXED_ONE) {
				LOG_DEBUG(log_audio_decode, "Completed transition");

				transition_gain_step = 0;
				crossfade_started = FALSE;
			}
		}
		else {
			memcpy(decode_fifo_buf + decode_audio->fifo.wptr, buffer, bytes_write);
			fifo_wptr_incby(&decode_audio->fifo, bytes_write);
		}

		buffer += (bytes_write / sizeof(sample_t));
		bytes_out -= bytes_write;
	}

	decode_audio_unlock();
}


// XXXX is this really buffer_size, or number_samples?
bool_t decode_output_can_write(u32_t buffer_size, u32_t sample_rate) {
	size_t freebytes;

	LOG_ERROR(log_audio_decode, "function is deprecated");

	// XXXX full port from ip3k
	
	decode_audio_lock();

	freebytes = fifo_bytes_free(&decode_audio->fifo);

	decode_audio_unlock();

	if (freebytes >= buffer_size) {
		return TRUE;
	}

	return FALSE;
}


int decode_output_samplerate(void) {
	u32_t sample_rate;

	decode_audio_lock();
	sample_rate = decode_audio->track_sample_rate;
	decode_audio_unlock();

	return sample_rate;
}


int decode_output_max_rate(void) {
	u32_t max_rate;

	decode_audio_lock();
	max_rate = decode_audio->max_rate;
	decode_audio_unlock();

	return max_rate;
}


void decode_output_song_ended(void) {
	ASSERT_AUDIO_LOCKED();

	upload_close();

	if (decode_transition_type & TRANSITION_FADE_OUT 
	    && decode_transition_period
	    && decode_audio->state & DECODE_STATE_RUNNING) {
		// Signal audio module to begin fade-out
		decode_audio->samples_until_fade = decode_audio->track_sample_rate * (TRANSITION_MAXIMUM_SECONDS - decode_transition_period);
		decode_audio->samples_to_fade = decode_audio->track_sample_rate * decode_transition_period;
		decode_audio->transition_sample_rate = decode_audio->track_sample_rate;
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
	case 5:
		decode_transition_type = TRANSITION_CROSSFADE | TRANSITION_IMMEDIATE;
		break;
	}
}


void decode_output_set_track_gain(u32_t replay_gain) {
	track_gain = (replay_gain) ? replay_gain : FIXED_ONE;

	LOG_DEBUG(log_audio_decode, "Track gain %d", track_gain);

	volume_get_clip_range(track_gain, track_clip_range);

	LOG_DEBUG(log_audio_decode, "Track clip range %x %x", track_clip_range[0], track_clip_range[1]);
}


void decode_set_track_polarity_inversion(u8_t inversion) {
	LOG_DEBUG(log_audio_decode, "Polarity inversion %d", inversion);

	track_inversion[0] = (inversion & POLARITY_INVERSION_LEFT) ? -1 : 1;
	track_inversion[1] = (inversion & POLARITY_INVERSION_RIGHT) ? -1 : 1;
}

void decode_set_output_channels(u8_t channels) {
	LOG_DEBUG(log_audio_decode, "Output channels left %d, right %d",
		channels & OUTPUT_CHANNEL_LEFT ? 1 : 0, channels & OUTPUT_CHANNEL_RIGHT ? 1 : 0);

	output_channels = channels;
}
