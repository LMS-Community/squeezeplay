/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct label_widget {
	JiveWidget w;

	// skin properties
	JiveFont *font;
	Uint16 line_height;
	Uint16 label_x, label_y; // label position
	Uint16 label_w;
	bool is_bg;
	bool is_sh;
	Uint32 bg;
	Uint32 fg;
	Uint32 sh;
	JiveSurface *bg_img;
} LabelWidget;


static JivePeerMeta labelPeerMeta = {
	sizeof(LabelWidget),
	"JiveLabel",
	jiveL_label_gc,
};


int jiveL_label_pack(lua_State *L) {
	LabelWidget *peer;
	JiveSurface *bg_img;
	SDL_Rect icon_bounds;
	int label_w = 0;
	int label_height = 0;
	JiveAlign align;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &labelPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	peer->font = jive_font_ref(jive_style_font(L, 1, "font"));
	peer->bg = jive_style_color(L, 1, "bg", JIVE_COLOR_WHITE, &(peer->is_bg));
	peer->fg = jive_style_color(L, 1, "fg", JIVE_COLOR_BLACK, NULL);
	peer->sh = jive_style_color(L, 1, "sh", JIVE_COLOR_WHITE, &(peer->is_sh));

	bg_img = jive_style_image(L, 1, "bgImg", NULL);
	if (bg_img != peer->bg_img) {
		if (peer->bg_img) {
			jive_surface_free(peer->bg_img);
		}
		peer->bg_img = jive_surface_ref(bg_img);
	}

	peer->line_height = jive_style_int(L, 1, "lineHeight", jive_font_ascend(peer->font));

	/* format text */
	lua_getfield(L, 1, "text");
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);

		jive_getmethod(L, 1, "_makeText");
		lua_pushvalue(L, 1);
		lua_call(L, 1, 1);
	}

	/* text bounds */
	if (!lua_isnil(L, 1)) {
		int num_lines = lua_objlen(L, -1);

		label_w = jive_style_int(L, 1, "textW", -1);
		if (label_w == -1) {
			int i;

			for (i = 1; i <= num_lines; i++) {
				const char *str;
				int width;

				lua_rawgeti(L, -1, i);
				str = lua_tostring(L, -1);
				
				width = jive_font_width(peer->font, str);
				label_w = MAX(label_w, width);

				lua_pop(L, 1);
			}
		}

		// FIXME not all lines are the same height
		label_height = num_lines * peer->line_height;
	}
	lua_pop(L, 1);
	peer->label_w = label_w;


	/* icon bounds */
	lua_getfield(L, 1, "widget");
	if (!lua_isnil(L, -1)) {
		/* pack widget
		 * we have to make sure the w,h are initialised
		 */
		if (jive_getmethod(L, -1, "pack")) {
			lua_pushvalue(L, -2);
			lua_call(L, 1, 0);
		}

		jive_widget_get_bounds(L, -1, &icon_bounds);
	}
	else {
		memset(&icon_bounds.w, 0, sizeof(SDL_Rect));
	}
	lua_pop(L, 1);


	/* default bounds tight around text and icon */

	/* FIXME by default a label's width and height will be shrunk
	 * to tightly fit around it's components. To do this we get the
	 * width and height of the label again here, if they are not set
	 * in the skin the work out the best size. This means that the
	 * label size cannot be specified by lua.
	 */
	peer->w.bounds.w = jive_style_int(L, 1, "w", 0);
	peer->w.bounds.h = jive_style_int(L, 1, "h", 0);

	if (!peer->w.bounds.h || !peer->w.bounds.w) {
		if (!peer->w.bounds.w) {
			peer->w.bounds.w = peer->w.lp + label_w + icon_bounds.w + peer->w.rp;
		}

		if (!peer->w.bounds.h) {
			peer->w.bounds.h = peer->w.tp + MAX(label_height, icon_bounds.h) + peer->w.bp;
		}
		
		jive_widget_set_bounds(L, 1, &peer->w.bounds);
	}


	/* pack text */
	align = jive_style_align(L, 1, "textAlign", JIVE_ALIGN_LEFT);
	peer->label_x = jive_widget_halign((JiveWidget *)peer, align, label_w);
	peer->label_y = jive_widget_valign((JiveWidget *)peer, align, label_height);


	/* pack widgets */
	lua_getfield(L, 1, "widget");
	if (!lua_isnil(L, -1)) {
		JiveAlign align;

		/* set bounds */
		align = jive_style_align(L, 1, "iconAlign", JIVE_ALIGN_RIGHT);
				
		icon_bounds.x = peer->w.bounds.x + jive_widget_halign((JiveWidget *)peer, align, icon_bounds.w);
		icon_bounds.y = peer->w.bounds.y + jive_widget_valign((JiveWidget *)peer, align, icon_bounds.h);

		jive_widget_set_bounds(L, -1, &icon_bounds);

		/* pack widget
		 * this sets the x,y location of the widget
		 */
		if (jive_getmethod(L, -1, "pack")) {
			lua_pushvalue(L, -2);
			lua_call(L, 1, 0);
		}
	}
	lua_pop(L, 1);

	return 0;
}


int jiveL_label_draw(lua_State *L) {
	Uint16 y;
	int n;

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	LabelWidget *peer = jive_getpeer(L, 1, &labelPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	if (drawLayer && peer->is_bg) {
		jive_surface_boxColor(srf, peer->w.bounds.x, peer->w.bounds.y, peer->w.bounds.x + peer->w.bounds.w, peer->w.bounds.y + peer->w.bounds.h, peer->bg);
	}
	if (drawLayer && peer->bg_img) {
		jive_surface_blit(peer->bg_img, srf, peer->w.bounds.x, peer->w.bounds.y);
	}

	/* draw child widgets */
	lua_getfield(L, 1, "widget");
	if (!lua_isnil(L, -1)) {
		if (jive_getmethod(L, -1, "draw")) {
			lua_pushvalue(L, -2);	// widget
			lua_pushvalue(L, 2);	// surface
			lua_pushvalue(L, 3);	// layer
			lua_call(L, 3, 0);
		}

	}
	lua_pop(L, 1);

	/* draw text label */
	lua_getfield(L, 1, "text");
	if (drawLayer && !lua_isnil(L, -1) && peer->font) {

		// FIXME this label cropping is crude, we need "..."
		// FIXME also scrolling when selected
		SDL_Rect old_clip, new_clip;
		jive_surface_get_clip(srf, &old_clip);
		
		new_clip.x = peer->w.bounds.x + peer->label_x;
		new_clip.y = old_clip.y;
		new_clip.w = peer->label_w;
		new_clip.h = old_clip.h;

		jive_rect_intersection(&old_clip, &new_clip, &new_clip);

		jive_surface_set_clip(srf, &new_clip);


		n = 1;
		y = peer->w.bounds.y + peer->label_y;

		lua_rawgeti(L, -1, n++);
		while (!lua_isnil(L, -1)) {
			JiveSurface *tsrf;
			const char *label = lua_tostring(L, -1);

			if (peer->is_sh) {
				tsrf = jive_font_draw_text(peer->font, peer->sh, label);
				jive_surface_blit(tsrf, srf, peer->w.bounds.x + peer->label_x + 1, y + 1);
				jive_surface_free(tsrf);
			}

			tsrf = jive_font_draw_text(peer->font, peer->fg, label);
			jive_surface_blit(tsrf, srf, peer->w.bounds.x + peer->label_x, y);
			jive_surface_free(tsrf);

			y += peer->line_height;

			lua_pop(L, 1);
			lua_rawgeti(L, -1, n++);
		}
		lua_pop(L, 1);


		jive_surface_set_clip(srf, &old_clip);
	}
	lua_pop(L, 1);

	return 0;
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
	if (peer->bg_img) {
		jive_surface_free(peer->bg_img);
		peer->bg_img = NULL;
	}

	return 0;
}
