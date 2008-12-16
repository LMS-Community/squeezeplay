/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"

#define SCROLL_FPS	7
#define SCROLL_OFFSET	6

#define SCROLL_PAD_RIGHT  40
#define SCROLL_PAD_LEFT   -20
#define SCROLL_PAD_START  -60


typedef struct label_format {
	JiveFont *font;
	bool is_sh, is_fg;
	Uint32 fg, sh;
	Uint16 lineHeight;
	Uint16 textOffset;
} LabelFormat;


typedef struct label_widget {
	JiveWidget w;

	// skin properties
	Uint16 label_w;
	JiveAlign text_align;
	JiveTile *bg_tile;
	LabelFormat base;

	int scroll_offset;
	Uint16 label_x, label_y; // line position
	Uint16 text_w, text_h; // maximum label width and height

	JiveSurface *text_sh;
	JiveSurface *text_fg;
} LabelWidget;


static JivePeerMeta labelPeerMeta = {
	sizeof(LabelWidget),
	"JiveLabel",
	jiveL_label_gc,
};


static void jive_label_gc_lines(LabelWidget *peer);
static void jive_label_gc_formats(LabelWidget *format);


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

	jive_label_gc_formats(peer);

	peer->base.font = jive_font_ref(jive_style_font(L, 1, "font"));
	peer->base.lineHeight = jive_style_int(L, 1, "lineHeight", jive_font_capheight(peer->base.font));
	peer->base.textOffset = jive_font_offset(peer->base.font);

	peer->base.fg = jive_style_color(L, 1, "fg", JIVE_COLOR_BLACK, NULL);
	peer->base.sh = jive_style_color(L, 1, "sh", JIVE_COLOR_WHITE, &(peer->base.is_sh));

	bg_tile = jive_style_tile(L, 1, "bgImg", NULL);
	if (bg_tile != peer->bg_tile) {
		if (peer->bg_tile) {
			jive_tile_free(peer->bg_tile);
		}
		peer->bg_tile = jive_tile_ref(bg_tile);
	}

	peer->text_align = jive_style_align(L, 1, "align", JIVE_ALIGN_LEFT);
	return 0;
}


static void prepare(lua_State *L) {
	LabelWidget *peer;
	Uint16 width, height, offset;
	const char *str;

	JiveFont *font;
	Uint32 fg, sh;
	bool is_sh;

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* free existing text surfaces */
	jive_label_gc_lines(peer);

	lua_getglobal(L, "tostring");
	lua_getfield(L, 1, "value");
	lua_call(L, 1, 1);

	str = lua_tostring(L, -1);

	if (!str || *str == '\0') {
		return;
	}

	peer->text_sh = peer->base.is_sh ? jive_font_draw_text(peer->base.font, peer->base.sh, str) : NULL;
	peer->text_fg = jive_font_draw_text(peer->base.font, peer->base.fg, str);


	/* label dimensions */
	jive_surface_get_size(peer->text_fg, &width, &height);
	//Note: surface height being returned is higher than peer->base.lineHeight, why? for now commenting out next line because of this
	//	height = MAX(peer->base.lineHeight, height);
	height = peer->base.lineHeight;
	
	/* text width and height */
	peer->text_h = height;
	peer->text_w = width;

	/* reset scroll position */
	peer->scroll_offset = SCROLL_PAD_START;

}


int jiveL_label_layout(lua_State *L) {
	LabelWidget *peer;
	Uint16 y;
	size_t i;
	Uint16 w, h;

	/* stack is:
	 * 1: widget
	 */

	// FIXME
	prepare(L);

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* align the label, minus the widget width */
	y = jive_widget_valign((JiveWidget *)peer, peer->text_align, peer->text_h);
	
	if (peer->text_fg ) {

		jive_surface_get_size(peer->text_fg, &w, &h);
	
		peer->label_x = jive_widget_halign((JiveWidget *)peer, peer->text_align, w);
		peer->label_y = y - peer->base.textOffset;
	
		y += peer->base.lineHeight;
	
	}

	/* maximum render width */
	peer->label_w = peer->w.bounds.w - peer->w.padding.left - peer->w.padding.right;

	return 0;
}


int jiveL_label_do_animate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 */

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);

	/* scroll? */
	if (peer->text_w <= peer->label_w) {
		return 0;
	}

	peer->scroll_offset += SCROLL_OFFSET;

	if (peer->scroll_offset > peer->text_w  + SCROLL_PAD_RIGHT) {
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
		lua_pushinteger(L, SCROLL_FPS);
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
	size_t i;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	Uint16 w, h, o, s;
	Uint16 text_w;

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	if (drawLayer && peer->bg_tile) {
		jive_tile_blit(peer->bg_tile, srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.w, peer->w.bounds.h);
	}

	//jive_surface_boxColor(srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.x + peer->w.bounds.w-1, peer->w.bounds.y + peer->w.bounds.h-1, 0x00FF007F);

	/* draw text label */
	if (!(drawLayer && peer->text_fg)) {
		return 0;
	}


	jive_surface_get_size(peer->text_fg, &w, &h);

	/* second text when scrolling */
	o = (peer->scroll_offset < 0) ? 0 : peer->scroll_offset;
	if (w < peer->label_w) {
		o = 0;
	}

	s = peer->text_w - o + SCROLL_PAD_RIGHT;
	text_w = peer->label_w;

	/* shadow text */
	if (peer->text_sh) {
		jive_surface_blit_clip(peer->text_sh, o, 0, text_w, h,
					   srf, peer->w.bounds.x + peer->label_x + 1, peer->w.bounds.y + peer->label_y + 1);

		if (o && s < text_w) {
			Uint16 len = MAX(0, text_w - s);
			jive_surface_blit_clip(peer->text_sh, 0, 0, len, h,
						   srf, peer->w.bounds.x + peer->label_x + s + 1, peer->w.bounds.y + peer->label_y + 1);
		} 
	}

	/* foreground text */
	jive_surface_blit_clip(peer->text_fg, o, 0, text_w, h,
				   srf, peer->w.bounds.x + peer->label_x, peer->w.bounds.y + peer->label_y);

	if (o && s < text_w) {
		Uint16 len = MAX(0, text_w - s);
		jive_surface_blit_clip(peer->text_fg, 0, 0, len, h,
					   srf, peer->w.bounds.x + peer->label_x + s, peer->w.bounds.y + peer->label_y);
	} 

	return 0;
}


int jiveL_label_get_preferred_bounds(lua_State *L) {
	LabelWidget *peer;
	Uint16 w, h;

	/* stack is:
	 * 1: widget
	 */

	// FIXME
	if (jive_getmethod(L, 1, "checkLayout")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	w = peer->text_w + peer->w.padding.left + peer->w.padding.right;
	h = peer->text_h + peer->w.padding.top + peer->w.padding.bottom;

	if (peer->w.preferred_bounds.x == JIVE_XY_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->w.preferred_bounds.x);
	}
	if (peer->w.preferred_bounds.y == JIVE_XY_NIL) {
		lua_pushnil(L);
	}
	else {
		lua_pushinteger(L, peer->w.preferred_bounds.y);
	}
	lua_pushinteger(L, (peer->w.preferred_bounds.w == JIVE_WH_NIL) ? w : peer->w.preferred_bounds.w);
	lua_pushinteger(L, (peer->w.preferred_bounds.h == JIVE_WH_NIL) ? h : peer->w.preferred_bounds.h);
	return 4;
}


static void jive_label_gc_lines(LabelWidget *peer) {
	if (peer->text_sh) {
		jive_surface_free(peer->text_sh);
	}
	if (peer->text_fg) {
		jive_surface_free(peer->text_fg);
	}
}


static void jive_label_gc_format(LabelFormat *format) {
	if (format->font) {
		jive_font_free(format->font);
		format->font = NULL;
	}
}


static void jive_label_gc_formats(LabelWidget *peer) {
	jive_label_gc_format(&peer->base);
}


int jiveL_label_gc(lua_State *L) {
	LabelWidget *peer;

	luaL_checkudata(L, 1, labelPeerMeta.magic);

	peer = lua_touserdata(L, 1);

	jive_label_gc_lines(peer);
	jive_label_gc_formats(peer);
	
	if (peer->bg_tile) {
		jive_tile_free(peer->bg_tile);
		peer->bg_tile = NULL;
	}

	return 0;
}
