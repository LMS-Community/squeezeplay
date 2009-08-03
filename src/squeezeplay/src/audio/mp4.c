/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "audio/streambuf.h"
#include "audio/decode/decode_priv.h"
#include "audio/mp4.h"


static void mp4_parse_container_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_track_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_track_header_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_sample_table_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_sample_size_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_sample_size2_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_mp4a_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_esds_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_mdat_box(struct decode_mp4 *mp4, size_t r);
static void mp4_parse_alac_box(struct decode_mp4 *mp4, size_t r);
static void mp4_skip_box(struct decode_mp4 *mp4, size_t r);


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
	{ "stsd", &mp4_parse_sample_table_box, },
	{ "stsz", &mp4_parse_sample_size_box, },
	{ "stz2", &mp4_parse_sample_size2_box, },
	{ "mp4a", &mp4_parse_mp4a_box, },
	{ "esds", &mp4_parse_esds_box, },
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

	return r;
}


static void mp4_get_fullbox(struct decode_mp4 *mp4, int *version, int *flags)
{
	if (version) {
		*version = mp4->ptr[0];
	}
	if (flags) {
		*flags  = mp4->ptr[1] << 16;
		*flags |= mp4->ptr[1] << 8;
		*flags |= mp4->ptr[1];
	}
	mp4->ptr += 4;
}


static u32_t mp4_get_u32(struct decode_mp4 *mp4)
{
	u32_t v;

	v  = (uint64_t)mp4->ptr[0] << 24;
	v |= (uint64_t)mp4->ptr[1] << 16;
	v |= (uint64_t)mp4->ptr[2] << 8;
	v |= (uint64_t)mp4->ptr[3];

	mp4->ptr += 4;
	return v;
}


static u64_t mp4_get_u64(struct decode_mp4 *mp4)
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
	return v;
}


static void mp4_parse_container_box(struct decode_mp4 *mp4, size_t r)
{
	static struct mp4_parser *parser;
	int i;

	/* mp4 box */
	if (r < 8) {
		mp4->box_size = 8;
		return;
	}
			
	mp4->box_size = mp4_get_u32(mp4);

	if (mp4->box_size == 1) {
		/* extended box size */
		mp4->box_size = mp4_get_u64(mp4);
	}
	else if (mp4->box_size == 0) {
		/* box extends to end of file */
		mp4->box_size = ULONG_MAX;
	}

	memcpy(mp4->box_type, mp4->ptr, 4);
	mp4->ptr += 4;

	LOG_DEBUG(log_audio_codec, "box %.4s %d (%x)", mp4->box_type, mp4->box_size, mp4->box_size);

	mp4->box_size -= 8;

	/* find box parser */
	i=0;
	parser = &mp4_parsers[i++];
	while (parser->type) {
		if (FOURCC_EQ(mp4->box_type, parser->type)) {
			break;
		}
		parser = &mp4_parsers[i++];		
	}

	if (parser->type) {
		mp4->f = parser->f;
	}
	else {
		mp4->f = mp4_skip_box;
	}
}


static void mp4_parse_track_box(struct decode_mp4 *mp4, size_t r)
{
	mp4->track_idx = mp4->track_count++;

	mp4->track = realloc(mp4->track, sizeof(struct mp4_track) * mp4->track_count);
	memset(&mp4->track[mp4->track_idx], 0, sizeof(struct mp4_track));

	mp4_parse_container_box(mp4 , r);
}


static void mp4_parse_track_header_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];
	int version;

	if (r < 24) {
		return;
	}

	mp4_get_fullbox(mp4, &version, NULL);

	/* skip times */
	if (version == 1) {
		mp4->ptr += 16;
	}
	else {
		mp4->ptr += 8;
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
}


static void mp4_parse_sample_table_box(struct decode_mp4 *mp4, size_t r)
{
	int entries;

	if (r < 8) {
		mp4->box_size = 8;
		return;
	}

	/* skip version, flags */
	mp4->ptr += 4;
	entries = mp4_get_u32(mp4);

	mp4->f = &mp4_parse_container_box;
}


static void mp4_parse_sample_size_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (!track->sample_count) {
		if (r < 12) {
			return;
		}

		/* skip version, flags */
		mp4->ptr += 4;

		track->sample_size = mp4_get_u32(mp4);
		track->sample_count = mp4_get_u32(mp4);		

		track->sample_idx = 0;
		if (track->sample_size == 0) {
			track->sample_sizes = malloc(sizeof(int) * track->sample_count);
		}

		mp4->box_size -= 12;
	}

	if (track->sample_size == 0) {
		while (track->sample_idx < mp4->track->sample_count) {
			if ((mp4->end - mp4->ptr) < 4) {
				return;
			}

			track->sample_sizes[track->sample_idx++] = mp4_get_u32(mp4);
			mp4->box_size -= 4;
		}

		track->sample_idx = 0;

		/* skip rest of box */
		mp4->f = mp4_skip_box;
	}
}


static void mp4_parse_sample_size2_box(struct decode_mp4 *mp4, size_t r)
{
	LOG_ERROR(log_audio_codec, "need to implement stz2");
	exit(-1);
}


static void mp4_parse_mp4a_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	memcpy(track->data_format, mp4->box_type, sizeof(track->data_format));

	mp4->ptr += 6; // skip 6 bytes resered
	mp4->ptr += 2; // short unsigned index from 'dref' box
	mp4->ptr += 2; // QUICKTIME audio encoding version
	mp4->ptr += 2; // QUICKTIME audio encoding revision level
	mp4->ptr += 4; // QUICKTIME audio encoding vendor
	mp4->ptr += 2; // audio channels
	mp4->ptr += 2; // audio sample size
	mp4->ptr += 2; // QUICKTIME audio compression id
	mp4->ptr += 2; // QUICKTIME audio packet size
	mp4->ptr += 4; // sample rate

	mp4->f = mp4_parse_container_box;
}


static void mp4_parse_esds_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	// FIXME parse this correctly

#if 0
	{
		size_t i;
		for (i=35; i<mp4->box_size; i++) {
			printf("%02x %c ", mp4->ptr[i], isalnum(mp4->ptr[i])?mp4->ptr[i]:'.');
			if (i % 8 == 7) printf("\n");
		}
		printf("\n");
	}
#endif

	track->conf_size = 10;
	track->conf = malloc(track->conf_size);
	memcpy(track->conf, mp4->ptr+35, track->conf_size);

	mp4->f = mp4_skip_box;

#if 0
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


static void mp4_parse_mdat_box(struct decode_mp4 *mp4, size_t r)
{
	int i;

	if (r < 12) {
		mp4->box_size = 16;
		return;
	}

	/* skip any wide atom */
	if (strncmp((const char *)(mp4->ptr + 4), "wide", 4) == 0) {
		mp4->ptr += 8;

		/* skip extra mdat atom */
		if (strncmp((const char *)(mp4->ptr + 4), "mdat", 4) == 0) {
			mp4->ptr += 8;
		}
	}

	LOG_DEBUG(log_audio_codec, "tracks: %d", mp4->track_count);
	for (i=0; i<mp4->track_count; i++) {
		LOG_DEBUG(log_audio_codec, "%d:\t%d, %.4s", i, mp4->track[i].track_id, mp4->track[i].data_format);
	}


	{
		size_t i;
		for (i=0; i<20; i++) {
			printf("%02x %c ", mp4->ptr[i], isalnum(mp4->ptr[i])?mp4->ptr[i]:'.');
			if (i % 8 == 7) printf("\n");
		}
		printf("\n");
	}


	/* start streaming content */
	mp4->track_idx = 0;
	mp4->f = NULL;
}


static void mp4_parse_alac_box(struct decode_mp4 *mp4, size_t r)
{
	struct mp4_track *track = &mp4->track[mp4->track_idx];

	if (r < mp4->box_size) {
		return;
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
}


static void mp4_skip_box(struct decode_mp4 *mp4, size_t r)
{
	size_t n;

	n = MIN(mp4->box_size, r);
	mp4->box_size -= n;
	mp4->ptr += n;

	if (mp4->box_size == 0) {
		mp4->f = mp4_parse_container_box;
	}
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

		r = mp4_fill_buffer(mp4, NULL);
		if (r < 0) {
			return 0;
		}

		/* parse box */
		mp4->f(mp4, r);
	}

	/* headers parsed, found mdat */
	return 1;
}


static inline ssize_t next_packet_size(struct mp4_track *track)
{
	if (track->sample_size) {
		return track->sample_size;
	}

	if (track->sample_idx < track->sample_count) {
		return track->sample_sizes[track->sample_idx];
	}
	else {
		return 0;
	}
}


u8_t *mp4_read(struct decode_mp4 *mp4, size_t *len, bool_t *streaming)
{
	u8_t *buf;

	while (1) {
		ssize_t n, r;
		struct mp4_track *track = &mp4->track[mp4->track_idx];

		r = mp4_fill_buffer(mp4, streaming);
		if (r < 0) {
			*len = 0;
			return 0;
		}

		/* media data */
		n = next_packet_size(track);
		if (r < n) {
			mp4->box_size = n;
			continue;
		}

		track->sample_idx++;

		/* pointer and length of packet */
		// FIXME assert(mp4->ptr + n < mp4->end);
		buf = mp4->ptr;
		*len = n;

		/* advance buffer to next packet */
		mp4->box_size = next_packet_size(track);
		mp4->ptr += n;

		if (mp4->box_size == 0) {
			mp4->f = mp4_parse_container_box;
		}

		// FIXME
		// this assumes packets in multiple layers interleave
		if (mp4->track_count > 1) {
			mp4->track_idx = (mp4->track_idx + 1) & 1;
		}

		return buf;
	}
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

		if (track->sample_sizes) {
			free(track->sample_sizes);
			track->sample_sizes = NULL;
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
