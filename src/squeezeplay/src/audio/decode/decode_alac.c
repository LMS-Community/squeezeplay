/*
** Copyright 2007-2009 Logitech. All Rights Reserved.
**
** This material is confidential and shall remain as such. Any unauthorized
** use, distribution, reproduction or storage of this material or any part
** thereof is strictly prohibited.   
*/

#include "common.h"

#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#include "audio/mp4.h"
#include "audio/alac/alac.h"

#define NUM_CHANNELS       2

// XXXX how big really?
#define OUTPUT_BUFFER_SIZE (NUM_CHANNELS * 4096 * sizeof(sample_t))


struct decode_alac {
	/* alac decoder */
	bool_t init;
	AVCodecContext alacdec;

	/* mp4 parser */
	struct decode_mp4 mp4;

	/* stream info */
	int sample_rate;
	int num_channels;

	/* buffers */
	sample_t *output_buffer;
};


static bool_t decode_alac_callback(void *data) {
	struct decode_alac *self = (struct decode_alac *) data;
	bool_t streaming;
	AVPacket avpkt;
	unsigned int outputsize;
	int num;
	sample_t *wptr, s;
	size_t len;
	int i, frames;
	size_t conf_size;
	u8_t *conf;
	int samplesize;

	if (current_decoder_state & DECODE_STATE_ERROR) {
		return FALSE;
	}

	if (!self->init) {
		size_t status = mp4_open(&self->mp4);
		if (status == 2) {
			return TRUE;		/* need to wait for some more data */
		} else 	if (status != 1) {
			LOG_WARN(log_audio_codec, "mp4_open() failed");
			current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
			return FALSE;
		}

		mp4_track_conf(&self->mp4, 0, &conf, &conf_size);
		if (!conf) {
			LOG_WARN(log_audio_codec, "mp4_track_conf() failed");
			current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
			return FALSE;
		}

		self->alacdec.channels = self->num_channels;
		self->alacdec.extradata = conf + 28;
		self->alacdec.extradata_size = conf_size - 28;

		if (alac_decode_init(&self->alacdec) < 0) {
			LOG_WARN(log_audio_codec, "alac_decode_init() failed");
			current_decoder_state |= DECODE_STATE_ERROR;
			return FALSE;
		}

		self->sample_rate = self->alacdec.samplerate;
		self->num_channels = self->alacdec.channels;

		LOG_INFO(log_audio_codec, "sample_rate=%d channels=%d", self->sample_rate, self->num_channels);
		self->init = TRUE;
	}

	avpkt.data = (void *)mp4_read(&self->mp4, 0, &len, &streaming);
	avpkt.size = len;
	if (avpkt.size == 0) {
		if (streaming) {
			return TRUE;	/* need to wait for more */
		} else {
			current_decoder_state |= DECODE_STATE_UNDERRUN;
			return FALSE;
		}
	}

	outputsize = OUTPUT_BUFFER_SIZE;
	if (self->alacdec.sample_fmt == SAMPLE_FMT_S16) outputsize /= 2;

	num = alac_decode_frame(&self->alacdec,
				self->output_buffer, &outputsize,
				&avpkt);

	if (num < 0) {
		LOG_WARN(log_audio_codec, "alac_decode_frame() failed");
		current_decoder_state |= DECODE_STATE_ERROR;
		return FALSE;
	}

	switch (self->alacdec.sample_fmt) {
	case SAMPLE_FMT_S16:
		samplesize = 2;
		break;
	case SAMPLE_FMT_S32:
		samplesize = 4;
		break;
	default:
		LOG_WARN(log_audio_codec, "unsupported sample format: %d", self->alacdec.sample_fmt);
		current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
		return FALSE;
	}

	frames = outputsize / samplesize / self->num_channels;

	wptr = ((sample_t *)(void *)self->output_buffer) + (frames * 2);

	switch (self->alacdec.sample_fmt) {
	case SAMPLE_FMT_S16:
		if (self->num_channels == 1) {
			/* mono */
			s16_t *rptr = ((s16_t *)(void *)self->output_buffer) + (frames * 1);

			for (i = 0; i < frames; i++) {
				s = (*--rptr) << 16;
				*--wptr = s;
				*--wptr = s;
			}
		}
		else if (self->num_channels == 2) {
			/* stereo */
			s16_t *rptr = ((s16_t *)(void *)self->output_buffer) + (frames * 2);

			for (i = 0; i < frames; i++) {
				*--wptr = (*--rptr) << 16;
				*--wptr = (*--rptr) << 16;
			}
		}
		break;

	case SAMPLE_FMT_S32:
		if (self->num_channels == 1) {
			/* mono */
			s32_t *rptr = ((s32_t *)(void *)self->output_buffer) + (frames * 1);

			for (i = 0; i < frames; i++) {
				s = *--rptr;
				*--wptr = s;
				*--wptr = s;
			}
		}
		else if (self->num_channels == 2) {
			/* stereo */

			/* nothing to do */
		}
		break;
	}

	decode_output_samples(self->output_buffer,
			      frames,
			      self->sample_rate);

	return FALSE;
}


static void *decode_alac_start(u8_t *params, u32_t num_params) {
	struct decode_alac *self;

	LOG_DEBUG(log_audio_codec, "decode_alac_start");

	self = calloc(1, sizeof(struct decode_alac));
	self->alacdec.priv_data = calloc(1, alac_priv_data_size);
	mp4_init(&self->mp4);

	self->output_buffer = malloc(OUTPUT_BUFFER_SIZE);

	/* Assume we aren't changing sample rates until proven wrong */
	self->sample_rate = decode_output_samplerate();

	return self;
}


static void decode_alac_stop(void *data) {
	struct decode_alac *self = (struct decode_alac *) data;

	LOG_DEBUG(log_audio_codec, "decode_alac_stop()");

	alac_decode_close(&self->alacdec);
	free(self->alacdec.priv_data);
	mp4_free(&self->mp4);

	if (self->output_buffer) {
		free(self->output_buffer);
		self->output_buffer = NULL;
	}
	
	free(self);
}


static size_t decode_alac_samples(void *data) {
	return BYTES_TO_SAMPLES(OUTPUT_BUFFER_SIZE);
}


// FIXME alac does not work fully yet, see Bug 12421
struct decode_module decode_alac = {
	'l',
	"alc",
	decode_alac_start,
	decode_alac_stop,
	decode_alac_samples,
	decode_alac_callback,
};
