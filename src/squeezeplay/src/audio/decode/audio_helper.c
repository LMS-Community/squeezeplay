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


void decode_init_buffers(void *buf, bool_t prio_inherit) {
	decode_audio = buf;
	decode_fifo_buf = ((u8_t *)decode_audio) + sizeof(struct decode_audio);
	effect_fifo_buf = ((u8_t *)decode_fifo_buf) + DECODE_FIFO_SIZE;

	memset(decode_audio, 0, sizeof(struct decode_audio));
	decode_audio->set_sample_rate = 44100;
	fifo_init(&decode_audio->fifo, DECODE_FIFO_SIZE, prio_inherit);
	fifo_init(&decode_audio->effect_fifo, EFFECT_FIFO_SIZE, prio_inherit);
}


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
	decode_audio->sync_elapsed_timestamp = 0; /* bug 15344: don't send previous-track data */

	return true;
}


static inline s16_t s16_clip(s16_t a, s16_t b) {
	s32_t s = a + b;

	if (s < -0x8000) {
		return -0x8000;
	} else if (s > 0x7fff) {
		return 0x7fff;
	}
	else {
		return s;
	}
}

#ifdef RESAMPLE_EFFECTS
#   include "../speex/speex_resampler.h"
#   define EFFECTS_SAMPLE_RATE 44100
#   define EFFECTS_RESAMPLE_QUALITY 2
	static SpeexResamplerState *resampler;
#endif

static int get_effects_samples(effect_t* output_samples_buf, size_t n_samples, unsigned int output_sample_rate) {
		size_t samples_available, samples_until_wrap;

        fifo_lock(&decode_audio->effect_fifo);

        samples_available = fifo_bytes_used(&decode_audio->effect_fifo) / sizeof(effect_t);

        /* shortcut the common case */
        if (samples_available == 0
#ifdef RESAMPLE_EFFECTS
        		&& !(resampler && jive_resampler_has_samples(resampler, 0))
#endif
			)
        {
                fifo_unlock(&decode_audio->effect_fifo);
                return 0;
        }

        samples_until_wrap = fifo_bytes_until_rptr_wrap(&decode_audio->effect_fifo) / sizeof(effect_t);
        if (samples_until_wrap < samples_available) {
        	samples_available = samples_until_wrap;
        }


#ifdef RESAMPLE_EFFECTS
       if (output_sample_rate != EFFECTS_SAMPLE_RATE) {
                spx_uint32_t in_samples;
                spx_uint32_t out_samples;
                int err;

                if (!resampler) {
                        resampler = jive_resampler_init(1, EFFECTS_SAMPLE_RATE, output_sample_rate, EFFECTS_RESAMPLE_QUALITY, &err);
                } else {
                        spx_uint32_t in_rate, out_rate;
                        jive_resampler_get_rate(resampler, &in_rate, &out_rate);
                        if (out_rate != output_sample_rate) {
                                jive_resampler_reset_mem(resampler);
                                jive_resampler_set_rate(resampler, EFFECTS_SAMPLE_RATE, output_sample_rate);
                        }
                }

                in_samples = samples_available;
                out_samples = n_samples;

                jive_resampler_process_int(resampler, 0,
                        (spx_int16_t *)(effect_t *)(void *)(effect_fifo_buf + decode_audio->effect_fifo.rptr),
                        &in_samples,
                        output_samples_buf, &out_samples);

                fifo_rptr_incby(&decode_audio->effect_fifo, in_samples * sizeof(effect_t));

                n_samples = out_samples;
        }
#else
        if (0) {}
#endif
        else {          /* no resampling */
                if (n_samples > samples_available) {
                        n_samples = samples_available;
                }
                memcpy(output_samples_buf,
                                effect_fifo_buf + decode_audio->effect_fifo.rptr,
                                n_samples * sizeof(effect_t));
                fifo_rptr_incby(&decode_audio->effect_fifo, n_samples * sizeof(effect_t));
        }

        fifo_unlock(&decode_audio->effect_fifo);

        return n_samples;
}

/*
 * This function is called by to copy effects to the audio buffer.
 */
void decode_mix_effects(void *outputBuffer,
			size_t framesPerBuffer,
			int sample_width,
			int output_sample_rate)
{
	effect_t effects_buffer[EFFECT_FIFO_SIZE]; /* pretty arbitrary size */
	int effects_frames;

	for ( ;
			framesPerBuffer > 0 &&
				(effects_frames = get_effects_samples(effects_buffer, framesPerBuffer, output_sample_rate)) > 0;
			framesPerBuffer -= effects_frames)
	{
		effect_t *effect_ptr;
		int i;
		s32_t s;

		effect_ptr = effects_buffer;

		if (sample_width == 24) {
			s32_t *output_ptr  = (sample_t *)outputBuffer;

			for (i=0; i < effects_frames; i++) {
				s = (*effect_ptr++) << 8;
				s = fixed_mul(decode_audio->effect_gain, s);

				*output_ptr = sample_clip(*output_ptr, s);
				output_ptr++;

				*output_ptr = sample_clip(*output_ptr, s);
				output_ptr++;
			}

			outputBuffer = output_ptr;
		}
		else if (sample_width == 16) {
			s16_t *output_ptr  = (s16_t *)outputBuffer;

			for (i=0; i < effects_frames; i++) {
				s = (*effect_ptr++) << 8;
				s = fixed_mul(decode_audio->effect_gain, s);

				*output_ptr = s16_clip(*output_ptr, s >> 8);
				output_ptr++;

				*output_ptr = s16_clip(*output_ptr, s >> 8);
				output_ptr++;
			}

			outputBuffer = output_ptr;
		}
	}
}

