/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"

#define SCROLL_PAD_RIGHT  10
#define SCROLL_PAD_LEFT   -20
#define SCROLL_PAD_START  -10


typedef struct label_widget {
	JiveWidget w;

	// skin properties
	JiveFont *font;
	Uint16 line_height;
	Uint16 line_width;
	Uint16 label_x, label_y; // label position
	Uint16 label_w;
	Uint16 icon_w;
	JiveAlign text_align;
	JiveAlign icon_align;
	bool is_sh;
	Uint32 fg;
	Uint32 sh;
	JiveTile *bg_tile;

	int scroll_offset;
	Uint16 scroll_w;
	Uint16 text_lines;
	Uint16 text_w, text_h;
	JiveSurface **text_sh;
	JiveSurface **text_fg;
} LabelWidget;


static JivePeerMeta labelPeerMeta = {
	sizeof(LabelWidget),
	"JiveLabel",
	jiveL_label_gc,
};



int jiveL_label_skin(lua_State *L) {
	LabelWidget *peer;
	JiveTile *bg_tile;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	peer->font = jive_font_ref(jive_style_font(L, 1, "font"));
	peer->fg = jive_style_color(L, 1, "fg", JIVE_COLOR_BLACK, NULL);
	peer->sh = jive_style_color(L, 1, "sh", JIVE_COLOR_WHITE, &(peer->is_sh));

	bg_tile = jive_style_tile(L, 1, "bgImg", NULL);
	if (bg_tile != peer->bg_tile) {
		if (peer->bg_tile) {
			jive_tile_free(peer->bg_tile);
		}
		peer->bg_tile = jive_tile_ref(bg_tile);
	}

	peer->line_height = jive_style_int(L, 1, "lineHeight", jive_font_ascend(peer->font));
	peer->line_width = jive_style_int(L, 1, "textW", JIVE_WH_NIL);

	peer->text_align = jive_style_align(L, 1, "textAlign", JIVE_ALIGN_LEFT);
	peer->icon_align = jive_style_align(L, 1, "iconAlign", JIVE_ALIGN_RIGHT);


	// XXXX should not have to call pack here but when the label style
	// is modified the icon do not get correctly updated

	/* pack widgets */
	lua_getfield(L, 1, "widget");
	if (!lua_isnil(L, -1)) {
		/* pack widget */
		if (jive_getmethod(L, -1, "reSkin")) {
			lua_pushvalue(L, -2);
			lua_call(L, 1, 0);
		}
	}
	lua_pop(L, 1);

	return 0;
}


int jiveL_label_prepare(lua_State *L) {
	LabelWidget *peer;
	Uint16 width;
	int max_width = 0;
	int i, lines = 1;
	const char *str, *ptr;

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* split multi-line text */
	lua_getglobal(L, "tostring");
	lua_getfield(L, 1, "value");
	lua_call(L, 1, 1);

	ptr = str = lua_tostring(L, -1);

	lua_newtable(L);
	if (ptr) {
		while (*ptr != '\0') {
			if (*ptr == '\n' || *ptr == '\r') {
				lua_pushlstring(L, str, ptr - str);
				lua_rawseti(L, -2, lines++);
				
				while (*ptr == '\n' || *ptr == '\r') {
					ptr++;
				}
				str = ptr;
			}

			ptr++;
		} 

		lua_pushlstring(L, str, ptr - str);
		lua_rawseti(L, -2, lines);
	}

	lua_setfield(L, 1, "text");
	lua_pop(L, 1);


	/* render text to buffer */
	if (peer->text_lines) {
		for (i=0; i<peer->text_lines; i++) {
			if (peer->text_sh[i]) {
				jive_surface_free(peer->text_sh[i]);
			}
			if (peer->text_fg[i]) {
				jive_surface_free(peer->text_fg[i]);
			}
		}
		free(peer->text_sh);
		free(peer->text_fg);
	}
	peer->text_sh = calloc(lines, sizeof(JiveSurface *));
	peer->text_fg = calloc(lines, sizeof(JiveSurface *));
	peer->text_lines = lines;

	i = 0;
	lua_getfield(L, 1, "text");
	lua_pushnil(L);
	for (i=0; lua_next(L, -2) != 0; i++) {
		const char *label = lua_tostring(L, -1);

		/* shadow text */
		if (peer->is_sh) {
			peer->text_sh[i] = jive_font_draw_text(peer->font, peer->sh, label);
		}

		/* foreground text */
		peer->text_fg[i]  = jive_font_draw_text(peer->font, peer->fg, label);

		jive_surface_get_size(peer->text_fg[i], &width, NULL);
		max_width = MAX(max_width, width);

		lua_pop(L, 1);
	}

	/* text width and height */
	peer->text_h = lines * peer->line_height;
	peer->text_w = (peer->line_width == JIVE_WH_NIL) ? max_width : peer->line_width;
	peer->scroll_w = max_width;

	return 0;
}


int jiveL_label_layout(lua_State *L) {
	LabelWidget *peer;
	int wx = 0, wy = 0, ww = 0, wh = 0;

	/* stack is:
	 * 1: widget
	 */

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* layout widget */
	lua_getfield(L, 1, "widget");
	if (!lua_isnil(L, -1)) {
		wx = peer->w.bounds.x;
		wy = peer->w.bounds.y;
		ww = 0;
		wh = 0;

		if (jive_getmethod(L, -1, "getPreferredBounds")) {
			lua_pushvalue(L, -2);
			lua_call(L, 1, 4);

			if (!lua_isnil(L, -4)) {
				wx = lua_tointeger(L, -4);
			}
			if (!lua_isnil(L, -3)) {
				wy = lua_tointeger(L, -3);
			}
			if (!lua_isnil(L, -2)) {
				ww = lua_tointeger(L, -2);
			}
			if (!lua_isnil(L, -1)) {
				wh = lua_tointeger(L, -1);
			}

			lua_pop(L, 4);
		}

		/* don't apply padding for the widget horizontal layout */
		switch (peer->icon_align) {
		default:
		case JIVE_ALIGN_LEFT:
		case JIVE_ALIGN_TOP_LEFT:
		case JIVE_ALIGN_BOTTOM_LEFT:
			wx = 0;
			break;

		case JIVE_ALIGN_CENTER:
		case JIVE_ALIGN_TOP:
		case JIVE_ALIGN_BOTTOM:
			wx = (peer->w.bounds.w - ww) / 2;
			break;

		case JIVE_ALIGN_RIGHT:
		case JIVE_ALIGN_TOP_RIGHT:
		case JIVE_ALIGN_BOTTOM_RIGHT:
			wx = peer->w.bounds.w - ww;
			break;
		}
		wy = peer->w.bounds.y + jive_widget_valign((JiveWidget *)peer, peer->icon_align, wh);

		if (jive_getmethod(L, -1, "setBounds")) {
			lua_pushvalue(L, -2);
			lua_pushinteger(L, wx);
			lua_pushinteger(L, wy);
			lua_pushinteger(L, ww);
			lua_pushinteger(L, wh);
			lua_call(L, 5, 0);
		}
	}

	/* align the label, minus the widget width */
	peer->w.bounds.w -= ww;
	peer->label_x = jive_widget_halign((JiveWidget *)peer, peer->text_align, peer->text_w);
	peer->label_y = jive_widget_valign((JiveWidget *)peer, peer->text_align, peer->text_h);
	peer->label_w = peer->w.bounds.w - peer->w.padding.left - peer->w.padding.right;
	peer->w.bounds.w += ww;

	if (peer->icon_align == JIVE_ALIGN_LEFT) {
		peer->label_x += ww;
	}

	return 0;
}


int jiveL_label_do_animate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 */

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* scroll? */
	if (peer->scroll_w <= peer->label_w) {
		return 0;
	}

	peer->scroll_offset++;

	if (peer->scroll_offset > peer->scroll_w  + SCROLL_PAD_RIGHT) {
		peer->scroll_offset = SCROLL_PAD_LEFT;
	}

	jive_getmethod(L, 1, "reDraw");
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);

	return 0;
}


int jiveL_label_animate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 * 2: boolean
	 */

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);
	if (lua_toboolean(L, 2)) {
		peer->scroll_offset = SCROLL_PAD_START;

		lua_getfield(L, 1, "_animationHandle");
		if (!lua_isnil(L, -1)) {
			return 0;
		}

		/* add animation handler */
		jive_getmethod(L, 1, "addAnimation");
		lua_pushvalue(L, 1);
		lua_pushcfunction(L, &jiveL_label_do_animate);
		lua_pushinteger(L, 14); // 14 fps
		lua_call(L, 3, 1);
		lua_setfield(L, 1, "_animationHandle");
	}
	else {
		peer->scroll_offset = 0;

		/* remove animation handler */
		lua_getfield(L, 1, "_animationHandle");
		if (lua_isnil(L, -1)) {
			return 0;
		}

		jive_getmethod(L, 1, "removeAnimation");
		lua_pushvalue(L, 1);
		lua_pushvalue(L, -3);
		lua_call(L, 2, 0);
		
		lua_pushnil(L);
		lua_setfield(L, 1, "_animationHandle");
	}

	return 0;
}


int jiveL_label_draw(lua_State *L) {
	Uint16 y;
	int i;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	if (drawLayer && peer->bg_tile) {
		jive_tile_blit(peer->bg_tile, srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.w, peer->w.bounds.h);

		//jive_surface_boxColor(srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.x + peer->w.bounds.w-1, peer->w.bounds.y + peer->w.bounds.h-1, 0xFF00007F);
	}

	/* draw child widgets */
	lua_getfield(L, 1, "widget");
	if (jive_getmethod(L, -1, "draw")) {
		lua_pushvalue(L, -2);	// widget
		lua_pushvalue(L, 2);	// surface
		lua_pushvalue(L, 3);	// layer
		lua_call(L, 3, 0);
	}
	lua_pop(L, 1);

	/* draw text label */
	lua_getfield(L, 1, "text");
	if (drawLayer && !lua_isnil(L, -1) && peer->font) {
		Uint16 w, h, o, s;
		Uint16 text_w;

		y = peer->w.bounds.y + peer->label_y;

		lua_pushnil(L);
		for (i=0; lua_next(L, -2) != 0; i++) {
			jive_surface_get_size(peer->text_fg[i], &w, &h);

			/* second text when scrolling */
			o = (peer->scroll_offset < 0) ? 0 : peer->scroll_offset;
			s = peer->scroll_w - o + SCROLL_PAD_RIGHT;

			text_w = peer->label_w; // - peer->icon_w;

			/* shadow text */
			if (peer->text_sh[i]) {
				jive_surface_blit_clip(peer->text_sh[i], o, 0, text_w, h,
						       srf, peer->w.bounds.x + peer->label_x + 1, y + 1);

				if (o && s < text_w) {
					Uint16 len = MAX(0, text_w - s);
					jive_surface_blit_clip(peer->text_sh[i], 0, 0, len, h,
							       srf, peer->w.bounds.x + peer->label_x + s + 1, y + 1);
				} 
			}

			/* foreground text */
			jive_surface_blit_clip(peer->text_fg[i], o, 0, text_w, h,
					       srf, peer->w.bounds.x + peer->label_x, y);

			if (o && s < text_w) {
				Uint16 len = MAX(0, text_w - s);
				jive_surface_blit_clip(peer->text_fg[i], 0, 0, len, h,
						       srf, peer->w.bounds.x + peer->label_x + s, y);
			} 

			y += peer->line_height;

			lua_pop(L, 1);
		}
	}
	lua_pop(L, 1);

	return 0;
}


int jiveL_label_get_preferred_bounds(lua_State *L) {
	LabelWidget *peer;
	Uint16 w, h;

	/* stack is:
	 * 1: widget
	 */

	if (jive_getmethod(L, 1, "doLayout")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	w = peer->text_w + peer->w.padding.left + peer->w.padding.right;
	h = peer->text_h + peer->w.padding.top + peer->w.padding.bottom;

	lua_pushinteger(L, (peer->w.preferred_bounds.x == JIVE_XY_NIL) ? 0 : peer->w.preferred_bounds.x);
	lua_pushinteger(L, (peer->w.preferred_bounds.y == JIVE_XY_NIL) ? 0 : peer->w.preferred_bounds.y);
	lua_pushinteger(L, (peer->w.preferred_bounds.w == JIVE_WH_NIL) ? w : peer->w.preferred_bounds.w);
	lua_pushinteger(L, (peer->w.preferred_bounds.h == JIVE_WH_NIL) ? h : peer->w.preferred_bounds.h);
	return 4;
}


int jiveL_label_gc(lua_State *L) {
	LabelWidget *peer;

	printf("********************* LABEL GC\n");

	luaL_checkudata(L, 1, labelPeerMeta.magic);

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
