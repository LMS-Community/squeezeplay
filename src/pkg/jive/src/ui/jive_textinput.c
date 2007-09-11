/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct textinput_widget {
	JiveWidget w;

	// skin properties
	JiveFont *font;
	JiveFont *cursorFont;
	Uint16 char_height;
	Uint16 char_width;
	Uint16 max_width;
	bool is_sh;
	Uint32 fg;
	Uint32 sh;
	Uint32 wh;
	JiveTile *bg_tile;
	JiveTile *wheel_tile;
	JiveTile *cursor_tile;
	JiveTile *enter_tile;
} TextinputWidget;


static JivePeerMeta textinputPeerMeta = {
	sizeof(TextinputWidget),
	"JiveTextinput",
	jiveL_textinput_gc,
};



int jiveL_textinput_skin(lua_State *L) {
	TextinputWidget *peer;
	JiveTile *tile;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &textinputPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	peer->font = jive_font_ref(jive_style_font(L, 1, "font"));
	peer->cursorFont = jive_font_ref(jive_style_font(L, 1, "cursorFont"));
	peer->fg = jive_style_color(L, 1, "fg", JIVE_COLOR_BLACK, NULL);
	peer->sh = jive_style_color(L, 1, "sh", JIVE_COLOR_WHITE, &(peer->is_sh));
	peer->wh = jive_style_color(L, 1, "wh", JIVE_COLOR_WHITE, NULL);

	tile = jive_style_tile(L, 1, "bgImg", NULL);
	if (tile != peer->bg_tile) {
		if (peer->bg_tile) {
			jive_tile_free(peer->bg_tile);
		}
		peer->bg_tile = jive_tile_ref(tile);
	}

	tile = jive_style_tile(L, 1, "wheelImg", NULL);
	if (tile != peer->wheel_tile) {
		if (peer->wheel_tile) {
			jive_tile_free(peer->wheel_tile);
		}
		peer->wheel_tile = jive_tile_ref(tile);
	}

	tile = jive_style_tile(L, 1, "cursorImg", NULL);
	if (tile != peer->cursor_tile) {
		if (peer->cursor_tile) {
			jive_tile_free(peer->cursor_tile);
		}
		peer->cursor_tile = jive_tile_ref(tile);
	}

	tile = jive_style_tile(L, 1, "enterImg", NULL);
	if (tile != peer->enter_tile) {
		if (peer->enter_tile) {
			jive_tile_free(peer->enter_tile);
		}
		peer->enter_tile = jive_tile_ref(tile);
	}

	peer->char_height = jive_style_int(L, 1, "charHeight", jive_font_height(peer->font));
	peer->char_width = jive_style_int(L, 1, "charWidth", jive_font_width(peer->font, "X"));

	return 0;
}


int jiveL_textinput_prepare(lua_State *L) {
	TextinputWidget *peer;
	const char *str;

	peer = jive_getpeer(L, 1, &textinputPeerMeta);

	/* measure text width */
	lua_getglobal(L, "tostring");
	lua_getfield(L, 1, "value");
	lua_call(L, 1, 1);

	str = lua_tostring(L, -1);
	peer->max_width = peer->char_width * strlen(str); // FIXME utf8

	return 0;
}

int jiveL_textinput_layout(lua_State *L) {
	TextinputWidget *peer;

	/* stack is:
	 * 1: widget
	 */

	peer = jive_getpeer(L, 1, &textinputPeerMeta);
	return 0;
}


int jiveL_textinput_draw(lua_State *L) {
	Uint16 x;
	Uint16 offset_x, offset_y, offset_cursor_y;
	JiveSurface *tsrf;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	TextinputWidget *peer = jive_getpeer(L, 1, &textinputPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	const char *text;
	size_t text_len;
	int cursor;
	int indent;
	SDL_Rect old_clip, new_clip;
	Uint16 text_h, text_x, text_y, text_w, cursor_x, cursor_w;
	const char *validchars, *validchars_end;
	int len_1, len_2, len_3;
	int i;


	/* get value as string */
	lua_getfield(L, 1, "value");
	lua_getglobal(L, "tostring");
	lua_getfield(L, 1, "value");
	lua_call(L, 1, 1);

	text = lua_tostring(L, -1);

	lua_getfield(L, 1, "cursor");
	cursor = lua_tointeger(L, -1);

	lua_getfield(L, 1, "indent");
	indent = lua_tointeger(L, -1);
	text += indent;
	cursor -= indent;

	text_len = strlen(text);

	/* calculate positions */
	text_h = peer->char_height;
	text_x = peer->w.bounds.x + peer->w.padding.left;
	text_y = peer->w.bounds.y + peer->w.padding.top + ((peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom - text_h) / 2);
	text_w = peer->w.bounds.w - peer->w.padding.left - peer->w.padding.right;
	text_x += (text_w % peer->char_width) / 2;
	text_w = (text_w / peer->char_width) * peer->char_width;

	cursor_w = peer->char_width;

	/* measure text */
	len_1 = jive_font_nwidth(peer->font, text, cursor - 1);
	len_2 = jive_font_nwidth(peer->cursorFont, text + cursor - 1, 1);
	len_3 = (cursor < text_len) ? jive_font_width(peer->font, text + cursor) : 0;

	/* move ident if cursor is off stage right */
	while (len_1 + cursor_w > text_w) {
		indent++;
		text++;
		text_len--;
		cursor--;

		len_1 = jive_font_nwidth(peer->font, text, cursor - 1);
		len_2 = jive_font_nwidth(peer->cursorFont, text + cursor - 1, 1);
		len_3 = (cursor < text_len) ? jive_font_width(peer->font, text + cursor) : 0;
	}

	/* move ident if cursor is off stage left */
	while (indent > 0 && len_1 - cursor_w < 0) {

		indent--;
		text--;
		text_len++;
		cursor++;

		len_1 = jive_font_nwidth(peer->font, text, cursor - 1);
		len_2 = jive_font_nwidth(peer->cursorFont, text + cursor - 1, 1);
		len_3 = (cursor < text_len) ? jive_font_width(peer->font, text + cursor) : 0;
	}

	/* keep cursor fixed distance from stage right */
	if (len_1 > text_w - cursor_w * 2) {
		int d = (text_w - cursor_w * 2) - len_1;

		text_x += d;
	}

#if 0
	/* keep cursor fixed distance from stage left */
	if (len_1 < cursor_w * 2) {
		int d = (cursor_w) - len_1;

		if (len_1 > d) {
			text_x += d;
		}
	}
#endif

	lua_pushinteger(L, indent);
	lua_setfield(L, 1, "indent");

	cursor_x = text_x + len_1;
	offset_y = (peer->char_height - jive_font_ascend(peer->font)) / 2;
	offset_cursor_y = (peer->char_height - jive_font_ascend(peer->cursorFont)) / 2;

	/* Valid characters */
	jive_getmethod(L, 1, "_getChars");
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);

	validchars = lua_tostring(L, -1);
	validchars_end = validchars + strlen(validchars) - 1;

	//jive_surface_boxColor(srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.x + peer->w.bounds.w, peer->w.bounds.y + peer->w.bounds.h, 0xFF00007F); // XXXX

	jive_surface_get_clip(srf, &old_clip);

	/* background clip */
	new_clip.x = peer->w.bounds.x;
	new_clip.y = peer->w.bounds.y;
	new_clip.w = peer->w.bounds.w;
	new_clip.h = peer->w.bounds.h;
	jive_surface_set_clip(srf, &new_clip);

	/* draw wheel */
	if (drawLayer && peer->wheel_tile && strlen(validchars)) {
		int w = cursor_w;
		int h = peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom;
		jive_tile_blit_centered(peer->wheel_tile, srf, cursor_x + (w / 2), peer->w.bounds.y + peer->w.padding.top + (h / 2), w, h);
	}

	/* draw background */
	if (drawLayer && peer->bg_tile) {
		jive_tile_blit_centered(peer->bg_tile, srf, peer->w.bounds.x + (peer->w.bounds.w / 2), text_y + (text_h / 2), peer->w.bounds.w, text_h);
	}

	/* content clip */
	new_clip.x = peer->w.bounds.x + peer->w.padding.left;
	new_clip.y = peer->w.bounds.y + peer->w.padding.top;
	new_clip.w = peer->w.bounds.w - peer->w.padding.left - peer->w.padding.right;
	new_clip.h = peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom;
	jive_surface_set_clip(srf, &new_clip);

	/* draw text label */
	if (drawLayer && peer->font) {
	  
		if (peer->is_sh) {
			/* pre-cursor */
			tsrf = jive_font_ndraw_text(peer->font, peer->sh, text, cursor - 1);
			jive_surface_blit(tsrf, srf, text_x + 1, text_y + offset_y + 1);
			jive_surface_free(tsrf);

			/* cursor */
			tsrf = jive_font_ndraw_text(peer->cursorFont, peer->sh, text + cursor - 1, 1);
			jive_surface_blit(tsrf, srf, cursor_x + (cursor_w - len_2) / 2 + 1, text_y + offset_cursor_y + 1);
			jive_surface_free(tsrf);

			/* post-cursor */
			if (cursor < text_len) {
				tsrf = jive_font_draw_text(peer->font, peer->sh, text + cursor);
				jive_surface_blit(tsrf, srf, cursor_x + cursor_w + 1, text_y + offset_y + 1);
				jive_surface_free(tsrf);
			}
		}

		/* pre-cursor */
		tsrf = jive_font_ndraw_text(peer->font, peer->fg, text, cursor - 1);
		jive_surface_blit(tsrf, srf, text_x, text_y + offset_y);
		jive_surface_free(tsrf);

		/* cursor */
		tsrf = jive_font_ndraw_text(peer->cursorFont, peer->fg, text + cursor - 1, 1);
		jive_surface_blit(tsrf, srf, cursor_x + (cursor_w - len_2) / 2, text_y + offset_cursor_y);
		jive_surface_free(tsrf);

		/* post-cursor */
		if (cursor < text_len) {
			tsrf = jive_font_draw_text(peer->font, peer->fg, text + cursor);
			jive_surface_blit(tsrf, srf, cursor_x + cursor_w, text_y + offset_y);
			jive_surface_free(tsrf);
		}

		if (cursor > text_len && peer->enter_tile) {
			/* draw enter in cursor */
			Uint16 cw, ch;

			jive_tile_get_min_size(peer->enter_tile, &cw, &ch);
			jive_tile_blit_centered(peer->enter_tile, srf, text_x + len_1 + (cursor_w / 2), text_y + (peer->char_height / 2), 0, 0);
		}
		else if (peer->enter_tile) {
			/* draw enter */
			Uint16 cw, ch;

			x = len_1 + cursor_w + len_3;
			jive_tile_get_min_size(peer->enter_tile, &cw, &ch);
			jive_tile_blit_centered(peer->enter_tile, srf, text_x + x + (cw / 2), text_y + (peer->char_height / 2), 0, 0);
		}
	}

	if (drawLayer) {
		const char *ptr = strchr(validchars, text[cursor - 1]);
		const char *ptr2;

		/* Draw wheel up */
		ptr2 = ptr - 1;
		for (i=1; i <= (peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom - peer->char_height) / 2 / peer->char_height; i++) {
			if (ptr2 < validchars) {
				ptr2 = validchars_end;
			}
			else if (ptr2 > validchars_end) {
				ptr2 = validchars;
			}
		
			offset_x = (peer->char_width - jive_font_nwidth(peer->font, ptr2, 1)) / 2;
			
			tsrf = jive_font_ndraw_text(peer->font, peer->wh, ptr2, 1);
			jive_surface_blit(tsrf, srf, cursor_x + offset_x, text_y - (i * peer->char_height) + offset_y);
			jive_surface_free(tsrf);

			ptr2--; // FIXME utf8
		}
		
		/* Draw wheel down */
		ptr2 = ptr + 1;
		for (i=1; i <= (peer->w.bounds.h - peer->w.padding.top - peer->w.padding.bottom - peer->char_height) / 2 / peer->char_height; i++) {
			if (ptr2 < validchars) {
				ptr2 = validchars_end;
			}
			else if (ptr2 > validchars_end) {
				ptr2 = validchars;
			}
			
			offset_x = (peer->char_width - jive_font_nwidth(peer->font, ptr2, 1)) / 2;
			
			tsrf = jive_font_ndraw_text(peer->font, peer->wh, ptr2, 1);
			jive_surface_blit(tsrf, srf, cursor_x + offset_x, text_y + (i * peer->char_height) + offset_y);
			jive_surface_free(tsrf);

			ptr2++; // FIXME utf8
		}
	}

	jive_surface_set_clip(srf, &old_clip);

	/* draw cursor */
	if (drawLayer && peer->cursor_tile) {
		jive_tile_blit_centered(peer->cursor_tile, srf, cursor_x + (peer->char_width / 2), text_y + (peer->char_height / 2), cursor_w, text_h);
	}

	lua_pop(L, 4);

	return 0;
}


int jiveL_textinput_get_preferred_bounds(lua_State *L) {
	TextinputWidget *peer;
	Uint16 w, h;

	/* stack is:
	 * 1: widget
	 */

	if (jive_getmethod(L, 1, "doLayout")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	peer = jive_getpeer(L, 1, &textinputPeerMeta);

	w = peer->max_width + peer->w.padding.left + peer->w.padding.right;
	h = JIVE_WH_NIL;

	lua_pushinteger(L, (peer->w.preferred_bounds.x == JIVE_XY_NIL) ? 0 : peer->w.preferred_bounds.x);
	lua_pushinteger(L, (peer->w.preferred_bounds.y == JIVE_XY_NIL) ? 0 : peer->w.preferred_bounds.y);
	lua_pushinteger(L, (peer->w.preferred_bounds.w == JIVE_WH_NIL) ? w : peer->w.preferred_bounds.w);
	lua_pushinteger(L, (peer->w.preferred_bounds.h == JIVE_WH_NIL) ? h : peer->w.preferred_bounds.h);
	return 4;
}


int jiveL_textinput_gc(lua_State *L) {
	TextinputWidget *peer;

	printf("********************* TEXTINPUT GC\n");

	luaL_checkudata(L, 1, textinputPeerMeta.magic);

	peer = lua_touserdata(L, 1);

	if (peer->font) {
		jive_font_free(peer->font);
		peer->font = NULL;
	}
	if (peer->bg_tile) {
		jive_tile_free(peer->bg_tile);
		peer->bg_tile = NULL;
	}

	return 0;
}
