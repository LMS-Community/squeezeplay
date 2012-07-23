/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


struct decode_wma {
	int sample_rate;
};


static bool_t decode_wma_win_callback(void *data) {
	struct decode_wma *self = (struct decode_wma *) data;

	LOG_DEBUG(log_audio_codec, "decode_wma_callback()");

	/* XXXX
	 * Check the output buffer has enough room for writing a buffer full of samples.
	 */
//	if (!decode_output_can_write(sizeof(sample_t) * BLOCKSIZE, self->sample_rate)) {
//		return FALSE;
//	}

	/* XXXX
	 * Read compressed wma data from the input stream into a buffer. Check that enough compressed
	 * data is available for decoding.
	 */
	//n = streambuf_read(inputBuffer, minBytes, maxBytes);

	/* XXXX
	 * Decode ...
	 */

	/* XXXX
	 * Write samples to the output buffer
	 */
//	decode_output_samples(outputBuffer, BLOCKSIZE, self->sample_rate, need_scaling, start_immediately, copyright_asserted);
	
	/* XXXX
	 * Return TRUE if output samples have been written to the output buffer, otherwise return FALSE
	 */
	return TRUE;
}		


static u32_t decode_wma_win_period(void *data) {
	/* XXXX
	 * Return the frequency (in ms) that the aboive callback should called to keep the output
	 * buffer full
	 */
	return 1;
}


static void *decode_wma_win_start(u8_t *params, u32_t num_params) {
	struct decode_wma *self;

	LOG_DEBUG(log_audio_codec, "decode_wma_start()");

	self = malloc(sizeof(struct decode_wma));
	memset(self, 0, sizeof(struct decode_wma));

	/* XXXX
	 * Perform any codec specific allocations or initialization.
	 */

	return self;
}


static void decode_wma_win_stop(void *data) {
	struct decode_tones *self = (struct decode_tones *) data;

	LOG_DEBUG(log_audio_codec, "decode_wma_stop()");

	// XXXX streambuf_flush();
	
	/* XXXX
	 * Perform any codec specific deallocations or deinitialization.
	 */

	free(self);
}


struct decode_module decode_wma_win = {
	'w',
	decode_wma_win_start,
	decode_wma_win_stop,
	decode_wma_win_period,
	decode_wma_win_callback,
};
