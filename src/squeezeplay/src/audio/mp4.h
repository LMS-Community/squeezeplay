/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"


struct decode_mp4;

typedef void (*mp4_read_box_t)(struct decode_mp4 *mp4, size_t r);

struct mp4_track {
	int track_id;
	char data_format[4];

	/* number samples */
	int sample_count;

	/* sample size (fixed or variable) */
	int sample_size;
	int *sample_sizes;

	/* sample counter */
	int sample_idx;

	/* aac configuration */
	u8_t *conf;
	int conf_size;
};

struct decode_mp4 {
	/* parser state */
	u8_t *buf, *ptr, *end;

	mp4_read_box_t f;

	size_t box_size;
	char box_type[4];

	/* tracks */
	int track_count;
	int track_idx;
	struct mp4_track *track;

};


void mp4_init(struct decode_mp4 *mp4);
size_t mp4_open(struct decode_mp4 *mp4);
u8_t *mp4_read(struct decode_mp4 *mp4, size_t *len, bool_t *streaming);
void mp4_free(struct decode_mp4 *mp4);
