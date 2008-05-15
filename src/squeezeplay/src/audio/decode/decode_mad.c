/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#include <mad.h>


/* The input buffer size is at the theoretical maximum frame
 * size - MPEG 2.5 Layer II 8KHz @ 160kbps with padding slot
 */
#define INPUT_BUFFER_SIZE 2890

#define OUTPUT_BUFFER_SIZE (2*32*36 * sizeof(sample_t))


struct decode_mad {
	struct mad_stream stream;
	struct mad_frame frame;
	struct mad_synth synth;

	u8_t *input_buffer;
	sample_t *output_buffer;
	u8_t *guard_pointer;

	enum {
		MAD_STATE_OK = 0,
		MAD_STATE_PCM_READY,
		MAD_STATE_END_OF_FILE,
		MAD_STATE_ERROR,
	} state;

	int sample_rate;
};


static void decode_mad_frame(struct decode_mad *self) {
	size_t read_max, read_num, remaining;
	u8_t *read_start;
	bool_t streaming;

	do {
		/* The input stream must be filled if it's the first
		 * execution of the loop or it becomes empty
		 */
		if (self->stream.buffer == NULL ||
		    self->stream.error == MAD_ERROR_BUFLEN) {

			/* If there's data left from the last time,
			 * copy it to the beginning of the input buffer
			 */
			if (self->stream.next_frame) {
				remaining = self->stream.bufend - self->stream.next_frame;
				memcpy(self->input_buffer, self->stream.next_frame, remaining);
			}
			/* Otherwise fill the input buffer */
			else {
				remaining = 0;
			}

			read_start = self->input_buffer + remaining;
			read_max = INPUT_BUFFER_SIZE - remaining;


			read_num = streambuf_read(read_start, 0, read_max, &streaming);

			if (!read_num) {
				current_decoder_state |= DECODE_STATE_UNDERRUN;
				if (streaming) {
					return;
				}

				/* If we're at the end of the input file, write
				 * out the buffer guard.
				 */
				self->guard_pointer = read_start + read_num;
				memset(self->guard_pointer, 0, MAD_BUFFER_GUARD);
				read_num += MAD_BUFFER_GUARD;
			}
			else {
				current_decoder_state &= ~DECODE_STATE_UNDERRUN;
			}

			/* Send the new content to libmad's stream decoder
			 */
			mad_stream_buffer(&self->stream,
					  self->input_buffer,
					  read_num + remaining);

			self->stream.error = MAD_ERROR_NONE;
		}

		if (mad_frame_decode(&self->frame, &self->stream)) {
			if (MAD_RECOVERABLE(self->stream.error)) {
				if (self->stream.error != MAD_ERROR_LOSTSYNC ||
				    self->stream.this_frame != self->guard_pointer) {
					continue;
				}
			}
			else {
				/* Need more data, try again */
				if (self->stream.error == MAD_ERROR_BUFLEN) {
					continue;
				}

				// XXXX unrecoverable error
				DEBUG_ERROR("Unrecoverable frame error %d", self->stream.error);
				self->state = MAD_STATE_ERROR;
				current_decoder_state |= DECODE_STATE_ERROR;
				return;
			}
		}

		mad_synth_frame(&self->synth, &self->frame);

		/* pcm is now ready  */
		self->state = MAD_STATE_PCM_READY;
	} while (0);
}		


static void decode_mad_output(struct decode_mad *self) {
	sample_t *buf;
	mad_fixed_t *left, *right;
	int i;

	self->sample_rate = self->frame.header.samplerate;

	if (!decode_output_can_write(self->synth.pcm.length * 2 * sizeof(sample_t), self->sample_rate)) {
		self->state = MAD_STATE_PCM_READY;
		return;
	}

	// XXXX parse xing header

	buf = self->output_buffer;

	left = self->synth.pcm.samples[0];
	right = self->synth.pcm.samples[1];

	if (self->synth.pcm.channels == 2) {
		/* stero */
		for (i=0; i<self->synth.pcm.length; i++) {
			*buf++ = *left++ >> (MAD_F_FRACBITS + 1 - 24);
			*buf++ = *right++ >> (MAD_F_FRACBITS + 1 - 24);
		}
	}
	else {
		/* mono */
		sample_t s;

		for (i=0; i<self->synth.pcm.length; i++) {
			s = *left++ >> (MAD_F_FRACBITS + 1 - 24);

			*buf++ = s;
			*buf++ = s;
		}
	}
	
	decode_output_samples(self->output_buffer,
			      self->synth.pcm.length,
			      self->sample_rate,
			      FALSE,
			      TRUE,
			      FALSE);

	/* If we've come to the guard pointer, we're done */
	if (self->stream.this_frame == self->guard_pointer) {
		DEBUG_TRACE("Reached end of stream");

		self->state = MAD_STATE_END_OF_FILE;

		// XXXX remove padding?
	}
	else {
		self->state = MAD_STATE_OK;
	}
}


static bool_t decode_mad_callback(void *data) {
	struct decode_mad *self = (struct decode_mad *) data;


	/* End of file? */
	if (self->state == MAD_STATE_END_OF_FILE ||
	    self->state == MAD_STATE_ERROR) {
		return FALSE;
	}

	if (!decode_output_can_write(OUTPUT_BUFFER_SIZE, self->sample_rate)) {
		return 0;
	}

	if (self->state == MAD_STATE_OK) {
		decode_mad_frame(self);
	}

	if (self->state == MAD_STATE_PCM_READY) {
		decode_mad_output(self);
	}

	return TRUE;
}


static u32_t decode_mad_period(void *data) {
	struct decode_mad *self = (struct decode_mad *) data;

	if (self->sample_rate <= 48000) {
		return 8;
	}
	else {
		return 4;
	}
}


static void *decode_mad_start(u8_t *params, u32_t num_params) {
	struct decode_mad *self;

	DEBUG_TRACE("decode_mad_start()");

	self = malloc(sizeof(struct decode_mad));
	memset(self, 0, sizeof(struct decode_mad));

	self->input_buffer = malloc(INPUT_BUFFER_SIZE + MAD_BUFFER_GUARD);
	self->output_buffer = malloc(OUTPUT_BUFFER_SIZE);
	self->guard_pointer = NULL;

	mad_stream_init(&self->stream);
	mad_frame_init(&self->frame);
	mad_synth_init(&self->synth);

	/* Assume we aren't changing sample rates until proven wrong */
	self->sample_rate = decode_output_samplerate();
	
	return self;
}


static void decode_mad_stop(void *data) {
	struct decode_mad *self = (struct decode_mad *) data;

	DEBUG_TRACE("decode_mad_stop()");

	mad_stream_finish(&self->stream);
	mad_frame_finish(&self->frame);
	mad_synth_finish(&self->synth);
	
	free(self->input_buffer);
	free(self->output_buffer);
	free(self);
}


struct decode_module decode_mad = {
	'm',
	decode_mad_start,
	decode_mad_stop,
	decode_mad_period,
	decode_mad_callback,
};
