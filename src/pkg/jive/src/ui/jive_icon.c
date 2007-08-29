/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


typedef struct icon_widget {
	JiveWidget w;

	JiveSurface *img;
	JiveSurface *default_img;
	Uint32 anim_frame;
	Uint32 anim_total;

	Uint16 image_width;
	Uint16 image_height;

	JiveAlign align;
	Uint32 offset_x;
	Uint32 offset_y;

	int frame_width;
	int frame_rate;
} IconWidget;


static JivePeerMeta iconPeerMeta = {
	sizeof(IconWidget),
	"JiveIcon",
	jiveL_icon_gc,
};



int jiveL_icon_skin(lua_State *L) {
	IconWidget *peer;
	JiveSurface *img;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &iconPeerMeta);
	jive_widget_pack(L, 1, (JiveWidget *)peer);


	/* default image from style */
	lua_getfield(L, 1, "imgStyleName");
	if (lua_isnil(L, -1)) {
		img = jive_style_image(L, 1, "img", NULL);
	}
	else {
		img = jive_style_image(L, 1, lua_tostring(L, -1), NULL);
	}
	lua_pop(L, 1);

	if (peer->default_img != img) {
		if (peer->default_img) {
			jive_surface_free(peer->default_img);
		}

		peer->default_img = jive_surface_ref(img);
	}
	
	peer->frame_rate = jive_style_int(L, 1, "frameRate", 0);
	if (peer->frame_rate) {
		peer->frame_width = jive_style_int(L, 1, "frameWidth", -1);
	}

	peer->align = jive_style_align(L, 1, "align", JIVE_ALIGN_TOP_LEFT);
	return 0;
}


int jiveL_icon_prepare(lua_State *L) {
	IconWidget *peer;
	JiveSurface *img = NULL;

	peer = jive_getpeer(L, 1, &iconPeerMeta);

	/* use image from widget, or skin image as default */
	lua_getfield(L, 1, "image");
	if (!lua_isnil(L, -1)) {
		img = tolua_tousertype(L, -1, 0);
	}
	else {
		img = peer->default_img;
	}

	if (peer->img != img) {
		if (peer->img) {
			jive_surface_free(peer->img);
		}

		peer->img = jive_surface_ref(img);
		peer->anim_frame = 0;


		/* remove animation handler */
		lua_getfield(L, 1, "_animationHandle");
		if (!lua_isnil(L, -1)) {
			jive_getmethod(L, 1, "removeAnimation");
			lua_pushvalue(L, 1);
			lua_pushvalue(L, -3);
			lua_call(L, 2, 0);

			lua_pushnil(L);
			lua_setfield(L, 1, "_animationHandle");
		}
		lua_pop(L, 1);


		if (peer->img) {
			jive_surface_get_size(img, &peer->image_width, &peer->image_height);

			/* add animation handler (if animated icon) */
			if (peer->frame_rate) {
				peer->anim_total = peer->image_width / peer->frame_width;
				peer->image_width = peer->frame_width;

				/* add animation handler */
				jive_getmethod(L, 1, "addAnimation");
				lua_pushvalue(L, 1);
				lua_pushcfunction(L, &jiveL_icon_animate);
				lua_pushinteger(L, peer->frame_rate);
				lua_call(L, 3, 1);
				lua_setfield(L, 1, "_animationHandle");
			}
			else {
				peer->anim_total = 1;
			}
		}
	}

	return 0;
}


int jiveL_icon_layout(lua_State *L) {
	IconWidget *peer;

	/* stack is:
	 * 1: widget
	 */

	peer = jive_getpeer(L, 1, &iconPeerMeta);

	if (peer->img) {
		peer->offset_x = jive_widget_halign((JiveWidget *)peer, peer->align, peer->image_width) + peer->w.padding.left;
		peer->offset_y = jive_widget_valign((JiveWidget *)peer, peer->align, peer->image_height) + peer->w.padding.top;
	}

	return 0;
}


int jiveL_icon_animate(lua_State *L) {
	/* stack is:
	 * 1: widget
	 */

	IconWidget *peer = jive_getpeer(L, 1, &iconPeerMeta);
	if (peer->anim_total) {
		peer->anim_frame++;
		if (peer->anim_frame >= peer->anim_total) {
			peer->anim_frame = 0;
		}

		jive_getmethod(L, 1, "reDraw");
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	return 0;
}


int jiveL_icon_draw(lua_State *L) {

	/* stack is:
	 * 1: widget
	 * 2: surface
	 * 3: layer
	 */

	IconWidget *peer = jive_getpeer(L, 1, &iconPeerMeta);
	JiveSurface *srf = tolua_tousertype(L, 2, 0);
	bool drawLayer = luaL_optinteger(L, 3, JIVE_LAYER_ALL) & peer->w.layer;

	if (!drawLayer || !peer->img) {
		return 0;
	}

	jive_surface_blit_clip(peer->img, peer->image_width * peer->anim_frame, 0, peer->image_width, peer->image_height,
			       srf, peer->w.bounds.x + peer->offset_x, peer->w.bounds.y + peer->offset_y);

	return 0;
}


int jiveL_icon_get_preferred_bounds(lua_State *L) {
	IconWidget *peer;
	Uint16 w = 0;
	Uint16 h = 0;

	/* stack is:
	 * 1: widget
	 */

	if (jive_getmethod(L, 1, "doLayout")) {
		lua_pushvalue(L, 1);
		lua_call(L, 1, 0);
	}

	peer = jive_getpeer(L, 1, &iconPeerMeta);

	if (peer->img) {
		jive_surface_get_size(peer->img, &w, &h);
		w /= peer->anim_total;
		w += peer->w.padding.left + peer->w.padding.right;
	}

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


int jiveL_icon_gc(lua_State *L) {
	IconWidget *peer;

	printf("********************* ICON GC\n");

	luaL_checkudata(L, 1, iconPeerMeta.magic);

	peer = lua_touserdata(L, 1);

	if (peer->img) {
		jive_surface_free(peer->img);
		peer->img = NULL;
	}

	return 0;
}

