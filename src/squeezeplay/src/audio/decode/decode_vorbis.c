/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#include <tremor/ogg.h>
#include <tremor/ivorbiscodec.h>
#include <tremor/ivorbisfile.h>


#define OUTPUT_BUFFER_SIZE 8192
#define METADATA_SIZE      1024

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
		//LOG_DEBUG(log_audio_codec, "decode_vorbis_read() - wanted %d, decoder underrun, still streaming? %d", requested_bytes, streaming);

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
	
	//LOG_DEBUG(log_audio_codec, "decode_vorbis_read() - wanted %d, read %d bytes (%d bytes left)", requested_bytes, read_bytes, streambuf_get_usedbytes());

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

static bool_t decode_vorbis_read_header(struct decode_vorbis *self) {
	vorbis_info *vi;
	vorbis_comment *vc;
	
	vi = ov_info(&self->vf, -1);

	if (!vi ||
	    vi->channels > 2) {
		LOG_WARN(log_audio_codec, "too many channels %d", vi->channels);
		current_decoder_state |= (DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED);
		return FALSE;
	}

	self->channels = vi->channels;
	self->sample_rate = vi->rate;
	
	// XXX handle mid-stream channel/rate changes?

	LOG_DEBUG(log_audio_codec, "ov_info channels=%d rate=%d", self->channels, self->sample_rate);
	
	// Read comments and send them to server
	vc = ov_comment(&self->vf, -1);
	if (vc) {
		u8_t *meta = alloca(METADATA_SIZE);
		u8_t *ptr = meta;
		if (ptr) {
			u16_t ptr_free = METADATA_SIZE;
			u16_t len;
			int i;
			
			/* Packet is prefixed with 'Ogg' */
			ptr[0] = 'O';
			ptr[1] = 'g';
			ptr[2] = 'g';
			ptr += 3;
			ptr_free -= 3;
		
			LOG_DEBUG(log_audio_codec, "Sending %d comments to server", vc->comments);
		
			for (i = 0; i < vc->comments; i++) {
				len = (u16_t)vc->comment_lengths[i];
				if (len <= ptr_free - 2) {
					ptr[0] = (len >> 8) & 0xFF;
					ptr[1] = len & 0xFF;
					ptr += 2;
					memcpy(ptr, vc->user_comments[i], len);
					ptr += len;
					ptr_free -= len + 2;
					LOG_DEBUG(log_audio_codec, "saved comment of length %d: %s", len, vc->user_comments[i]);
				}
				else {
					LOG_DEBUG(log_audio_codec, "skipping large comment of length %d: %s", len, vc->user_comments[i]);
				}
			}
			
			decode_queue_metadata(VORBIS_META, meta, METADATA_SIZE - ptr_free);
		}
	}
	
	return TRUE;
}

static bool_t decode_vorbis_callback(void *data) {
	struct decode_vorbis *self = (struct decode_vorbis *) data;
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
			LOG_DEBUG(log_audio_codec, "ov_open_callbacks r=%d", r);
			if (r < 0) {
				ov_clear(&self->vf);
				current_decoder_state |= (DECODE_STATE_ERROR | DECODE_STATE_NOT_SUPPORTED);
				return FALSE;
			}

			self->state = OGG_STATE_HEADER;
			// fall through

		case OGG_STATE_HEADER:
			if ( !decode_vorbis_read_header(self) )
				return FALSE;
			
			self->state = OGG_STATE_STREAM;
			// fall through

		case OGG_STATE_STREAM:

			buffer_size = OUTPUT_BUFFER_SIZE >> 1;

			if (self->channels == 1) {
				buffer_size >>= 1;
			}

			bytes = ov_read(&self->vf, self->output_buffer, buffer_size, &self->bitstream);
			
			//LOG_DEBUG(log_audio_codec, "ov_read decoded %d bytes of PCM\n", bytes);

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
				// If we've crossed a chained bitstream, re-read the header information
				if (self->vf.chained) {
					LOG_DEBUG(log_audio_codec, "Chained bitstream detected, will read new header");
					self->vf.chained = 0;
					if ( !decode_vorbis_read_header(self) )
						return FALSE;
				}
				
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
