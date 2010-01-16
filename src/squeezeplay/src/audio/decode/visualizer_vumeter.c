/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/mqueue.h"
#include "audio/fifo.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#define VUMETER_DEFAULT_SAMPLE_WINDOW 8 * 1024

int decode_vumeter(lua_State *L) {
	u32_t sample_accumulator[2];
	sample_t *ptr;
	size_t samples_until_wrap;
	s16_t sample;
	s32_t sample_sq;
	size_t i, num_samples;

	num_samples = luaL_optinteger(L, 2, VUMETER_DEFAULT_SAMPLE_WINDOW);

	sample_accumulator[0] = 0;
	sample_accumulator[1] = 0;

	decode_audio_lock();

	if (decode_audio->state & DECODE_STATE_RUNNING) {
		ptr = (sample_t *)(void *)(decode_fifo_buf + decode_audio->fifo.rptr);
		samples_until_wrap = BYTES_TO_SAMPLES(fifo_bytes_until_rptr_wrap(&decode_audio->fifo));

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

	decode_audio_unlock();

	sample_accumulator[0] /= num_samples;
	sample_accumulator[1] /= num_samples;

	lua_newtable(L);
	lua_pushinteger(L, sample_accumulator[0]);
	lua_rawseti(L, -2, 1);
	lua_pushinteger(L, sample_accumulator[1]);
	lua_rawseti(L, -2, 2);

	return 1;
}

