/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"

#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#include <tremor/ogg.h>
#include <tremor/ivorbiscodec.h>
#include <tremor/ivorbisfile.h>


#define OUTPUT_BUFFER_SIZE 8192


struct decode_vorbis {
	OggVorbis_File vf;
	int bitstream;

	enum {
		OGG_STATE_INIT = 0,
		OGG_STATE_HEADER,
		OGG_STATE_STREAM,
	} state;

	char *output_buffer;

	int channels;
	int sample_rate;
};


static size_t decode_vorbis_read(void *ptr, size_t size, size_t nmemb, void *datasource) {
	size_t requested_bytes, read_bytes;
	bool_t streaming;

	requested_bytes = size * nmemb;
	if (!requested_bytes) {
		return 0;
	}

	read_bytes = streambuf_read(ptr, 0, requested_bytes, &streaming);

	if (read_bytes == 0) {
		LOG_DEBUG(log_audio_codec, "decode_vorbis_read() - decoder underrun, still streaming? %d", streaming);

		current_decoder_state |= DECODE_STATE_UNDERRUN;

		if (streaming) {
			return OGG_STARVED;
		}
		else {
			return 0;
		}
	}
	else {
		current_decoder_state &= ~DECODE_STATE_UNDERRUN;
	}
	
	LOG_DEBUG(log_audio_codec, "decode_vorbis_read() - read %d bytes", read_bytes);

	return read_bytes;
}


static int decode_vorbis_seek(void *datasource, ogg_int64_t offset, int whence) {
	return -1; /* stream is not seekable */
}


static int decode_vorbis_close(void *datasource) {
	return 0;
}


static long decode_vorbis_tell(void *datasource) {
	return -1; /* stream is not seekable */
}


static ov_callbacks vorbis_callbacks = {
	decode_vorbis_read,
	decode_vorbis_seek,
	decode_vorbis_close,
	decode_vorbis_tell,
};


static bool_t decode_vorbis_callback(void *data) {
	struct decode_vorbis *self = (struct decode_vorbis *) data;
	vorbis_info *vi;
	size_t i, nsamples;
	int r, buffer_size;
	long bytes;
	s16_t *rptr;
	sample_t *wptr;

	while (!(current_decoder_state & DECODE_STATE_ERROR)) {
		switch (self->state) {
		case OGG_STATE_INIT:
			LOG_DEBUG(log_audio_codec, "Calling ov_open_callbacks");

			r = ov_open_callbacks(self, &self->vf, NULL, 0, vorbis_callbacks);
			if (r < 0) {
				LOG_WARN(log_audio_codec, "ov_open_callbacks r=%d", r);

				ov_clear(&self->vf);
				current_decoder_state |= (DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED);
				return FALSE;
			}

			self->state = OGG_STATE_HEADER;
			// fall through

		case OGG_STATE_HEADER:
			vi = ov_info(&self->vf, -1);

			if (!vi ||
			    vi->channels > 2) {
				LOG_WARN(log_audio_codec, "too many channels %d", vi->channels);
				current_decoder_state |= (DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED);
				return FALSE;
			}

			self->channels = vi->channels;
			self->sample_rate = vi->rate;

			LOG_DEBUG(log_audio_codec, "ov_info channels=%d rate=%d", self->channels, self->sample_rate);

			self->state = OGG_STATE_STREAM;
			// fall through

		case OGG_STATE_STREAM:

			buffer_size = OUTPUT_BUFFER_SIZE >> 1;

			if (self->channels == 1) {
				buffer_size >>= 1;
			}

			bytes = ov_read(&self->vf, self->output_buffer, buffer_size, &self->bitstream);
			
			LOG_DEBUG(log_audio_codec, "ov_read decoded %d bytes of PCM\n", bytes);

			switch (bytes) {
			case OV_HOLE:
				LOG_DEBUG(log_audio_codec, "OV_HOLE");
				return FALSE;

			case OV_EBADLINK:
			case OV_EINVAL:
				LOG_DEBUG(log_audio_codec, "OV_EBADLINK or OV_EINVAL");

				current_decoder_state |= DECODE_STATE_ERROR;
				return FALSE;

			case 0:
				LOG_DEBUG(log_audio_codec, "End of ogg stream");

				current_decoder_state |= DECODE_STATE_ERROR;
				return FALSE;

			default:
				if (self->channels == 1) {
					nsamples = bytes / 2;

					/* mono */
					rptr = ((s16_t *)(void *)self->output_buffer) + nsamples;
					wptr = ((sample_t *)(void *)self->output_buffer) + (nsamples * 2);

					for (i = 0; i < nsamples; i++) {
						sample_t s = (*--rptr) << 16;
						*--wptr = s;
						*--wptr = s;
					}
				}
				else {
					nsamples = bytes / 4;

					/* stereo */
					rptr = ((s16_t *)(void *)self->output_buffer) + (nsamples * 2);
					wptr = ((sample_t *)(void *)self->output_buffer) + (nsamples * 2);

					for (i = 0; i < nsamples; i++) {
						*--wptr = (*--rptr) << 16;
						*--wptr = (*--rptr) << 16;
					}
				}

				decode_output_samples((sample_t *)(void *)self->output_buffer, nsamples, self->sample_rate);

				return TRUE;
			}

			break;
		}
	}

	// XXX this is FALSE in ip3k
	return TRUE;
}


static size_t decode_vorbis_samples(void *data) {
	return BYTES_TO_SAMPLES(OUTPUT_BUFFER_SIZE);
}


static void *decode_vorbis_start(u8_t *params, u32_t num_params) {
	struct decode_vorbis *self;

	LOG_DEBUG(log_audio_codec, "decode_vorbis_start()");

	self = malloc(sizeof(struct decode_vorbis));
	memset(self, 0, sizeof(struct decode_vorbis));

	self->output_buffer = malloc(OUTPUT_BUFFER_SIZE);
	self->state = OGG_STATE_INIT;
	
	return self;
}


static void decode_vorbis_stop(void *data) {
	struct decode_vorbis *self = (struct decode_vorbis *) data;

	LOG_DEBUG(log_audio_codec, "decode_vorbis_stop()");

	free(self->output_buffer);
	free(self);
}


struct decode_module decode_vorbis = {
	'o',
	"ogg",
	decode_vorbis_start,
	decode_vorbis_stop,
	decode_vorbis_samples,
	decode_vorbis_callback,
};
