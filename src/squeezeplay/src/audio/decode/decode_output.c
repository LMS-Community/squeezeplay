/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

//#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/fifo.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


/* The start point of the last track */
static bool_t check_start_point = FALSE;
static size_t track_start_point = 0;

/* Has the audio output been initialized? */
static bool_t output_started = FALSE;


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
	output_started = FALSE;

	decode_audio->stop();
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

	/* Past the start point */
	check_start_point = FALSE;
	decode_num_tracks_started++;
	decode_elapsed_samples = 0;

	return true;
}


void decode_output_samples(sample_t *buffer, u32_t nsamples, int sample_rate,
			   bool_t need_scaling, bool_t start_immediately,
			   bool_t copyright_asserted) {
	size_t bytes_out;

	DEBUG_TRACE("Got %d samples\n", samples);

	/* Some decoders can pass no samples at the start of the track. Stop
	 * early, otherwise we may send the track start event at the wrong
	 * time.
	 */
	if (nsamples == 0) {
		return;
	}

	// XXXX full port from ip3k

	if (decode_first_buffer) {
		current_sample_rate = sample_rate;
		track_start_point = decode_fifo.wptr;
		check_start_point = TRUE;
		decode_first_buffer = FALSE;
	}

	bytes_out = SAMPLES_TO_BYTES(nsamples);

	while (bytes_out) {
		size_t wrap, bytes_write;

		wrap = fifo_bytes_until_wptr_wrap(&decode_fifo);

		bytes_write = bytes_out;
		if (bytes_write > wrap) {
			bytes_write = wrap;
		}

		memcpy(decode_fifo_buf + decode_fifo.wptr, buffer, bytes_write);
		fifo_wptr_incby(&decode_fifo, bytes_write);

		buffer += (bytes_write / sizeof(sample_t));
		bytes_out -= bytes_write;
	}

	if (start_immediately) {
		current_audio_state = DECODE_STATE_RUNNING;
	}
}


// XXXX is this really buffer_size, or number_samples?
bool_t decode_output_can_write(u32_t buffer_size, u32_t sample_rate) {
	size_t freebytes;

	// XXXX full port from ip3k
	
	freebytes = fifo_bytes_free(&decode_fifo);

	if (freebytes >= buffer_size) {
		return TRUE;
	}

	return FALSE;
}

