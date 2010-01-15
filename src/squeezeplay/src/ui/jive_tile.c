/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"
#include "jive.h"


void jive_surface_get_tile_blit(JiveSurface *srf, SDL_Surface **sdl, Sint16 *x, Sint16 *y);


struct jive_tile {
	Uint32 refcount;

	SDL_Surface *srf[9];
	Uint16 w[2];
	Uint16 h[2];
	Uint32 bg;
	bool is_bg;
};


JiveTile *jive_tile_fill_color(Uint32 col) {
	JiveTile *tile;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	tile->is_bg = true;
	tile->bg = col;

	return tile;
}

JiveTile *jive_tile_load_image(const char *path) {
	JiveTile *tile;
	char *fullpath;
	SDL_Surface *tmp;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	fullpath = malloc(PATH_MAX);

	if (!squeezeplay_find_file(path, fullpath)) {
		LOG_ERROR(log_ui_draw, "Can't find image %s\n", path);
		free(fullpath);
		free(tile);
		return NULL;
	}

	tmp = IMG_Load(fullpath);
	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile: %s\n", IMG_GetError());
		free(fullpath);
		free(tile);
		return NULL;
	}
	else {
		if (tmp->format->Amask) {
			tile->srf[0] = SDL_DisplayFormatAlpha(tmp);
		}
		else {
			tile->srf[0] = SDL_DisplayFormat(tmp);
		}
		SDL_FreeSurface(tmp);
	}

	/* tile sizes */
	tile->w[0] = tile->srf[0]->w;
	tile->h[0] = tile->srf[0]->h;

	free(fullpath);

	return tile;
}


JiveTile *jive_tile_load_image_data(const char *data, size_t len) {
	JiveTile *tile;
	SDL_Surface *tmp;
	SDL_RWops *src ;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	src = SDL_RWFromConstMem(data, (int) len);
	tmp = IMG_Load_RW(src, 1);

	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile: %s\n", IMG_GetError());
		free(tile);
		return NULL;
	}
	else {
		if (tmp->format->Amask) {
			tile->srf[0] = SDL_DisplayFormatAlpha(tmp);
		}
		else {
			tile->srf[0] = SDL_DisplayFormat(tmp);
		}
		SDL_FreeSurface(tmp);
	}

	/* tile sizes */
	tile->w[0] = tile->srf[0]->w;
	tile->h[0] = tile->srf[0]->h;

	return tile;
}


JiveTile *jive_tile_load_tiles(char *path[9]) {
	JiveTile *tile;
	char *fullpath;
	SDL_Surface *tmp;
	int i;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	fullpath = malloc(PATH_MAX);

	for (i=0; i<9; i++) {
		if (!path[i]) {
			continue;
		}

		if (!squeezeplay_find_file(path[i], fullpath)) {
			LOG_ERROR(log_ui_draw, "Can't find image %s\n", path[i]);
			continue;
		}

		tmp = IMG_Load(fullpath);
		if (!tmp) {
			LOG_WARN(log_ui_draw, "Error loading tile: %s\n", IMG_GetError());
		}
		else {
			if (tmp->format->Amask) {
				tile->srf[i] = SDL_DisplayFormatAlpha(tmp);
			}
			else {
				tile->srf[i] = SDL_DisplayFormat(tmp);
			}
			SDL_FreeSurface(tmp);
		}
	}

	free(fullpath);


	/* tile sizes */
	tile->w[0] = tile->w[1] = 0;
	tile->h[0] = tile->h[1] = 0;

	/* top left */
	if (tile->srf[1]) {
		tile->w[0] = MAX(tile->srf[1]->w, tile->w[0]);
		tile->h[0] = MAX(tile->srf[1]->h, tile->h[0]);
	}

	/* top right */
	if (tile->srf[3]) {
		tile->w[1] = MAX(tile->srf[3]->w, tile->w[1]);
		tile->h[0] = MAX(tile->srf[3]->h, tile->h[0]);
	}

	/* bottom right */
	if (tile->srf[5]) {
		tile->w[1] = MAX(tile->srf[5]->w, tile->w[1]);
		tile->h[1] = MAX(tile->srf[5]->h, tile->h[1]);
	}

	/* bottom left */
	if (tile->srf[7]) {
		tile->w[0] = MAX(tile->srf[7]->w, tile->w[0]);
		tile->h[1] = MAX(tile->srf[7]->h, tile->h[1]);
	}

	/* top */
	if (tile->srf[2]) {
		tile->h[0] = MAX(tile->srf[2]->h, tile->h[0]);
	}

	/* right */
	if (tile->srf[4]) {
		tile->w[1] = MAX(tile->srf[4]->w, tile->w[1]);
	}

	/* bottom */
	if (tile->srf[6]) {
		tile->h[1] = MAX(tile->srf[6]->h, tile->h[1]);
	}

	/* left */
	if (tile->srf[8]) {
		tile->w[0] = MAX(tile->srf[8]->w, tile->w[0]);
	}

	return tile;
}

JiveTile *jive_tile_load_vtiles(char *path[3]) {
	char *path2[9];

	memset(path2, 0, sizeof(path2));
	path2[1] = path[0];
	path2[8] = path[1];
	path2[7] = path[2];

	return jive_tile_load_tiles(path2);
}


JiveTile *jive_tile_load_htiles(char *path[3]) {
	char *path2[9];

	memset(path2, 0, sizeof(path2));
	path2[1] = path[0];
	path2[2] = path[1];
	path2[3] = path[2];

	return jive_tile_load_tiles(path2);
}

JiveTile *jive_tile_ref(JiveTile *tile) {
	if (tile) {
		tile->refcount++;
	}
	return tile;
}

void jive_tile_get_min_size(JiveTile *tile, Uint16 *w, Uint16 *h) {
	if (w) {
		*w = tile->w[0] + tile->w[1];
	}
	if (h) {
		*h = tile->h[0] + tile->h[1];
	}
}

void jive_tile_set_alpha(JiveTile *tile, Uint32 flags) {
	int i;

	for (i=0; i<9; i++) {
		if (tile->srf[i]) {
			SDL_SetAlpha(tile->srf[i], flags, 0);
		}
	}
}

void jive_tile_free(JiveTile *tile) {
	int i;

	if (--tile->refcount > 0) {
		return;
	}

	for (i=0; i<9; i++) {
		if (tile->srf[i]) {
			SDL_FreeSurface(tile->srf[i]);
			tile->srf[i] = NULL;
		}
	}

	free(tile);
}

static __inline__ void blit_area(SDL_Surface *src, SDL_Surface *dst, int dx, int dy, int dw, int dh) {
	SDL_Rect sr, dr;
	int x, y, w, h;
	int tw, th;

	tw = src->w;
	th = src->h;

	sr.x = 0;
	sr.y = 0;

	h = dh;
	y = dy;
	while (h > 0) {
		w = dw;
		x = dx;
		while (w > 0) {
			sr.w = w;
			sr.h = h;
			dr.x = x;
			dr.y = y;

			SDL_BlitSurface(src, &sr, dst, &dr);

			x += tw;
			w -= tw;
		}

		y += th;
		h -= th;
	}
}


static void _blit_tile(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
	int ox=0, oy=0, ow=0, oh=0;
	Sint16 dst_offset_x, dst_offset_y;
	SDL_Surface *dst_srf;

	if (tile->is_bg) {
		jive_surface_boxColor(dst, dx, dy, dx + dw - 1, dy + dh - 1, tile->bg);
		return;
	}

	jive_surface_get_tile_blit(dst, &dst_srf, &dst_offset_x, &dst_offset_y);

	dx += dst_offset_x;
	dy += dst_offset_y;

	/* top left */
	if (tile->srf[1]) {
		ox = MIN(tile->w[0], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(tile->srf[1], dst_srf, dx, dy, ox, oy);
	}

	/* top right */
	if (tile->srf[3]) {
		ow = MIN(tile->w[1], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(tile->srf[3], dst_srf, dx + dw - ow, dy, ow, oy);
	}

	/* bottom right */
	if (tile->srf[5]) {
		ow = MIN(tile->w[1], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(tile->srf[5], dst_srf, dx + dw - ow, dy + dh - oh, ow, oh);
	}

	/* bottom left */
	if (tile->srf[7]) {
		ox = MIN(tile->w[0], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(tile->srf[7], dst_srf, dx, dy + dh - oh, ox, oh);
	}

	/* top */
	if (tile->srf[2]) {
		oy = MIN(tile->h[0], dh);
		blit_area(tile->srf[2], dst_srf, dx + ox, dy, dw - ox - ow, oy);
	}

	/* right */
	if (tile->srf[4]) {
		ow = MIN(tile->w[1], dw);
		blit_area(tile->srf[4], dst_srf, dx + dw - ow, dy + oy, ow, dh - oy - oh);
	}

	/* bottom */
	if (tile->srf[6]) {
		oh = MIN(tile->h[1], dh);
		blit_area(tile->srf[6], dst_srf, dx + ox, dy + dh - oh, dw - ox - ow, oh);
	}

	/* left */
	if (tile->srf[8]) {
		ox = MIN(tile->w[0], dw);
		blit_area(tile->srf[8], dst_srf, dx, dy + oy, ox, dh - oy - oh);
	}

	/* center */
	if (tile->srf[0]) {
		blit_area(tile->srf[0], dst_srf, dx + ox, dy + oy, dw - ox - ow, dh - oy - oh);
	}
}


void jive_tile_blit(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT
	Uint16 mw, mh;

	if (!dw || !dh) {
		jive_tile_get_min_size(tile, &mw, &mh);
		if (!dw) {
			dw = mw;
		}
		if (!dh) {
			dh = mh;
		}
	}

	_blit_tile(tile, dst, dx, dy, dw, dh);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_tile_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_tile_blit_centered(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT
	Uint16 mw, mh;

	jive_tile_get_min_size(tile, &mw, &mh);
	if (dw < mw) {
		dw = mw;
	}
	if (dh < mh) {
		dh = mh;
	}

	_blit_tile(tile, dst, dx - (dw/2), dy -  (dh/2), dw, dh);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_tile_blit_centered took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}
