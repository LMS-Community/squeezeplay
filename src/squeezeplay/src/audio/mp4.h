/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"


struct decode_mp4;

typedef int (*mp4_read_box_t)(struct decode_mp4 *mp4, size_t r);

struct decode_mp4 {
	/* parser state */
	u8_t *buf, *ptr, *end;
	size_t off;

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
u8_t *mp4_read(struct decode_mp4 *mp4, int track, size_t *len, bool_t *streaming);
void mp4_track_conf(struct decode_mp4 *mp4, int track, u8_t **conf, size_t *size);
void mp4_free(struct decode_mp4 *mp4);
int mp4_track_is_type(struct decode_mp4 *mp4, int track, const char *type);

