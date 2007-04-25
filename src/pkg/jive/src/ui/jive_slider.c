/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"


typedef struct slider_widget {
	JiveWidget w;

	JiveSurface *bg;
	JiveSurface *img;
	JiveSurface *cap1;
	JiveSurface *cap2;
	bool horizontal;
} SliderWidget;


static JivePeerMeta sliderPeerMeta = {
	sizeof(SliderWidget),
	"JiveSlider",
	jiveL_slider_gc,
};


int jiveL_slider_pack(lua_State *L) {
	SliderWidget *peer;
	JiveSurface *bg, *img, *cap1, *cap2;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &sliderPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	/* slider background */
	bg = jive_style_image(L, 1, "bgImg", NULL);
	if (peer->bg != bg) {
		if (peer->bg) {
			jive_surface_free(peer->bg);
		}

		peer->bg = jive_surface_ref(bg);
	}

	/* vertial or horizontal */
	peer->horizontal = jive_style_int(L, 1, "horizontal", 1);

	/* slider bubble */
	img = jive_style_image(L, 1, "img", NULL);
	if (peer->img != img) {
		if (peer->img) {
			jive_surface_free(peer->img);
		}

		peer->img = jive_surface_ref(img);
	}

	cap1 = jive_style_image(L, 1, "cap1", NULL);
	if (peer->cap1 != cap1) {
		if (peer->cap1) {
			jive_surface_free(peer->cap1);
		}

		peer->cap1 = jive_surface_ref(cap1);
	}

	cap2 = jive_style_image(L, 1, "cap2", NULL);
	if (peer->cap2 != cap2) {
		if (peer->cap2) {
			jive_surface_free(peer->cap2);
		}

		peer->cap2 = jive_surface_ref(cap2);
	}

	return 0;
}


int jiveL_slider_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	SliderWidget *peer = jive_getpeer(L, 1, &sliderPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	if (!drawLayer) {
		return 0;
	}

	if (peer->bg) {
		jive_surface_blit(peer->bg, srf, peer->w.bounds.x, peer->w.bounds.y);
	}
	if (peer->img) {
		Uint16 img_w, img_h;
		Uint16 cap1_w = 0, cap1_h = 0;
		Uint16 cap2_w = 0, cap2_h = 0;
		int height, width, range, value, size;
		int y0, y1;
		int x0, x1;

		/* bubble offset */
		jive_surface_get_size(peer->img, &img_w, &img_h);
		if (peer->cap1) {
			jive_surface_get_size(peer->cap1, &cap1_w, &cap1_h);
		}
		if (peer->cap2) {
			jive_surface_get_size(peer->cap2, &cap2_w, &cap2_h);
		}

		height = peer->w.bounds.h - peer->w.tp - peer->w.bp;
		width = peer->w.bounds.w - peer->w.lp - peer->w.rp;
	
		lua_getfield(L, 1, "range");
		range = lua_tointeger(L, -1);

		lua_getfield(L, 1, "value");
		value = lua_tointeger(L, -1);
		lua_pop(L, 2);

		lua_getfield(L, 1, "size");
		size = lua_tointeger(L, -1);
		lua_pop(L, 2);

		if (peer->horizontal) {			
			x0 = (width / (float)(range - 1)) * (value - 1);
			x1 = (width / (float)(range - 1)) * (size - 1);
			y0 = 0;
			y1 = height;
		}
		else {
			x0 = 0;
			x1 = width;
			y0 = (height / (float)(range - 1)) * (value - 1);
			y1 = (height / (float)(range - 1)) * (size - 1);
		}

		if (peer->cap1) {
			jive_surface_blit(peer->cap1, srf, peer->w.bounds.x + x0, peer->w.bounds.y + y0);
			if (peer->horizontal) {
				x0 += cap1_w;
				x1 -= cap1_w;
			}
			else {
				y0 += cap1_h;
				y1 -= cap1_h;
			}
		}
		if (peer->cap2) {
			if (peer->horizontal) {
				x1 -= cap2_w;
			}
			else {
				y1 -= cap2_h;
			}
		}

		if (x1 < 0) {
			x1 = 0;
		}
		if (y1 < 0) {
			y1 = 0;
		}

		jive_surface_blit_clip(peer->img, 0, 0, x1, y1,
				       srf, peer->w.bounds.x + x0, peer->w.bounds.y + y0);

		if (peer->cap2) {
			if (peer->horizontal) {
				jive_surface_blit(peer->cap2, srf, peer->w.bounds.x + x0 + x1, peer->w.bounds.y + y0);
			}
			else {
				jive_surface_blit(peer->cap2, srf, peer->w.bounds.x + x0, peer->w.bounds.y + y0 + y1);
			}
		}
	}

	return 0;
}


int jiveL_slider_gc(lua_State *L) {
	SliderWidget *peer;

	printf("********************* SLIDER GC\n");

	luaL_checkudata(L, 1, sliderPeerMeta.magic);

	peer = lua_touserdata(L, 1);

	if (peer->bg) {
		jive_surface_free(peer->bg);
		peer->bg = NULL;
	}
	if (peer->img) {
		jive_surface_free(peer->img);
		peer->img = NULL;
	}
	if (peer->cap1) {
		jive_surface_free(peer->cap1);
		peer->cap1 = NULL;
	}
	if (peer->cap2) {
		jive_surface_free(peer->cap2);
		peer->cap2 = NULL;
	}

	return 0;
}
