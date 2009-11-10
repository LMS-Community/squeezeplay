/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


#ifdef SCREEN_ROTATION_ENABLED
static SDL_Surface *real_sdl = NULL;
#endif


JiveSurface *jive_surface_set_video_mode(Uint16 w, Uint16 h, Uint16 bpp, bool fullscreen) {
	JiveSurface *srf;
	SDL_Surface *sdl;
	Uint32 flags;

#ifdef SCREEN_ROTATION_ENABLED
	{
		Uint16 tmp;
	  
		tmp = w;
		w = h;
		h = tmp;
	}
#endif

	if (fullscreen) {
	    flags = SDL_FULLSCREEN;
	}
	else {
	    flags = SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE;
	}

	sdl = SDL_GetVideoSurface();

	if (sdl) {
		const SDL_VideoInfo *video_info;
		Uint32 mask;

		/* check if we can reuse the existing suface? */
		video_info = SDL_GetVideoInfo();
		if (video_info->wm_available) {
			mask = (SDL_FULLSCREEN | SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE);
		}
		else {
			mask = (SDL_HWSURFACE | SDL_DOUBLEBUF);
		}

		if ((sdl->w != w) || (sdl->h != h)
		    || (bpp && sdl->format->BitsPerPixel != bpp)
		    || ((sdl->flags & mask) != (flags & mask))) {
			sdl = NULL;
		}
	}

	if (!sdl) {
		/* create new surface */
		sdl = SDL_SetVideoMode(w, h, bpp, flags);
		if (!sdl) {
			LOG_ERROR(log_ui_draw, "SDL_SetVideoMode(%d,%d,%d): %s",
				  w, h, bpp, SDL_GetError());
			return NULL;
		}

		if ( (sdl->flags & SDL_HWSURFACE) && (sdl->flags & SDL_DOUBLEBUF)) {
			LOG_INFO(log_ui_draw, "Using a hardware double buffer");
		}

		LOG_DEBUG(log_ui_draw, "Video mode: %d bits/pixel %d bytes/pixel [R<<%d G<<%d B<<%d]", sdl->format->BitsPerPixel, sdl->format->BytesPerPixel, sdl->format->Rshift, sdl->format->Gshift, sdl->format->Bshift);

#ifdef SCREEN_ROTATION_ENABLED
		/* orientaion hack */
		real_sdl = sdl;
		bpp = sdl->format->BitsPerPixel;
		sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, h, w, bpp, 0, 0, 0, 0);
		SDL_SetAlpha(sdl, SDL_SRCALPHA, SDL_ALPHA_OPAQUE);
#endif
	}

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}

JiveSurface *jive_surface_newRGB(Uint16 w, Uint16 h) {
	JiveSurface *srf;
	SDL_Surface *screen, *sdl;
	int bpp;

	screen = SDL_GetVideoSurface();
	bpp = screen->format->BitsPerPixel;

	sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, bpp, 0, 0, 0, 0);

	/* Opaque surface */
	SDL_SetAlpha(sdl, SDL_SRCALPHA, SDL_ALPHA_OPAQUE);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}


JiveSurface *jive_surface_newRGBA(Uint16 w, Uint16 h) {
	JiveSurface *srf;
	SDL_Surface *sdl;

	/*
	 * Work out the optimium pixel masks for the display with
	 * 32 bit alpha surfaces. If we get this wrong a non-optimised
	 * blitter will be used.
	 */
	const SDL_VideoInfo *video_info = SDL_GetVideoInfo();
	if (video_info->vfmt->Rmask < video_info->vfmt->Bmask) {
		sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32,
					   0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000);
	}
	else {
		sdl = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32,
					   0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);
	}

	/* alpha channel, paint transparency */
	SDL_SetAlpha(sdl, SDL_SRCALPHA, SDL_ALPHA_OPAQUE);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return srf;
}


JiveSurface *jive_surface_new_SDLSurface(SDL_Surface *sdl_surface) {
	JiveSurface *srf;

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl_surface;

	return srf;
}


JiveSurface *jive_surface_ref(JiveSurface *srf) {
	if (srf) {
		srf->refcount++;
	}
	return srf;
}


/*
 * Convert image to best format for display on the screen
 */
static JiveSurface *jive_surface_display_format(JiveSurface *srf) {
	SDL_Surface *sdl;

	if (srf->sdl == NULL || SDL_GetVideoSurface() == NULL) {
		return srf;
	}

	if (srf->sdl->format->Amask) {
		sdl = SDL_DisplayFormatAlpha(srf->sdl);
	}
	else {
		sdl = SDL_DisplayFormat(srf->sdl);
	}
	SDL_FreeSurface(srf->sdl);
	srf->sdl = sdl;

	return srf;
}


JiveSurface *jive_surface_load_image(const char *path) {
	char *fullpath;
	JiveSurface *srf;
	SDL_Surface *sdl;

	if (!path) {
		return NULL;
	}

	fullpath = malloc(PATH_MAX);
	if (!squeezeplay_find_file(path, fullpath)) {
		LOG_ERROR(log_ui_draw, "Can't find image %s\n", path);
		free(fullpath);
		return NULL;
	}

	sdl = IMG_Load(fullpath);
	if (!sdl) {
		LOG_WARN(log_ui_draw, "Error loading surface: %s\n", IMG_GetError());
	}

	free(fullpath);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return jive_surface_display_format(srf);
}


JiveSurface *jive_surface_load_image_data(const char *data, size_t len) {
	SDL_RWops *src = SDL_RWFromConstMem(data, (int) len);
	SDL_Surface *sdl = IMG_Load_RW(src, 1);

	JiveSurface *srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	srf->sdl = sdl;

	return jive_surface_display_format(srf);
}


int jive_surface_set_wm_icon(JiveSurface *srf) {
	SDL_WM_SetIcon(srf->sdl, NULL);
	return 1;
}


int jive_surface_save_bmp(JiveSurface *srf, const char *file) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return 0;
	}
	return SDL_SaveBMP(srf->sdl, file);
}


static int _getPixel(SDL_Surface *s, Uint16 x, Uint16 y) {
	Uint8 R, G, B;

	switch (s->format->BytesPerPixel) {
	case 1: { /* 8-bpp */
		Uint8 *p;
		p = (Uint8 *)s->pixels + y*s->pitch + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}

	case 2: { /* 15-bpp or 16-bpp */
		Uint16 *p;
		p = (Uint16 *)s->pixels + y*s->pitch/2 + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}

	case 3: { /* 24-bpp */
		/* FIXME */
		assert(0);
	}

	case 4: { /* 32-bpp */
		Uint32 *p;
		p = (Uint32 *)s->pixels + y*s->pitch/4 + x;

		SDL_GetRGB(*p, s->format, &R, &G, &B);
		return (R << 16) | (G << 8) | B;
	}
	}

	return 0;
}


int jive_surface_cmp(JiveSurface *a, JiveSurface *b, Uint32 key) {
	SDL_Surface *sa = a->sdl;
	SDL_Surface *sb = b->sdl;
	Uint32 pa, pb;
	int x, y;
	int count=0, equal=0;

	if (!sa || !sb) {
		return 0;
	}

	if (sa->w != sb->w || sa->h != sb->h) {
		return 0;
	}

	if (SDL_MUSTLOCK(sa)) {
		SDL_LockSurface(sa);
	}
	if (SDL_MUSTLOCK(sb)) {
		SDL_LockSurface(sb);
	}
	
	for (x=0; x<sa->w; x++) {
		for (y=0; y<sa->h; y++) {
			pa = _getPixel(sa, x, y);
			pb = _getPixel(sb, x ,y);
			
			count++;
			if (pa == pb || pa == key || pb == key) {
				equal++;
			}
		}
	}

	if (SDL_MUSTLOCK(sb)) {
		SDL_UnlockSurface(sb);
	}
	if (SDL_MUSTLOCK(sa)) {
		SDL_UnlockSurface(sa);
	}

	return (int)(((float)equal / count) * 100);
}

void jive_surface_get_offset(JiveSurface *srf, Sint16 *x, Sint16 *y) {
	*x = srf->offset_x;
	*y = srf->offset_y;
}

void jive_surface_set_offset(JiveSurface *srf, Sint16 x, Sint16 y) {
	srf->offset_x = x;
	srf->offset_y = y;
}

void jive_surface_get_clip(JiveSurface *srf, SDL_Rect *r) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	SDL_GetClipRect(srf->sdl, r);

	r->x -= srf->offset_x;
	r->y -= srf->offset_y;
}

void jive_surface_set_clip(JiveSurface *srf, SDL_Rect *r) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}

	if (r) {
		tmp.x = r->x + srf->offset_x;
		tmp.y = r->y + srf->offset_y;
		tmp.w = r->w;
		tmp.h = r->h;
	}
	else {
		tmp.x = 0;
		tmp.y = 0;
		tmp.w = srf->sdl->w;
		tmp.h = srf->sdl->h;
	}

	SDL_SetClipRect(srf->sdl, &tmp);
}


void jive_surface_push_clip(JiveSurface *srf, SDL_Rect *r, SDL_Rect *pop)
{
	SDL_Rect tmp;

	jive_surface_get_clip(srf, pop);
	jive_rect_intersection(r, pop, &tmp);
	jive_surface_set_clip(srf, &tmp);
}


void jive_surface_set_clip_arg(JiveSurface *srf, Uint16 x, Uint16 y, Uint16 w, Uint16 h) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}

	tmp.x = x + srf->offset_x;
	tmp.y = y + srf->offset_y;
	tmp.w = w;
	tmp.h = h;

	SDL_SetClipRect(srf->sdl, &tmp);
}

void jive_surface_get_clip_arg(JiveSurface *srf, Uint16 *x, Uint16 *y, Uint16 *w, Uint16 *h) {
	SDL_Rect tmp;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		*x = 0;
		*y = 0;
		*w = 0;
		*h = 0;
		return;
	}

	SDL_GetClipRect(srf->sdl, &tmp);

	*x = tmp.x - srf->offset_x;
	*y = tmp.y - srf->offset_y;
	*w = tmp.w;
	*h = tmp.h;
}

void jive_surface_flip(JiveSurface *srf) {
#ifdef SCREEN_ROTATION_ENABLED
	int x, y;

	/* orientation hack */
	SDL_LockSurface(real_sdl);
	SDL_LockSurface(srf->sdl);

	switch (real_sdl->format->BytesPerPixel) {
	case 2: {
		Uint16 *srcp, *dstp;

		for (y=0; y<srf->sdl->h; y++) {
			srcp = ((Uint16 *)srf->sdl->pixels) + (y * srf->sdl->pitch/2);
			dstp = ((Uint16 *)real_sdl->pixels) + y + ((real_sdl->h - 1) * real_sdl->pitch/2);

			for (x=0; x<srf->sdl->w; x++) {
				*dstp = *srcp;
				srcp++;
				dstp -= real_sdl->pitch/2;
			}
		}
		break;
	}

	case 4: {
		Uint32 *srcp, *dstp;

		for (y=0; y<srf->sdl->h; y++) {
			srcp = ((Uint32 *)srf->sdl->pixels) + (y * srf->sdl->pitch/4);
			dstp = ((Uint32 *)real_sdl->pixels) + y + ((real_sdl->h - 1) * real_sdl->pitch/4);

			for (x=0; x<srf->sdl->w; x++) {
				*dstp = *srcp;
				srcp++;
				dstp -= real_sdl->pitch/4;
			}
		}
		break;
	}
	}

	SDL_UnlockSurface(srf->sdl);
	SDL_UnlockSurface(real_sdl);

	SDL_Flip(real_sdl);
#else
	SDL_Flip(srf->sdl);
#endif

}


/* this function must only be used for blitting tiles */
void jive_surface_get_tile_blit(JiveSurface *srf, SDL_Surface **sdl, Sint16 *x, Sint16 *y) {
	*sdl = srf->sdl;
	*x = srf->offset_x;
	*y = srf->offset_y;
}


void jive_surface_blit(JiveSurface *src, JiveSurface *dst, Uint16 dx, Uint16 dy) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect dr;
	dr.x = dx + dst->offset_x;
	dr.y = dy + dst->offset_y;

	SDL_BlitSurface(src->sdl, 0, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_blit_clip(JiveSurface *src, Uint16 sx, Uint16 sy, Uint16 sw, Uint16 sh,
			  JiveSurface* dst, Uint16 dx, Uint16 dy) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect sr, dr;
	sr.x = sx; sr.y = sy; sr.w = sw; sr.h = sh;
	dr.x = dx + dst->offset_x; dr.y = dy + dst->offset_y;

	SDL_BlitSurface(src->sdl, &sr, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_blit_alpha(JiveSurface *src, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint8 alpha) {
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = jive_jiffies(), t1;
#endif //JIVE_PROFILE_BLIT

	SDL_Rect dr;
	dr.x = dx + dst->offset_x;
	dr.y = dy + dst->offset_y;

	SDL_SetAlpha(src->sdl, SDL_SRCALPHA, alpha);
	SDL_BlitSurface(src->sdl, 0, dst->sdl, &dr);

#ifdef JIVE_PROFILE_BLIT
	t1 = jive_jiffies();
	printf("\tjive_surface_blit took=%d\n", t1-t0);
#endif //JIVE_PROFILE_BLIT
}


void jive_surface_get_size(JiveSurface *srf, Uint16 *w, Uint16 *h) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		*w = 0;
		*h = 0;
		return;
	}
	if (w) {
		*w = (srf->sdl) ? srf->sdl->w : 0;
	}
	if (h) {
		*h = (srf->sdl) ? srf->sdl->h : 0;
	}
}


int jive_surface_get_bytes(JiveSurface *srf) {
	SDL_PixelFormat *format;

	if (!srf->sdl) {
		return 0;
	}

	format = srf->sdl->format;
	return srf->sdl->w * srf->sdl->h * format->BytesPerPixel;
}


void jive_surface_free(JiveSurface *srf) {
	if (--srf->refcount > 0) {
		return;
	}

	if (srf->sdl) {
		SDL_FreeSurface (srf->sdl);
		srf->sdl = NULL;
	}
	free(srf);
}

void jive_surface_release(JiveSurface *srf) {
	if (srf->sdl) {
		SDL_FreeSurface (srf->sdl);
		srf->sdl = NULL;
	}
}

/* SDL_gfx encapsulated functions */
JiveSurface *jive_surface_rotozoomSurface(JiveSurface *srf, double angle, double zoom, int smooth){
	JiveSurface *srf2;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = rotozoomSurface(srf->sdl, angle, zoom, smooth);

	return srf2;
}

JiveSurface *jive_surface_zoomSurface(JiveSurface *srf, double zoomx, double zoomy, int smooth) {
	JiveSurface *srf2;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = zoomSurface(srf->sdl, zoomx, zoomy, smooth);

	return srf2;
}

JiveSurface *jive_surface_shrinkSurface(JiveSurface *srf, int factorx, int factory) {
	JiveSurface *srf2;
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return NULL;
	}

	srf2 = calloc(sizeof(JiveSurface), 1);
	srf2->refcount = 1;
	srf2->sdl = shrinkSurface(srf->sdl, factorx, factory);

	return srf2;
}


void jive_surface_pixelColor(JiveSurface *srf, Sint16 x, Sint16 y, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	pixelColor(srf->sdl,
		   x + srf->offset_x,
		   y + srf->offset_y,
		   color);
}

void jive_surface_hlineColor(JiveSurface *srf, Sint16 x1, Sint16 x2, Sint16 y, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	hlineColor(srf->sdl,
		   x1 + srf->offset_x,
		   x2 + srf->offset_x,
		   y + srf->offset_y,
		   color);
}

void jive_surface_vlineColor(JiveSurface *srf, Sint16 x, Sint16 y1, Sint16 y2, Uint32 color) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	vlineColor(srf->sdl,
		   x + srf->offset_x,
		   y1 + srf->offset_y,
		   y2 + srf->offset_y,
		   color);
}

void jive_surface_rectangleColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	rectangleColor(srf->sdl,
		       x1 + srf->offset_x,
		       y1 + srf->offset_y,
		       x2 + srf->offset_x,
		       y2 + srf->offset_y,
		       col);
}

void jive_surface_boxColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	boxColor(srf->sdl,
		 x1 + srf->offset_x,
		 y1 + srf->offset_y,
		 x2 + srf->offset_x,
		 y2 + srf->offset_y,
		 col);
}

void jive_surface_lineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	lineColor(srf->sdl,
		  x1 + srf->offset_x,
		  y1 + srf->offset_y,
		  x2 + srf->offset_x,
		  y2 + srf->offset_y,
		  col);
}

void jive_surface_aalineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aalineColor(srf->sdl,
		    x1 + srf->offset_x,
		    y1 + srf->offset_y,
		    x2 + srf->offset_x,
		    y2 + srf->offset_y,
		    col);
}

void jive_surface_circleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	circleColor(srf->sdl,
		    x + srf->offset_x,
		    y + srf->offset_y,
		    r,
		    col);
}

void jive_surface_aacircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aacircleColor(srf->sdl,
		      x + srf->offset_x,
		      y + srf->offset_y,
		      r,
		      col);
}

void jive_surface_filledCircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledCircleColor(srf->sdl,
			  x + srf->offset_x,
			  y + srf->offset_y,
			  r,
			  col);
}

void jive_surface_ellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	ellipseColor(srf->sdl,
		     x + srf->offset_x,
		     y + srf->offset_y,
		     rx,
		     ry,
		     col);
}

void jive_surface_aaellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aaellipseColor(srf->sdl,
		       x + srf->offset_x,
		       y + srf->offset_y,
		       rx,
		       ry,
		       col);
}

void jive_surface_filledEllipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledEllipseColor(srf->sdl,
			   x + srf->offset_x,
			   y + srf->offset_y,
			   rx,
			   ry,
			   col);
}

void jive_surface_pieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	pieColor(srf->sdl,
		 x + srf->offset_x,
		 y + srf->offset_y,
		 rad,
		 start,
		 end,
		 col);
}

void jive_surface_filledPieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledPieColor(srf->sdl,
		       x + srf->offset_x,
		       y + srf->offset_y,
		       rad,
		       start,
		       end,
		       col);
}

void jive_surface_trigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	trigonColor(srf->sdl,
		    x1 + srf->offset_x,
		    y1 + srf->offset_y,
		    x2 + srf->offset_x,
		    y2 + srf->offset_y,
		    x3 + srf->offset_x,
		    y3 + srf->offset_y,
		    col);
}

void jive_surface_aatrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	aatrigonColor(srf->sdl,
		      x1 + srf->offset_x,
		      y1 + srf->offset_y,
		      x2 + srf->offset_x,
		      y2 + srf->offset_y,
		      x3 + srf->offset_x,
		      y3 + srf->offset_y,
		      col);
}

void jive_surface_filledTrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col) {
	if (!srf->sdl) {
		LOG_ERROR(log_ui, "Underlying sdl surface already freed, possibly with release()");
		return;
	}
	filledTrigonColor(srf->sdl,
			  x1 + srf->offset_x,
			  y1 + srf->offset_y,
			  x2 + srf->offset_x,
			  y2 + srf->offset_y,
			  x3 + srf->offset_x,
			  y3 + srf->offset_y,
			  col);
}
