/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"
#include "jive.h"


void jive_surface_get_tile_blit(JiveSurface *srf, SDL_Surface **sdl, Sint16 *x, Sint16 *y);

struct loaded_image_surface {
	Uint16 image;								/* index to underlying struct image */
	SDL_Surface *srf;
	struct loaded_image_surface *prev, *next;	/* LRU cache double-linked list */
};

/* locked images (no path) are not counted or kept in the LRU list */
#define MAX_LOADED_IMAGES 75
static struct loaded_image_surface lruHead, lruTail;
static Uint16 nloadedImages;

struct image {
	const char * path;
	Uint16 w;
	Uint16 h;
	Uint16 flags;
#   define IMAGE_FLAG_INIT  (1<<0)			/* Have w & h been evaluated yet */
#   define IMAGE_FLAG_AMASK (1<<1)
	Uint16 ref_count;
#ifdef JIVE_PROFILE_IMAGE_CACHE
	Uint16 use_count;
	Uint16 load_count;
#endif
	struct loaded_image_surface * loaded;	/* reference to loaded surface */
};

/* We do not use image 0 - it is just easier to let 0 mean no image */
#define MAX_IMAGES 500
static struct image images[MAX_IMAGES];
static Uint16 n_images = 1;

struct jive_tile {
	/* the first two fields must match struct jive_surface */
	Uint32 refcount;
	bool is_tile;

	Uint16 image[9];
	Uint16 w[2];
	Uint16 h[2];
	Uint32 bg;
	Uint32 alpha_flags;
	Uint16 flags;
#   define TILE_FLAG_INIT  (1<<0)		/* Have w & h been evaluated yet */
#   define TILE_FLAG_BG    (1<<1)
#   define TILE_FLAG_ALPHA (1<<2)		/* have alpha flags been set of this tile */
#   define TILE_FLAG_LOCK  (1<<3)		/* loaded from data, cannot be loaded on demand */
#   define TILE_FLAG_IMAGE (1<<4)		/* just a single image */
};

static Uint16 _new_image_with_surface (SDL_Surface *srf) {
	Uint16 i;

	if (n_images >= MAX_IMAGES) {
		LOG_ERROR(log_ui_draw, "Maximum number of images (%d) exceeded for data image\n", MAX_IMAGES);
		return 0;
	}

	i = n_images++;
	images[i].ref_count = 1;
	images[i].w = srf->w;
	images[i].h = srf->h;

	images[i].loaded = calloc(sizeof *images[i].loaded, 1);
	images[i].loaded->image = i;
	images[i].loaded->srf = srf;

	images[i].flags = IMAGE_FLAG_INIT;

	return i;
}

static int _new_image(const char *path) {
	Uint16 i;

	for (i = 0; i < n_images; i++) {
		if (images[i].ref_count <= 0)
			break;
		if (images[i].path && strcmp(path, images[i].path) == 0) {
			images[i].ref_count++;
			return i;
		}
	}

	if (i >= MAX_IMAGES) {
		LOG_ERROR(log_ui_draw, "Maximum number of images (%d) exceeded for %s\n", MAX_IMAGES, path);
		return 0;
	}

	if (i == n_images)
		n_images++;
	images[i].path = strdup(path);
	images[i].ref_count = 1;
	return i;
}

static void _unload_image(Uint16 index) {
	struct loaded_image_surface *loaded = images[index].loaded;

	if (loaded->next) {
		nloadedImages--;	/* only counted if actually in LRU list */
		loaded->prev->next = loaded->next;
		loaded->next->prev = loaded->prev;
	}

#ifdef JIVE_PROFILE_IMAGE_CACHE
	LOG_DEBUG(log_ui_draw, "Unloading  %3d:%s", index, images[index].path);
#endif

	SDL_FreeSurface(loaded->srf);
	free(loaded);
	images[index].loaded = 0;
}

static void _use_image(Uint16 index) {
	struct loaded_image_surface *loaded = images[index].loaded;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	images[index].use_count++;
#endif

	/* short-circuit if already at head */
	if (loaded->prev == &lruHead)
		return;

	/* ignore locked images */
	if (images[index].path == 0)
		return;

	/* init head and tail if needed */
	if (lruHead.next == 0) {
		lruHead.next = &lruTail;
		lruTail.prev = &lruHead;
	}

	/* If already in the list then just move to head */
	if (loaded->next) {

		/* cut out */
		loaded->prev->next = loaded->next;
		loaded->next->prev = loaded->prev;

		/* insert at head */
		loaded->next = lruHead.next;
		loaded->next->prev = loaded;
		loaded->prev = &lruHead;
		lruHead.next = loaded;
	}

	/* otherwise, insert at head and eject oldest if necessary */
	else {
		/* insert at head */
		loaded->next = lruHead.next;
		loaded->next->prev = loaded;
		loaded->prev = &lruHead;
		lruHead.next = loaded;

		if (++nloadedImages > MAX_LOADED_IMAGES) {
			_unload_image(lruTail.prev->image);
		}
	}
}

static void _load_image (Uint16 index, bool hasAlphaFlags, Uint32 alphaFlags) {
	struct image *image = &images[index];
	SDL_Surface *tmp, *srf;

	tmp = IMG_Load(image->path);
	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile image %s: %s\n", image->path, IMG_GetError());
		return;
	}
	if (tmp->format->Amask) {
		srf = SDL_DisplayFormatAlpha(tmp);
		image->flags |= IMAGE_FLAG_AMASK;
	} else {
		srf = SDL_DisplayFormat(tmp);
	}
	SDL_FreeSurface(tmp);

	if (!srf)
		return;

	if (hasAlphaFlags) {
		SDL_SetAlpha(srf, alphaFlags, 0);
	}

	image->loaded = calloc(sizeof *(image->loaded), 1);
	image->loaded->image = index;
	image->loaded->srf = srf;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	image->load_count++;
#endif

	if (!(image->flags & IMAGE_FLAG_INIT)) {
		image->w = srf->w;
		image->h = srf->h;
		image->flags |= IMAGE_FLAG_INIT;
	}

	_use_image(index);

#ifdef JIVE_PROFILE_IMAGE_CACHE
	LOG_DEBUG(log_ui_draw, "Loaded image %3d:%s", index, image->path);
#endif
}

static void _load_tile_images (JiveTile *tile) {
	int i, max;

#ifdef JIVE_PROFILE_IMAGE_CACHE
	int n = 0, m = 0;
#endif

	/* shortcut for images */
	max =  (tile->flags & TILE_FLAG_IMAGE) ? 1 : 9;

	/* make two passes to avoid the unload/load shuttle problem */
	for (i = 0; i < max; i++) {
		Uint16 image = tile->image[i];

		if (!image)
			continue;

		if (images[image].loaded)
			_use_image(image);
	}

	for (i = 0; i < max; i++) {
		Uint16 image = tile->image[i];

		if (!image)
			continue;

		if (!images[image].loaded) {

#ifdef JIVE_PROFILE_IMAGE_CACHE
			if (images[image].flags & IMAGE_FLAG_INIT)
				m++;
			n++;
#endif

			_load_image(image, tile->flags & TILE_FLAG_ALPHA, tile->alpha_flags);
		}
	}

#ifdef JIVE_PROFILE_IMAGE_CACHE
	if (n) {
		int loaded = 0;
		for (i = 0; i < n_images; i++) {
			if (images[i].loaded)
				loaded++;
		}
		LOG_DEBUG(log_ui_draw, "Loaded %d new images, %d already inited; %d of %d now loaded", n, m, loaded, n_images);
	}
#endif

}

static void _init_image_sizes(struct image *image) {
	if (image->loaded) {
		image->w = image->loaded->srf->w;
		image->h = image->loaded->srf->h;
	} else {
		SDL_Surface *tmp;

#ifdef JIVE_PROFILE_IMAGE_CACHE
		 LOG_DEBUG(log_ui_draw, "Loading image just for sizes: %s", image->path);
#endif

		tmp = IMG_Load(image->path);
		if (!tmp) {
			LOG_WARN(log_ui_draw, "Error loading tile image %s: %s\n", image->path, IMG_GetError());
			image->flags |= IMAGE_FLAG_INIT;	/* fake it - no point in trying repeatedly */
			return;
		}
		if (tmp->format->Amask)
			image->flags |= IMAGE_FLAG_AMASK;

		image->w = tmp->w;
		image->h = tmp->h;

		SDL_FreeSurface(tmp);
	}
	image->flags |= IMAGE_FLAG_INIT;
}

static Uint16 _get_image_w(struct image *image) {
	if (!(image->flags & IMAGE_FLAG_INIT))
		_init_image_sizes(image);
	return image->w;
}

static Uint16 _get_image_h(struct image *image) {
	if (!(image->flags & IMAGE_FLAG_INIT))
		_init_image_sizes(image);
	return image->h;
}

static void _init_tile_sizes(JiveTile *tile) {
	if (tile->flags & TILE_FLAG_INIT)
		return;

	/* top left */
	if (tile->image[1]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[1]]), tile->w[0]);
		tile->h[0] = MAX(_get_image_h(&images[tile->image[1]]), tile->h[0]);
	}

	/* top right */
	if (tile->image[3]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[3]]), tile->w[1]);
		tile->h[0] = MAX(_get_image_h(&images[tile->image[3]]), tile->h[0]);
	}

	/* bottom right */
	if (tile->image[5]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[5]]), tile->w[1]);
		tile->h[1] = MAX(_get_image_h(&images[tile->image[5]]), tile->h[1]);
	}

	/* bottom left */
	if (tile->image[7]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[7]]), tile->w[0]);
		tile->h[1] = MAX(_get_image_h(&images[tile->image[7]]), tile->h[1]);
	}

	/* top */
	if (tile->image[2]) {
		tile->h[0] = MAX(_get_image_h(&images[tile->image[2]]), tile->h[0]);
	}

	/* right */
	if (tile->image[4]) {
		tile->w[1] = MAX(_get_image_w(&images[tile->image[4]]), tile->w[1]);
	}

	/* bottom */
	if (tile->image[6]) {
		tile->h[1] = MAX(_get_image_h(&images[tile->image[6]]), tile->h[1]);
	}

	/* left */
	if (tile->image[8]) {
		tile->w[0] = MAX(_get_image_w(&images[tile->image[8]]), tile->w[0]);
	}

	/* special for single images */
	if (tile->image[0] && !tile->image[1] && !tile->w[0]) {
		tile->w[0] = _get_image_w(&images[tile->image[0]]);
		tile->h[0] = _get_image_h(&images[tile->image[0]]);
	}

	tile->flags |= TILE_FLAG_INIT;
}

static void _get_tile_surfaces(JiveTile *tile, SDL_Surface *srf[9], bool load) {
	int i;

	if (load)
		_load_tile_images(tile);

	for (i = 0; i < 9; i++) {
		if (tile->image[i] && images[tile->image[i]].loaded) {
			srf[i] = images[tile->image[i]].loaded->srf;
		} else {
			srf[i] = 0;
		}
	}
}

SDL_Surface *jive_tile_get_image_surface(JiveTile *tile) {
	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return NULL;
	}

	_load_tile_images(tile);
	if (!images[tile->image[0]].loaded)
		return NULL;

	return images[tile->image[0]].loaded->srf;
}

JiveTile *jive_tile_fill_color(Uint32 col) {
	JiveTile *tile;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;

	tile->flags = TILE_FLAG_INIT | TILE_FLAG_BG;
	tile->bg = col;
	tile->is_tile = true;

	return tile;
}

JiveTile *jive_tile_load_image(const char *path) {
	char *paths[9];
	JiveTile *tile;

	memset(paths, 0, sizeof paths);
	paths[0] = (char *)path;

	tile = jive_tile_load_tiles(paths);
	tile->flags |= TILE_FLAG_IMAGE;

	return tile;
}


JiveTile *jive_tile_load_image_data(const char *data, size_t len) {
	JiveTile *tile;
	SDL_Surface *tmp, *srf;
	SDL_RWops *src;
	Uint16 image;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;
	tile->is_tile = true;

	src = SDL_RWFromConstMem(data, (int) len);
	tmp = IMG_Load_RW(src, 1);

	if (!tmp) {
		LOG_WARN(log_ui_draw, "Error loading tile: %s\n", IMG_GetError());
		free(tile);
		return NULL;
	}
	else {
		if (tmp->format->Amask) {
			srf = SDL_DisplayFormatAlpha(tmp);
		}
		else {
			srf = SDL_DisplayFormat(tmp);
		}
		SDL_FreeSurface(tmp);
	}

	/* tile sizes */
	tile->w[0] = srf->w;
	tile->h[0] = srf->h;

	image = _new_image_with_surface(srf);
	if (!image) {
		tile->image[0] = image;
		SDL_FreeSurface(srf);
		free(tile);
		LOG_WARN(log_ui_draw, "Error loading tile");
		return NULL;
	}

	tile->image[0] = image;
	tile->flags = TILE_FLAG_INIT | TILE_FLAG_LOCK | TILE_FLAG_IMAGE;
;

	return tile;
}

JiveTile *jive_tile_load_tiles(char *path[9]) {
	JiveTile *tile;
	char *fullpath;
	int i;

	tile = calloc(sizeof(JiveTile), 1);
	tile->refcount = 1;
	tile->is_tile = true;

	fullpath = malloc(PATH_MAX);

	for (i=0; i<9; i++) {
		if (!path[i]) {
			continue;
		}

		if (!squeezeplay_find_file(path[i], fullpath)) {
			LOG_ERROR(log_ui_draw, "Can't find image %s\n", path[i]);
			continue;
		}

		tile->image[i] = _new_image(fullpath);
	}

	free(fullpath);

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
		if (!tile->is_tile)
			LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
			// we can continue here as refcount is in the same place for JiveTile and JiveSurface

		tile->refcount++;
	}
	return tile;
}

void jive_tile_get_min_size(JiveTile *tile, Uint16 *w, Uint16 *h) {

	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return;
	}

	_init_tile_sizes(tile);

	if (w) {
		*w = tile->w[0] + tile->w[1];
	}
	if (h) {
		*h = tile->h[0] + tile->h[1];
	}
}

void jive_tile_set_alpha(JiveTile *tile, Uint32 flags) {
	SDL_Surface *srf[9];
	int i;

	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return;
	}

	tile->alpha_flags = flags;
	tile->flags |= TILE_FLAG_ALPHA;

	_get_tile_surfaces(tile, srf, false);
	for (i=0; i<9; i++) {
		if (srf[i]) {
			SDL_SetAlpha(srf[i], flags, 0);
		}
	}
}

void jive_tile_free(JiveTile *tile) {
	int i;

	if (--tile->refcount > 0) {
		return;
	}

	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return;
	}

	for (i=0; i<9; i++) {
		struct image *image;

		if (!tile->image[i])
			continue;

		image = &images[tile->image[i]];
		if (--image->ref_count > 0)
			continue;

		if (image->loaded) {
			_unload_image(tile->image[i]);
		}
		memset(image, 0, sizeof *image);
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
	SDL_Surface *srf[9];

	if (tile->flags & TILE_FLAG_BG) {
		jive_surface_boxColor(dst, dx, dy, dx + dw - 1, dy + dh - 1, tile->bg);
		return;
	}

	_get_tile_surfaces(tile, srf, true);
	_init_tile_sizes(tile);

	jive_surface_get_tile_blit(dst, &dst_srf, &dst_offset_x, &dst_offset_y);

	dx += dst_offset_x;
	dy += dst_offset_y;

	/* top left */
	if (srf[1]) {
		ox = MIN(tile->w[0], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(srf[1], dst_srf, dx, dy, ox, oy);
	}

	/* top right */
	if (srf[3]) {
		ow = MIN(tile->w[1], dw);
		oy = MIN(tile->h[0], dh);
		blit_area(srf[3], dst_srf, dx + dw - ow, dy, ow, oy);
	}

	/* bottom right */
	if (srf[5]) {
		ow = MIN(tile->w[1], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(srf[5], dst_srf, dx + dw - ow, dy + dh - oh, ow, oh);
	}

	/* bottom left */
	if (srf[7]) {
		ox = MIN(tile->w[0], dw);
		oh = MIN(tile->h[1], dh);
		blit_area(srf[7], dst_srf, dx, dy + dh - oh, ox, oh);
	}

	/* top */
	if (srf[2]) {
		oy = MIN(tile->h[0], dh);
		blit_area(srf[2], dst_srf, dx + ox, dy, dw - ox - ow, oy);
	}

	/* right */
	if (srf[4]) {
		ow = MIN(tile->w[1], dw);
		blit_area(srf[4], dst_srf, dx + dw - ow, dy + oy, ow, dh - oy - oh);
	}

	/* bottom */
	if (srf[6]) {
		oh = MIN(tile->h[1], dh);
		blit_area(srf[6], dst_srf, dx + ox, dy + dh - oh, dw - ox - ow, oh);
	}

	/* left */
	if (srf[8]) {
		ox = MIN(tile->w[0], dw);
		blit_area(srf[8], dst_srf, dx, dy + oy, ox, dh - oy - oh);
	}

	/* center */
	if (srf[0]) {
		blit_area(srf[0], dst_srf, dx + ox, dy + oy, dw - ox - ow, dh - oy - oh);
	}
}


void jive_tile_blit(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT
	Uint16 mw, mh;

	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return;
	}

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

	if (!tile->is_tile) {
		LOG_ERROR(log_ui_draw, "jive_tile_*() called with JiveSurface");
		return;
	}

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
