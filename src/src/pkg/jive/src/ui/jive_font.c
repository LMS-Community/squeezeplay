/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


static const char *JIVE_FONT_MAGIC = "Font";

static JiveFont *fonts = NULL;


static int load_ttf_font(JiveFont *font, const char *name, Uint16 size);

static void destroy_ttf_font(JiveFont *font);

static int width_ttf_font(JiveFont *font, const char *str);

static SDL_Surface *draw_ttf_font(JiveFont *font, Uint32 color, const char *str);



JiveFont *jive_font_load(const char *name, Uint16 size) {

	// Do we already have this font loaded?
	JiveFont *ptr = fonts;
	while (ptr) {
		if (ptr->size == size &&
		    strcmp(ptr->name, name) == 0) {
			ptr->refcount++;
			return ptr;
		}

		ptr = ptr->next;
	}

	/* Initialise the TTF api when required */
	if (!TTF_WasInit() && TTF_Init() == -1) {
		fprintf(stderr, "TTF_Init: %s\n", TTF_GetError());
		exit(-1);
	}

	ptr = calloc(sizeof(JiveFont), 1);
	
	if (!load_ttf_font(ptr, name, size)) {
		free(ptr);
		return NULL;
	}

	ptr->refcount = 1;
	ptr->name = strdup(name);
	ptr->size = size;
	ptr->next = fonts;
	ptr->magic = JIVE_FONT_MAGIC;
	fonts = ptr;

	return ptr;
}

JiveFont *jive_font_ref(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	++font->refcount;
	return font;
}

void jive_font_free(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (--font->refcount > 0) {
		return;
	}

	if (font == fonts) {
		fonts = font->next;
	}
	else {
		JiveFont *ptr = fonts;
		while (ptr) {
			if (ptr->next == font) {
				ptr->next = font->next;
				break;
			}

			ptr = ptr->next;
		}
	}

	font->destroy(font);
	free(font->name);
	free(font);

	/* Shutdown the TTF api when all fonts are free */
	if (fonts == NULL && TTF_WasInit()) {
		TTF_Quit();
	}
}

int jive_font_width(JiveFont *font, const char *str) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->width(font, str);
}

int jive_font_height(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->height;
}

int jive_font_ascend(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->ascend;
}

static int load_ttf_font(JiveFont *font, const char *name, Uint16 size) {
	char *fullpath = malloc(PATH_MAX);

	if (!jive_find_file(name, fullpath) ) {
		free(fullpath);
		fprintf(stderr, "Cannot find font %s\n", name);
		return 0;
	}

	font->ttf = TTF_OpenFont(fullpath, size);
	if (!font->ttf) {
		free(fullpath);
		fprintf(stderr, "TTF_OpenFont: %s\n", TTF_GetError());
		return 0;
	}
	free(fullpath);

	font->height = TTF_FontHeight(font->ttf);
	font->ascend = TTF_FontAscent(font->ttf);
	font->width = width_ttf_font;
	font->draw = draw_ttf_font;
	font->destroy = destroy_ttf_font;

	return 1;
}

static void destroy_ttf_font(JiveFont *font) {
	if (font->ttf) {
		TTF_CloseFont(font->ttf);
		font->ttf = NULL;
	}
}

static int width_ttf_font(JiveFont *font, const char *str) {
	int w, h;

	if (!str) {
		return 0;
	}

	TTF_SizeUTF8(font->ttf, str, &w, &h);
	return w;
}

static SDL_Surface *draw_ttf_font(JiveFont *font, Uint32 color, const char *str) {
	SDL_Color clr;

	clr.r = (color >> 24) & 0xFF;
	clr.g = (color >> 16) & 0xFF;
	clr.b = (color >> 8) & 0xFF;

	return TTF_RenderUTF8_Blended(font->ttf, str, clr);
}

JiveSurface *jive_font_draw_text(JiveFont *font, Uint32 color, const char *str) {
	JiveSurface *srf;

	assert(font && font->magic == JIVE_FONT_MAGIC);

	srf = calloc(sizeof(JiveSurface), 1);
	srf->refcount = 1;
	if (str) {
		srf->sdl = font->draw(font, color, str);
	}

	return srf;
}


#if 0
void jive_font_draw_text_blended(JiveSurface *srf, JiveFont *font, Uint16 x, Uint16 y, Uint32 color, const char *str) {
	JiveSurface *txt;

	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (!str) {
		return;
	}

	txt = font->draw(font, color, str);
	if (!txt) {
		return;
	}

	// SDL_SetAlpha(txt, SDL_SRCALPHA, 0); // FIXME
	jive_surface_blit(txt, srf, x, y);
	// SDL_FreeSurface(txt); // FIXME
}

void jive_font_draw_text(JiveSurface *srf, JiveFont *font, Uint16 x, Uint16 y, Uint32 color, const char *str) {
	JiveSurface *txt;

	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (!str) {
		return;
	}

	txt = font->draw(font, color, str);
	if (!txt) {
		return;
	}

	// SDL_SetAlpha(txt, 0, 0); // FIXME
	jive_surface_blit(txt, srf, x, y);
	// SDL_FreeSurface(txt); // FIXME
}
#endif
