/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"
#include "audio/streambuf.h"
#include "audio/decode/decode_priv.h"
#include "audio/mp4.h"


static int mp4_parse_container_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_track_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_track_header_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_sample_to_chunk_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_sample_table_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_sample_size_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_sample_size2_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_chunk_offset_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_chunk_large_offset_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_mp4a_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_esds_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_mdat_box(struct decode_mp4 *mp4, size_t r);
static int mp4_parse_alac_box(struct decode_mp4 *mp4, size_t r);
static int mp4_skip_box(struct decode_mp4 *mp4, size_t r);


struct mp4_sample_to_chunk {
	u32_t first_chunk;
	u32_t samples_per_chunk;
	u32_t description_index;
};

struct mp4_track {
	int track_id;
	char data_format[4];

	/* number samples */
	u32_t sample_count;

	/* sample size (fixed or variable) */
	u32_t fixed_sample_size;
	u32_t *sample_size;

	/* chunk offsets */
	u32_t chunk_offset_count;
	u64_t *chunk_offset;

	/* sample to chunk */
	u32_t sample_to_chunk_count;
	struct mp4_sample_to_chunk *sample_to_chunk;

	/* stream state */
	u32_t sample_num;		/* current sample */
	u32_t chunk_num;		/* current chunk, index into chunk_offset */
	u32_t chunk_idx;		/* index into sample_to_chunk */
	u32_t chunk_sample_num;		/* current sample in chunk */
	size_t chunk_sample_offset;	/* offset into chunk */

	/* aac configuration */
	u8_t *conf;
	size_t conf_size;
};

struct mp4_parser {
	char *type;
	mp4_read_box_t f;
};

static struct mp4_parser mp4_parsers[] = {
	{ "moov", &mp4_parse_container_box, },
	{ "trak", &mp4_parse_track_box, },
	{ "tkhd", &mp4_parse_track_header_box, },
	{ "mdia", &mp4_parse_container_box, },
	{ "minf", &mp4_parse_container_box, },
	{ "stbl", &mp4_parse_container_box, },
	{ "stsc", &mp4_parse_sample_to_chunk_box, },
	{ "stsd", &mp4_parse_sample_table_box, },
	{ "stsz", &mp4_parse_sample_size_box, },
	{ "stz2", &mp4_parse_sample_size2_box, },
	{ "stco", &mp4_parse_chunk_offset_box, },
	{ "co64", &mp4_parse_chunk_large_offset_box, },
	{ "mp4a", &mp4_parse_mp4a_box, },
	{ "esds", &mp4_parse_esds_box, },
	{ "m4ae", &mp4_parse_mp4a_box, },	// same as mp4a
	{ "mdat", &mp4_parse_mdat_box, },
	{ "alac", &mp4_parse_alac_box, },
	{ NULL, NULL }
};

#define MIN(a,b) (((a)<(b))?(a):(b))

#define FOURCC_EQ(a, b) (a[0]==b[0] && a[1]==b[1] && a[2]==b[2] && a[3]==b[3])

#define MP4_BUFFER_SIZE (8192 * 3)


static ssize_t mp4_fill_buffer(struct decode_mp4 *mp4, bool_t *streaming)
{
	size_t n, r = (mp4->end - mp4->ptr);

	if (r < MIN(MP4_BUFFER_SIZE, mp4->box_size)) {
		memmove(mp4->buf, mp4->ptr, r);
		n = streambuf_read(mp4->buf + r, 0, MP4_BUFFER_SIZE - r, streaming);

		mp4->ptr = mp4->buf;
		mp4->end = mp4->buf + r + n;

		if (n == 0) {
			return -1;
		}

		r = (mp4->end - mp4->ptr);
	}
	else {
		/* update streaming */
		streambuf_read(NULL, 0, 0, streaming);
	}

	return r;
}


static void mp4_get_fullbox(struct decode_mp4 *mp4, int *version, int *flags)
{
	if (version) {
		*version = mp4->ptr[0];
	}
	if (flags) {
		*flags  = mp4->ptr[1] << 16;
		*flags |= mp4->ptr[2] << 8;
		*flags |= mp4->ptr[3];
	}
	mp4->ptr += 4;
	mp4->off += 4;
}


static inline u32_t mp4_get_u32(struct decode_mp4 *mp4)
{
	u32_t v;

	v  = (uint64_t)mp4->ptr[0] << 24;
	v |= (uint64_t)mp4->ptr[1] << 16;
	v |= (uint64_t)mp4->ptr[2] << 8;
	v |= (uint64_t)mp4->ptr[3];

	mp4->ptr += 4;
	mp4->off += 4;
	return v;
}


static inline u64_t mp4_get_u64(struct decode_mp4 *mp4)
{
	u64_t v;

	v  = (uint64_t)mp4->ptr[0] << 56;
	v |= (uint64_t)mp4->ptr[1] << 48;
	v |= (uint64_t)mp4->ptr[2] << 40;
	v |= (uint64_t)mp4->ptr[3] << 32;
	v |= (uint64_t)mp4->ptr[4] << 24;
	v |= (uint64_t)mp4->ptr[5] << 16;
	v |= (uint64_t)mp4->ptr[6] << 8;
	v |= (uint64_t)mp4->ptr[7];

	mp4->ptr += 4;
	mp4->off += 4;
	return v;
}

static inline u8_t mp4_get_u8(struct decode_mp4 *mp4)
{
	mp4->ptr += 1;
	mp4->off += 1;
	return mp4->ptr[-1];
}

static u32_t mp4_get_descr_len(struct decode_mp4 *mp4)
{
	u8_t b;
	u8_t numBytes = 0;
	u32_t length = 0;

    do
    {
        b = mp4_get_u8(mp4);
        numBytes++;
        length = (length << 7) | (b & 0x7F);
    } while ((b & 0x80) && numBytes < 4);

	mp4->box_size -= numBytes;

    return length;
}

static inline int mp4_skip(struct decode_mp4 *mp4, size_t n)
{
	mp4->ptr += n;
	mp4->off += n;
	return 1;
}


static int mp4_parse_container_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_parser *parser;

	/* mp4 box */
	if (r < 8) {
		mp4->box_size = 8;
		return 1;
	}
			
	mp4->box_size = mp4_get_u32(mp4);

	memcpy(mp4->box_type, mp4->ptr, 4);
	mp4_skip(mp4, 4);

	if (mp4->box_size == 0) {
		/* box extends to end of file */
		mp4->box_size = ULONG_MAX;
	} else {
		if (mp4->box_size == 1) {
			/* extended box size */
			mp4->box_size = mp4_get_u64(mp4);
			mp4->box_size -= 8;
		}

		mp4->box_size -= 8;
	}

	LOG_DEBUG(log_audio_codec, "box %.4s, size without header %u (%x)", mp4->box_type, mp4->box_size, mp4->box_size);

	/* find box parser */
	for (parser = &mp4_parsers[0]; parser->type; parser++) {
		if (FOURCC_EQ(mp4->box_type, parser->type)) {
			break;
		}
	}

	if (parser->type) {
		mp4->f = parser->f;
	}
	else {
		mp4->f = mp4_skip_box;
	}

	return 1;
}


static int mp4_parse_track_box(struct decode_mp4 *mp4, size_t r)
{
	mp4->track_idx = mp4->track_count++;

	mp4->track = realloc(mp4->track, sizeof(struct mp4_track) * mp4->track_count);
	memset(&mp4->track[mp4->track_idx], 0, sizeof(struct mp4_track));

	return mp4_parse_container_box(mp4 , r);
}


static int mp4_parse_track_header_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];
	int version;

	if (r < 24) {
		return 1;
	}

	mp4_get_fullbox(mp4, &version, NULL);

	/* skip times */
	if (version == 1) {
		mp4_skip(mp4, 16);
	}
	else {
		mp4_skip(mp4, 8);
	}

	/* track id */
	track->track_id = mp4_get_u32(mp4);

	/* skip rest of box */
	if (version == 1) {
		mp4->box_size -= 24;
	}
	else {
		mp4->box_size -= 16;
	}
	mp4->f = mp4_skip_box;

	return 1;
}


static int mp4_parse_sample_to_chunk_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (!track->sample_to_chunk) {
		if (r < 8) {
			return 1;
		}

		/* skip version, flags */
		mp4_skip(mp4, 4);

		track->sample_to_chunk_count = mp4_get_u32(mp4);
		track->chunk_num = 0;

		track->sample_to_chunk = malloc(sizeof(struct mp4_sample_to_chunk) * track->sample_to_chunk_count);

		mp4->box_size -= 8;
	}

	while (track->chunk_num < track->sample_to_chunk_count) {
		if ((mp4->end - mp4->ptr) < 12) {
			return 1;
		}

		track->sample_to_chunk[track->chunk_num].first_chunk = mp4_get_u32(mp4);
		track->sample_to_chunk[track->chunk_num].samples_per_chunk = mp4_get_u32(mp4);
		track->sample_to_chunk[track->chunk_num].description_index = mp4_get_u32(mp4);

		track->chunk_num++;

		mp4->box_size -= 12;
	}

	track->chunk_num = 0;

	/* skip rest of box */
	mp4->f = mp4_skip_box;

	return 1;
}


static int mp4_parse_sample_table_box(struct decode_mp4 *mp4, size_t r)
{
	int entries;

	if (r < 8) {
		mp4->box_size = 8;
		return 1;
	}

	/* skip version, flags */
	mp4_skip(mp4, 4);
	entries = mp4_get_u32(mp4);

	mp4->f = &mp4_parse_container_box;

	return 1;
}


static int mp4_parse_sample_size_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (!track->sample_count) {
		if (r < 12) {
			return 1;
		}

		/* skip version, flags */
		mp4_skip(mp4, 4);

		track->fixed_sample_size = mp4_get_u32(mp4);
		track->sample_count = mp4_get_u32(mp4);		
		track->sample_num = 0;

		if (track->fixed_sample_size > 0) {
			/* fixed size, skip rest of box */
			mp4->f = mp4_skip_box;
		}

		track->sample_size = malloc(sizeof(u32_t) * track->sample_count);

		mp4->box_size -= 12;
	}

	if (track->fixed_sample_size == 0) {
		while (track->sample_num < track->sample_count) {
			if ((mp4->end - mp4->ptr) < 4) {
				return 1;
			}

			track->sample_size[track->sample_num++] = mp4_get_u32(mp4);
			mp4->box_size -= 4;
		}

		track->sample_num = 0;

		/* skip rest of box */
		mp4->f = mp4_skip_box;
	}

	return 1;
}


static int mp4_parse_sample_size2_box(struct decode_mp4 *mp4, size_t r)
{
	LOG_ERROR(log_audio_codec, "need to implement stz2");
	return 0;
}


static int mp4_parse_chunk_offset_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (!track->chunk_offset_count) {
		if (r < 8) {
			return 1;
		}

		/* skip version, flags */
		mp4_skip(mp4, 4);

		track->chunk_offset_count = mp4_get_u32(mp4);		
		track->sample_num = 0;

		track->chunk_offset = malloc(sizeof(u64_t) * track->chunk_offset_count);

		mp4->box_size -= 8;
	}

	while (track->sample_num < track->chunk_offset_count) {
		if ((mp4->end - mp4->ptr) < 4) {
			return 1;
		}

		track->chunk_offset[track->sample_num++] = mp4_get_u32(mp4);
		mp4->box_size -= 4;
	}

	track->sample_num = 0;

	/* skip rest of box */
	mp4->f = mp4_skip_box;

	return 1;
}


static int mp4_parse_chunk_large_offset_box(struct decode_mp4 *mp4, size_t r)
{
	LOG_ERROR(log_audio_codec, "need to implement co64");
	return 0;
}


static int mp4_parse_mp4a_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (r < 28) {
		return 1;
	}

	memcpy(track->data_format, mp4->box_type, sizeof(track->data_format));

	mp4_skip(mp4, 6); // skip 6 bytes resered
	mp4_skip(mp4, 2); // short unsigned index from 'dref' box
	mp4_skip(mp4, 2); // QUICKTIME audio encoding version
	mp4_skip(mp4, 2); // QUICKTIME audio encoding revision level
	mp4_skip(mp4, 4); // QUICKTIME audio encoding vendor
	mp4_skip(mp4, 2); // audio channels
	mp4_skip(mp4, 2); // audio sample size
	mp4_skip(mp4, 2); // QUICKTIME audio compression id
	mp4_skip(mp4, 2); // QUICKTIME audio packet size
	mp4_skip(mp4, 4); // sample rate

	mp4->f = mp4_parse_container_box;
	return 1;
}


static int mp4_parse_esds_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (r < mp4->box_size) {
		return 1;
	}

	/* skip version, flags */
	mp4_skip(mp4, 4);
	mp4->box_size -= 4;

    /* get and verify ES_DescrTag */
    if (mp4_get_u8(mp4) == 0x03)
    {
        /* read length */
        if (mp4_get_descr_len(mp4) < 5 + 15) {
        	LOG_ERROR(log_audio_codec, "esds 0x03 tag-length too small");
        	return 0;
        }

        /* skip 3 bytes */
        mp4_skip(mp4, 3);
    	mp4->box_size -= 4;
    } else {
        /* skip 2 bytes */
    	mp4_skip(mp4, 2);
    	mp4->box_size -= 3;
    }

    /* get and verify DecoderConfigDescrTab */
    if (mp4_get_u8(mp4) != 0x04) {
       	LOG_ERROR(log_audio_codec, "esds 0x04 tag expected");
    	return 0;
    }

    /* read length */
    if (mp4_get_descr_len(mp4) < 13) {
       	LOG_ERROR(log_audio_codec, "esds 0x04 tag-length too small");
    	return 0;
    }

    mp4_skip(mp4, 1);	// Audio type
    mp4_skip(mp4, 4);	// 0x15000414 ????
    mp4_skip(mp4, 4);	// max bitrate
    mp4_skip(mp4, 4);	// avg bitrate
	mp4->box_size -= 14;

    /* get and verify DecSpecificInfoTag */
    if (mp4_get_u8(mp4) != 0x05) {
       	LOG_ERROR(log_audio_codec, "esds 0x05 tag expected");
    	return 0;
    };
	mp4->box_size -= 1;

    /* read length */
    track->conf_size = mp4_get_descr_len(mp4);
	track->conf = malloc(track->conf_size);
	memcpy(track->conf, mp4->ptr, track->conf_size);

#if 0
	{
		size_t i;
		for (i=35; i<mp4->box_size; i++) {
			printf("%02x %c ", mp4->ptr[i], isalnum(mp4->ptr[i])?mp4->ptr[i]:'.');
			if (i % 8 == 7) printf("\n");
		}
		printf("\n");
	}

	track->conf_size = 10;
	track->conf = malloc(track->conf_size);
	memcpy(track->conf, mp4->ptr+35, track->conf_size);
#endif

	/* ignore the rest */
	mp4->f = mp4_skip_box;

	return 1;

#if 0
	// The tag-length sequences 80 80 80 nn, might only be nn depending upon the encoder
	00 . 00 . 00 . 00 . // 4 bytes version/flags = 8-bit hex version + 24-bit hex flags
	03 . // 1 byte ES descriptor type tag = 8-bit hex value 0x03
	80 . 80 . 80 . // 3 bytes extended descriptor type tag string = 3 * 8-bit hex value
	22 . // 1 byte descriptor type length = 8-bit unsigned length
	00 . 00 . // 2 bytes ES ID = 16-bit unsigned value
	00 . // 1 byte stream priority = 8-bit unsigned value
	04 . //1 byte decoder config descriptor type tag = 8-bit hex value 0x04
	80 . 80 . 80 . // 3 bytes extended descriptor type tag string = 3 * 8-bit hex value
	14 . // 1 byte descriptor type length = 8-bit unsigned length
	40 . // 1 byte object type ID = 8-bit unsigned value
	15 . // 6 bits stream type, 1 bit upstream flag, 1 bit reserved flag
	00 . 18 . 00 . // 3 bytes buffer size = 24-bit unsigned value
	00 . 02 . ee . 00 . // 4 bytes maximum bit rate = 32-bit unsigned value
	00 . 02 . ee . 00 . // 4 bytes average bit rate = 32-bit unsigned value
	05 . // 1 byte decoder specific descriptor type tag
	80 . 80 . 80 . // 3 bytes extended descriptor type tag string
	02 . // 1 byte descriptor type length

	12 . 10 . // ES header start codes = hex dump
	06 . // 1 byte SL config descriptor type tag = 8-bit hex value 0x06
	80 . 80 . 80 . // 3 bytes extended descriptor type tag string = 3 * 8-bit hex value
	01 . // 1 byte descriptor type length = 8-bit unsigned length
	02 . // 1 byte SL value = 8-bit hex value set to 0x02
#endif
}


static int mp4_parse_mdat_box(struct decode_mp4 *mp4, size_t r)
{
	int i;

	if (r < 12) {
		mp4->box_size = 16;
		return 1;
	}

	/* skip any wide atom */
	if (strncmp((const char *)(mp4->ptr + 4), "wide", 4) == 0) {
		mp4_skip(mp4, 8);

		/* skip extra mdat atom */
		if (strncmp((const char *)(mp4->ptr + 4), "mdat", 4) == 0) {
			mp4_skip(mp4, 8);
		}
	}

	LOG_DEBUG(log_audio_codec, "tracks: %d", mp4->track_count);
	for (i=0; i<mp4->track_count; i++) {
		LOG_DEBUG(log_audio_codec, "%d:\t%d, %.4s", i, mp4->track[i].track_id, mp4->track[i].data_format);
	}

	/* start streaming content */
	mp4->track_idx = 0;
	mp4->f = NULL;

	return 1;
}


static int mp4_parse_alac_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (r < mp4->box_size) {
		return 1;
	}

#if 0
	{
		size_t i;
		for (i=0; i<mp4->box_size; i++) {
			printf("%02x %c ", mp4->ptr[i], isalnum(mp4->ptr[i])?mp4->ptr[i]:'.');
			if (i % 8 == 7) printf("\n");
		}
		printf("\n");
	}
#endif

	track->conf_size = mp4->box_size;
	track->conf = malloc(track->conf_size);
	memcpy(track->conf, mp4->ptr, track->conf_size);

	/* skip rest of box */
	mp4->f = mp4_skip_box;

	return 1;
}


static int mp4_skip_box(struct decode_mp4 *mp4, size_t r)
{
	size_t n;

	n = MIN(mp4->box_size, r);
	mp4->box_size -= n;
	mp4_skip(mp4, n);

	if (mp4->box_size == 0) {
		mp4->f = mp4_parse_container_box;
	}

	return 1;
}


void mp4_init(struct decode_mp4 *mp4)
{
	// FIXME +1 is to prevent valgrind error, I really can't spot
	// the off-by-one error in this code :(. See also the commented
	// assert in mp4_read().
	mp4->buf = malloc(MP4_BUFFER_SIZE + 1);
	mp4->ptr = mp4->end = NULL;

	mp4->f = mp4_parse_container_box;
}


size_t mp4_open(struct decode_mp4 *mp4)
{
	while (mp4->f) {
		ssize_t r;
		bool_t streaming;

		r = mp4_fill_buffer(mp4, &streaming);
		if (r < 0) {
			if (streaming) {
				LOG_DEBUG(log_audio_codec, "waiting for more stream");
				return 2;
			} else {
				LOG_ERROR(log_audio_codec, "premature end of stream");
				return 0;
			}
		}

		/* parse box */
		if (!mp4->f(mp4, r))
			return 0;
	}

	/* headers parsed, found mdat */
	return 1;
}


static inline void packet_size(struct mp4_track *track, size_t *pos, size_t *len)
{
	if (track->sample_count <= track->sample_num) {
		*pos = 0;
		*len = 0;
		return;
	}

	*pos = track->chunk_offset[track->chunk_num] + track->chunk_sample_offset;

	if (track->fixed_sample_size) {
		*len = track->fixed_sample_size;
	}
	else {
		*len = track->sample_size[track->sample_num];
	}
}


static inline void next_packet(struct mp4_track *track)
{
	size_t pos, len;

	packet_size(track, &pos, &len);

	track->chunk_sample_offset += len;

	track->sample_num++;
	track->chunk_sample_num++;

	if (track->chunk_sample_num == track->sample_to_chunk[track->chunk_idx].samples_per_chunk) {
		track->chunk_num++;
		track->chunk_sample_num = 0;
		track->chunk_sample_offset = 0;

		if (track->chunk_idx < track->chunk_offset_count
				&& track->sample_to_chunk[track->chunk_idx + 1].first_chunk == track->chunk_num + 1) // first_chunk starts at 1
		{
			track->chunk_idx++;
		}
	}
}


u8_t *mp4_read(struct decode_mp4 *mp4, int track_idx, size_t *rlen, bool_t *streaming)
{
	u8_t *buf;

	while (1) {
		size_t pos, len;
		ssize_t r;
		struct mp4_track *track = &mp4->track[track_idx];

		r = mp4_fill_buffer(mp4, streaming);
		if (r < 0) {
			*rlen = 0;
			return 0;
		}

		/* media data */
		packet_size(track, &pos, &len);

		if (pos == 0) {
			/* end of file */
			*rlen = 0;
			if (streaming) *streaming = 0;	/* if we have reached the logical end of the stream,
												then indicate no longer streaming */
			return 0;
		}

		if (pos && (mp4->off < pos)) {
			mp4_skip(mp4, MIN((size_t)r, pos - mp4->off));

			if (mp4->off < pos) {
				mp4->box_size = pos - mp4->off;
				continue;
			}
		}

		if ((size_t)r < len) {
			mp4->box_size = len;
			continue;
		}

		next_packet(track);

		/* pointer and length of packet */
		// FIXME assert(mp4->ptr + n < mp4->end);
		buf = mp4->ptr;
		*rlen = len;

		/* advance buffer to next packet */
		mp4_skip(mp4, len);

		packet_size(track, &pos, &len);
		mp4->box_size = len;

		return buf;
	}
}


void mp4_track_conf(struct decode_mp4 *mp4, int track, u8_t **conf, size_t *size)
{
	if (track >= mp4->track_count) {
		*conf = NULL;
		*size = 0;
		return;
	}

	*conf = mp4->track[track].conf;
	*size = mp4->track[track].conf_size;
}

int mp4_track_is_type(struct decode_mp4 *mp4, int track, const char *type) {
	return strncmp(mp4->track[track].data_format, type, sizeof (mp4->track[track].data_format)) == 0;
}


void mp4_free(struct decode_mp4 *mp4)
{
	int i;

	if (mp4->buf) {
		free(mp4->buf);
		mp4->buf = NULL;
	}

	for (i=0; i<mp4->track_count; i++) {
		struct mp4_track *track = &mp4->track[i];

		if (track->sample_to_chunk) {
			free(track->sample_to_chunk);
			track->sample_to_chunk = NULL;
		}
		if (track->sample_size) {
			free(track->sample_size);
			track->sample_size = NULL;
		}
		if (track->chunk_offset) {
			free(track->chunk_offset);
			track->chunk_offset = NULL;
		}
		if (track->conf) {
			free(track->conf);
			track->conf = NULL;
		}
	}

	if (mp4->track) {
		free(mp4->track);
		mp4->track = NULL;
	}
}
