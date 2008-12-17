/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"
#include <pango/pango.h>


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
	if (font) {
		assert(font->magic == JIVE_FONT_MAGIC);
		++font->refcount;
	}
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

int jive_font_nwidth(JiveFont *font, const char *str, size_t len) {
	int w;
	char *tmp;

	assert(font && font->magic == JIVE_FONT_MAGIC);

	if (len <= 0) {
		return 0;
	}

	// FIXME use utf8 len
	tmp = malloc(len + 1);
	strncpy(tmp, str, len);
	*(tmp + len) = '\0';
	
	w = font->width(font, tmp);

	free(tmp);

	return w;
}

int jive_font_capheight(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->capheight;
}

int jive_font_height(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->height;
}

int jive_font_ascend(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->ascend;
}

int jive_font_offset(JiveFont *font) {
	assert(font && font->magic == JIVE_FONT_MAGIC);

	return font->ascend - font->capheight;
}

static int load_ttf_font(JiveFont *font, const char *name, Uint16 size) {
	int miny, maxy, descent;
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

	font->ascend = TTF_FontAscent(font->ttf);

	/* calcualte the cap height using H */
	if (TTF_GlyphMetrics(font->ttf, 'H', NULL, NULL, NULL, &maxy, NULL) == 0) {
		font->capheight = maxy;
	}
	else {
		font->capheight = font->ascend;
	}

	/* calcualte the non diacritical descent using g */
	if (TTF_GlyphMetrics(font->ttf, 'g', NULL, NULL, &miny, NULL, NULL) == 0) {
		descent = miny;
	}
	else {
		descent = TTF_FontDescent(font->ttf);
	}

	/* calculate the font height, using the capheight and descent */
	font->height = font->capheight - descent + 1;

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
#ifdef JIVE_PROFILE_BLIT
	Uint32 t0 = SDL_GetTicks(), t1;
#endif //JIVE_PROFILE_BLIT
	SDL_Color clr;
	SDL_Surface *srf;

	clr.r = (color >> 24) & 0xFF;
	clr.g = (color >> 16) & 0xFF;
	clr.b = (color >> 8) & 0xFF;

	srf = TTF_RenderUTF8_Blended(font->ttf, str, clr);

#if 0
	// draw text bounding box for debugging
	if (srf) {
		rectangleColor(srf, 0,0, srf->w - 1, srf->h - 1, 0xff0000df);
		lineColor(srf, 0, font->ascend, srf->w - 1, font->ascend, 0xff0000df);
		lineColor(srf, 0, font->ascend, srf->w - 1, font->ascend, 0xff0000df);
		lineColor(srf, 0, font->ascend - font->capheight, srf->w - 1, font->ascend - font->capheight, 0xff0000df);
	}
#endif


#ifdef JIVE_PROFILE_BLIT
	t1 = SDL_GetTicks();
	printf("\tdraw_ttf_font took=%d %s\n", t1-t0, str);
#endif //JIVE_PROFILE_BLIT

	return srf;
}
JiveSurface *jive_font_draw_text(JiveFont *font, Uint32 color, const char *str ) {
    return jive_font_draw_text_wrap(font, color, str, -1 );
}

/**
 * if wrapping_width == -1, no wrapping will be done
 */
JiveSurface *jive_font_draw_text_wrap(JiveFont *font, Uint32 color, const char *str, Uint16 wrapping_width ) {
	JiveSurface *jive_surface;
	PangoAttrList *attr_list;
	PangoAttribute *size, *fgcolor, *family, *weight, *letter_spacing;
    GError *err = NULL;
    char *text = NULL;
    
	assert(font && font->magic == JIVE_FONT_MAGIC);

    PangoLayout *layout = SDLPango_GetPangoLayout(pangocontext);

    if ( !pango_parse_markup(str, -1, 0, &attr_list, &text, NULL, &err)) {
        fprintf(stderr, "pango_parse_markup error: %s\n", err->message);
        g_error_free(err); 
    	
    	//Fall back to using non-marked up set_text which is more forgiving and will replace illegal chars with '?' 
    	attr_list = pango_attr_list_new();
    	pango_layout_set_text (layout, str, -1);
    } else {
    	pango_layout_set_text (layout, text, -1);    
    }
    
	
	size = pango_attr_size_new (font->size * 1000);
	size->start_index = 0;
	size->end_index = strlen(str);
    pango_attr_list_insert_before (attr_list, size);
    	
	fgcolor = pango_attr_foreground_new (256 * ((color >> 24) & 0xFF), 256 * ((color >> 16) & 0xFF) , 256 * ((color >> 8) & 0xFF));
	fgcolor->start_index = 0;
	fgcolor->end_index = strlen(str);
    pango_attr_list_insert_before (attr_list, fgcolor);
	
	family = pango_attr_family_new ("FreeSans");
	family->start_index = 0;
	family->end_index = strlen(str);
    pango_attr_list_insert_before (attr_list, family);
    	
    if (strstr(font->name, "Bold") != NULL) {	
		weight = pango_attr_weight_new (PANGO_WEIGHT_BOLD);
		weight->start_index = 0;
		weight->end_index = strlen(str);
		pango_attr_list_insert_before (attr_list, weight);
	}
        	
//    letter_spacing = pango_attr_letter_spacing_new (-600);
//	letter_spacing->start_index = 0;
//	letter_spacing->end_index = strlen(str);
//    pango_attr_list_insert_before (attr_list, letter_spacing);


	pango_layout_set_attributes(layout, attr_list);
	pango_layout_context_changed(layout);
	pango_attr_list_unref(attr_list);
    g_free (text);


	if (wrapping_width == -1) {
	    //don't wrap
        pango_layout_set_width(layout, (guint) -1);
    } else {
        pango_layout_set_width(layout, (guint) wrapping_width * PANGO_SCALE);
    }
    pango_layout_set_wrap(layout, PANGO_WRAP_WORD);
    //pango_layout_set_height (SDLPango_GetPangoLayout(pangocontext), 300* PANGO_SCALE);
    
	jive_surface = jive_surface_new_SDLSurface(str ? SDLPango_CreateSurfaceDraw (pangocontext) : NULL);

	return jive_surface;

}

JiveSurface *jive_font_ndraw_text(JiveFont *font, Uint32 color, const char *str, size_t len) {	
	JiveSurface *srf;
	char *tmp;

	// FIXME use utf8 len

	tmp = malloc(len + 1);
	strncpy(tmp, str, len);
	*(tmp + len) = '\0';
	
	srf = jive_font_draw_text(font, color, tmp);

	free(tmp);

	return srf;
}
