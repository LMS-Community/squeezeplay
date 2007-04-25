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
	Uint32 anim_frame;
	Uint32 anim_total;
} IconWidget;


static JivePeerMeta iconPeerMeta = {
	sizeof(IconWidget),
	"JiveIcon",
	jiveL_icon_gc,
};


int jiveL_icon_pack(lua_State *L) {
	IconWidget *peer;
	JiveSurface *img;

	int frame_width = 0, frame_rate = 0;

	/* stack is:
	 * 1: widget
	 */

	lua_pushcfunction(L, jiveL_style_path);
	lua_pushvalue(L, -2);
	lua_call(L, 1, 0);

	peer = jive_getpeer(L, 1, &iconPeerMeta);

	jive_widget_pack(L, 1, (JiveWidget *)peer);

	/* use image from widget or style */
	lua_getfield(L, 1, "image");
	if (!lua_isnil(L, -1)) {
		/* image from lua widget */
		img = tolua_tousertype(L, -1, 0);

	}
	else {
		/* image from style */
		lua_getfield(L, 1, "imgStyleName");
		if (lua_isnil(L, -1)) {
			img = jive_style_image(L, 1, "img", NULL);
		}
		else {
			img = jive_style_image(L, 1, lua_tostring(L, -1), NULL);
		}
		lua_pop(L, 1);

		frame_width = jive_style_int(L, 1, "frameWidth", -1);
		frame_rate = jive_style_int(L, 1, "frameRate", 0);
	}
	lua_pop(L, 1);

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

		/* set widget size to image size */
		if (peer->img) {
			jive_surface_get_size(peer->img, &peer->w.bounds.w, &peer->w.bounds.h);

			/* add animation handler (if animated icon) */
			if (frame_rate) {
				peer->anim_total = peer->w.bounds.w / frame_width;
				peer->w.bounds.w = frame_width;

				/* add animation handler */
				jive_getmethod(L, 1, "addAnimation");
				lua_pushvalue(L, 1);
				lua_pushcfunction(L, &jiveL_icon_animate);
				lua_pushinteger(L, frame_rate);
				lua_call(L, 3, 1);
				lua_setfield(L, 1, "_animationHandle");
			}

			jive_widget_set_bounds(L, 1, &(peer->w.bounds));
		}
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

		jive_getmethod(L, 1, "dirty");
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

	jive_surface_blit_clip(peer->img, peer->w.bounds.w * peer->anim_frame, 0, peer->w.bounds.w, peer->w.bounds.h,
			       srf, peer->w.bounds.x, peer->w.bounds.y);

	return 0;
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

