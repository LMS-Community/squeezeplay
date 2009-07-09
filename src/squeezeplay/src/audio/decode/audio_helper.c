/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


bool_t decode_check_start_point(void) {
	bool_t reached_start_point;
	size_t track_start_point;
	ssize_t track_start_offset;

	ASSERT_AUDIO_LOCKED();

	if (!decode_audio->check_start_point) {
		/* We are past the start point */
		return false;
	}

	track_start_point = decode_audio->track_start_point;
	
	/* We mark the start point of a track in the decode FIFO. This function
	 * tells us whether we've played past that point.
	 */
	if (decode_audio->fifo.wptr > track_start_point) {
		reached_start_point = ((decode_audio->fifo.rptr > track_start_point) &&
			(decode_audio->fifo.rptr <= decode_audio->fifo.wptr));
	}
	else {
		reached_start_point = ((decode_audio->fifo.rptr > track_start_point) ||
			(decode_audio->fifo.rptr <= decode_audio->fifo.wptr));
	}

	if (!reached_start_point) {
		/* We have not reached the start point */
		return false;
	}
	
	track_start_offset = decode_audio->fifo.rptr - decode_audio->track_start_point;
	if (track_start_offset < 0) {
		track_start_offset += DECODE_FIFO_SIZE;
	}

	/* Past the start point */
	decode_audio->check_start_point = FALSE;
	decode_audio->num_tracks_started++;
	decode_audio->elapsed_samples = BYTES_TO_SAMPLES(track_start_offset);

	return true;
}
