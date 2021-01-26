/*
** Copyright 2019 Ralph Irving. All Rights Reserved.
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#include "audio/mp4.h"

/* Redefined in fdk-aac header file */
#ifdef SAMPLE_MIN
#undef SAMPLE_MIN
#endif
#ifdef SAMPLE_MAX
#undef SAMPLE_MAX
#endif

#include <fdk-aac/aacdecoder_lib.h>

#ifdef AACDECODER_LIB_VL0
#define FDKDEC_VER_AT_LEAST(vl0, vl1) \
    ((AACDECODER_LIB_VL0 > vl0) || \
     (AACDECODER_LIB_VL0 == vl0 && AACDECODER_LIB_VL1 >= vl1))
#else
#define FDKDEC_VER_AT_LEAST(vl0, vl1) 0
#endif

#if !FDKDEC_VER_AT_LEAST(2, 5) // < 2.5.10
#define AAC_PCM_MAX_OUTPUT_CHANNELS AAC_PCM_OUTPUT_CHANNELS
#endif

#define SAMPLES_PER_FRAME  (2048)
#define NUM_CHANNELS       (2)
#define INPUT_BUFFER_SIZE  (4096)
#define OUTPUT_BUFFER_SIZE (NUM_CHANNELS * SAMPLES_PER_FRAME * 2)

struct decode_aac {
	/* he-aac decoder */
	HANDLE_AACDECODER heaacdec;
	TRANSPORT_TYPE type;

	/* mp4 parser */
	int isMP4;
	int mp4_track;
	struct decode_mp4 mp4;

	/* stream info */
	int sample_rate;
	int bits_per_sample;
	int samples_per_frame;
	int num_channels;

	/* buffers */
	UCHAR *input_ptr;
	UCHAR *input_buffer;
	sample_t *output_buffer;

	UINT bytes_read;
	UINT bytes_valid;
};


static bool_t decode_aac_init_heaac(struct decode_aac *self)
{
	struct decode_mp4 *mp4 = &self->mp4;
	AAC_DECODER_ERROR err;
	size_t conf_size;
	u8_t *conf;

	LOG_DEBUG(log_audio_codec, "FDK-AAC");

	self->heaacdec = aacDecoder_Open(self->type, 1);

	if ( !self->heaacdec ) {
		LOG_DEBUG(log_audio_codec, "open failed (%d)", self->type);
		return FALSE;
	}
	
	if (self->isMP4) {
		// FIXME
		self->mp4_track = 0;

		mp4_track_conf(mp4, self->mp4_track, &conf, &conf_size);
		if (!conf) {
			LOG_WARN(log_audio_codec, "no track data");
			goto error;
		}

		if ((err = aacDecoder_ConfigRaw(self->heaacdec, (UCHAR **) &conf, (const UINT *) &conf_size)) != AAC_DEC_OK) {
			LOG_ERROR(log_audio_codec, "can't set raw config (%x)", err);
			goto error;
		}
	}

	/* 0 = muting, 1 = noise */
	if ((err = aacDecoder_SetParam(self->heaacdec, AAC_CONCEAL_METHOD, 0)) != AAC_DEC_OK) {
		LOG_ERROR(log_audio_codec, "can't set conceal method (%x)", err);
		goto error;
	} 

	if ((err = aacDecoder_SetParam(self->heaacdec, AAC_PCM_MAX_OUTPUT_CHANNELS, 2)) != AAC_DEC_OK) {
		LOG_ERROR(log_audio_codec, "can't set max output channels (%x)", err);
		goto error;
	} 

	return TRUE;

 error:
	aacDecoder_Close(self->heaacdec);
	self->heaacdec = NULL;
	return FALSE;
}


static u32_t decode_aac_callback_heaac(struct decode_aac *self)
{
	AAC_DECODER_ERROR err;
	CStreamInfo *stream_info;
	s16_t *rptr;
	sample_t *wptr;
	sample_t s;
	int frames;
	int i;

	err = aacDecoder_Fill(self->heaacdec, &self->input_ptr, &self->bytes_read, &self->bytes_valid);

	/* Give up decoded on any other error */
	if (err != AAC_DEC_OK) {
		LOG_DEBUG(log_audio_codec, "fill error %x", err);

		current_decoder_state |= DECODE_STATE_ERROR;
		return FALSE;
	}

	err = aacDecoder_DecodeFrame(self->heaacdec, (INT_PCM *)self->output_buffer, OUTPUT_BUFFER_SIZE / sizeof(INT_PCM), 0);

	if (err == AAC_DEC_NOT_ENOUGH_BITS) {
		LOG_DEBUG(log_audio_codec, "not enough bits");
		return FALSE;
	}

	if (err == AAC_DEC_TRANSPORT_SYNC_ERROR) {
		LOG_WARN(log_audio_codec, "sync error %d %d", self->bytes_read, self->bytes_valid);
		return TRUE;
	}

	/* Do concealment of corrupted frames */
	if (IS_DECODE_ERROR(err)) {
		LOG_WARN(log_audio_codec, "concealing corrupted frames %x", err);
		err = aacDecoder_DecodeFrame(self->heaacdec, (INT_PCM *)self->output_buffer, OUTPUT_BUFFER_SIZE / sizeof(INT_PCM), AACDEC_CONCEAL);
	}

	/* Give up decoded on any other error */
	if (err != AAC_DEC_OK) {
		LOG_DEBUG(log_audio_codec, "decode aac frame error %x", err);

		current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED ;
		return FALSE;
	}

	stream_info = aacDecoder_GetStreamInfo(self->heaacdec);

	/* No samples available if frame size is zero */
	if (stream_info->frameSize == 0) {
		return FALSE;
	}

	self->samples_per_frame = stream_info->frameSize;

	if (self->num_channels != stream_info->numChannels || self->sample_rate != stream_info->sampleRate) {
		self->num_channels = stream_info->numChannels;
		self->sample_rate = stream_info->sampleRate;

		LOG_DEBUG(log_audio_codec, "MPEG-4 AOT: %d", stream_info->aot);
		LOG_DEBUG(log_audio_codec, "MPEG-2 Profile: %d", stream_info->profile);
		LOG_DEBUG(log_audio_codec, "Sample rate: %d", stream_info->sampleRate);
		LOG_DEBUG(log_audio_codec, "Channels: %d", stream_info->numChannels);
		LOG_DEBUG(log_audio_codec, "Frame size: %d", stream_info->frameSize);
	}

	/* From decode_alac.c 16bit sample size only, 32bit not included */
	/* frames = outputsize / samplesize / self->num_channels; */
	frames = self->samples_per_frame * self->num_channels;

	wptr = ((sample_t *)(void *)self->output_buffer) + (frames * 2);

	if (self->num_channels == 1) {
		/* mono */
		rptr = ((s16_t *)(void *)self->output_buffer) + (frames * 1);

		for (i = 0; i < frames; i++) {
			s = (*--rptr) << 16;
			*--wptr = s;
			*--wptr = s;
		}
	}
	else if (self->num_channels == 2) {
		/* stereo */
		rptr = ((s16_t *)(void *)self->output_buffer) + (frames * 2);

		for (i = 0; i < frames; i++) {
			*--wptr = (*--rptr) << 16;
			*--wptr = (*--rptr) << 16;
		}
	}
	else if (self->num_channels > 2) {
		current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
		return FALSE;
	}

	return TRUE;
}


static inline bool_t do_mp4_read(struct decode_aac *self, bool_t *streaming) {
	if (self->bytes_valid == 0) {
		if (self->isMP4) {
			size_t bytes_read = 0;
			self->input_ptr = mp4_read(&self->mp4, self->mp4_track, &bytes_read, streaming);
			self->bytes_read = bytes_read;
		}
		else {
			self->bytes_read = streambuf_read(self->input_buffer, 0, INPUT_BUFFER_SIZE, streaming);
			self->input_ptr = self->input_buffer;
		}

		self->bytes_valid = self->bytes_read;
		current_decoder_state &= ~DECODE_STATE_UNDERRUN;
		
		if (self->bytes_read == 0) {
			if (*streaming) {
				return TRUE;	/* need to wait for more */
			} else {
				current_decoder_state |= DECODE_STATE_UNDERRUN;
				return FALSE;
			}
		}
	}

	return TRUE;
}


static bool_t decode_aac_callback(void *data) {
	struct decode_aac *self = (struct decode_aac *) data;
	bool_t streaming;

	if (current_decoder_state & DECODE_STATE_ERROR) {
		return FALSE;
	}

	if (!self->heaacdec) {
		if (self->isMP4) {
			size_t status = mp4_open(&self->mp4);
			if (status == 2) {
				return TRUE;		/* need to wait for some more data */
			} else 	if (status != 1) {
				current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
				return FALSE;
			}
		}

		/* HE-AAC stream */
		if (!decode_aac_init_heaac(self)) {
			current_decoder_state |= DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED;
			return FALSE;
		}
	}

	if (self->heaacdec) {
		if (!do_mp4_read(self, &streaming)) {
			return FALSE;
		}

		if (self->bytes_read == 0) {
			return TRUE;	/* need to wait for more */
		}

		if (!decode_aac_callback_heaac(self)) {
			return FALSE;
		}
	}

	decode_output_samples(self->output_buffer,
			      self->samples_per_frame,
			      self->sample_rate);

	return TRUE;
}


static void *decode_aac_start(u8_t *params, u32_t num_params) {
	struct decode_aac *self;

	LOG_DEBUG(log_audio_codec, "decode_aac_start(%c)", params[0]);

	self = malloc(sizeof(struct decode_aac));
	memset(self, 0, sizeof(struct decode_aac));

	self->input_buffer = malloc(INPUT_BUFFER_SIZE);
	self->output_buffer = malloc(OUTPUT_BUFFER_SIZE * sizeof(sample_t));

	/* Assume we aren't changing sample rates until proven wrong */
	self->sample_rate = decode_output_samplerate();

	/* param[0]:	'1' (adif bitstream), '2' (adts bitstream), '3' (loas/latm bitstream),
			'4' (rawpkts), '5' (mp4 file format), '6' (latm within rawpkts) */

	self->type = params[0] - '0';

	switch (params[0]) {
		case '3': /* TT_MP4_LOAS */
			self->type = TT_MP4_LOAS;
			break;

		case '4': /* TT_MP4_RAWPACKETS */
			self->type = TT_MP4_RAW;
			break;

		case '5': /* TT_MP4_MP4F */
			self->isMP4 = 1;
			self->type = TT_MP4_RAW;
			mp4_init(&self->mp4);
			break;
	}

	return self;
}


static void decode_aac_stop(void *data) {
	struct decode_aac *self = (struct decode_aac *) data;

	LOG_DEBUG(log_audio_codec, "decode_aac_stop()");

	if (self->heaacdec) {
		aacDecoder_Close(self->heaacdec);
		self->heaacdec = NULL;
	}

	if (self->isMP4) {
		mp4_free(&self->mp4);
	}

	if (self->output_buffer) {
		free(self->output_buffer);
		self->output_buffer = NULL;
	}

	if (self->input_buffer) {
		free(self->input_buffer);
		self->input_buffer = NULL;
	}
	
	free(self);
}


static size_t decode_aac_samples(void *data) {
	return BYTES_TO_SAMPLES(OUTPUT_BUFFER_SIZE);
}


struct decode_module decode_aac = {
	'a',
	"aac",
	decode_aac_start,
	decode_aac_stop,
	decode_aac_samples,
	decode_aac_callback,
};
