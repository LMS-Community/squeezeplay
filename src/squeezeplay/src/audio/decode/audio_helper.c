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


static void decode_mix_effects_ch(int ch, void *outputBuffer,
				  size_t framesPerBuffer)
{
	struct fifo *ch_fifo;
	size_t len, bytes_used;
	sample_t *output_ptr;

	ASSERT_AUDIO_LOCKED();

	len = framesPerBuffer * sizeof(effect_t);

	// XXXX don't lock channels?
	ch_fifo = &decode_audio->effect_fifo[ch];
	fifo_lock(ch_fifo);

	bytes_used = fifo_bytes_used(ch_fifo);
	if (bytes_used > len) {
		bytes_used = len;
	}

	output_ptr = (sample_t *)(void *)outputBuffer;
	while (bytes_used > 0) {
		effect_t *effect_ptr;
		sample_t s;
		size_t i, bytes_write;

		bytes_write = fifo_bytes_until_rptr_wrap(ch_fifo);
		if (bytes_write > bytes_used) {
			bytes_write = bytes_used;
		}

		effect_ptr = (effect_t *)(effect_fifo_buf[ch] + ch_fifo->rptr);

		for (i=0; i<(bytes_write / sizeof(effect_t)); i++) {
			s = (*effect_ptr++) << 16;

			s = fixed_mul(decode_audio->effect_gain, s);

			*output_ptr = (*output_ptr >> 1) + (s >> 1);
			output_ptr++;

			*output_ptr = (*output_ptr >> 1) + (s >> 1);
			output_ptr++;
		}

		fifo_rptr_incby(ch_fifo, bytes_write);
		bytes_used -= bytes_write;
	}

	fifo_unlock(ch_fifo);
}

/*
 * This function is called by to copy effects to the audio buffer.
 */
void decode_mix_effects(void *outputBuffer, size_t framesPerBuffer)
{
	decode_mix_effects_ch(0, outputBuffer, framesPerBuffer);
	decode_mix_effects_ch(1, outputBuffer, framesPerBuffer);
}
