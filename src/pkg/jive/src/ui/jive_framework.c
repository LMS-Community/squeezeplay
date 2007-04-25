/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


char *jive_resource_path = NULL;

SDL_Rect jive_dirty_region;


/* Frame rate calculations */
static Uint32 framecount = 0;
static Uint32 frameepoch = 0;
static float framerate = (1000.0f / JIVE_FRAME_RATE);


/* button hold threshold 2 seconds */
#define HOLD_TIMEOUT 2000

static JiveSurface *jive_background = NULL;

struct jive_keymap {
	SDLKey keysym;
	JiveKey keycode;
};

static enum jive_key_state {
	KEY_STATE_NONE,
	KEY_STATE_DOWN,
	KEY_STATE_SENT,
} key_state;

static JiveKey key_mask;

static SDL_TimerID key_timer;

static struct jive_keymap keymap[] = {
	{ SDLK_RIGHT,		JIVE_KEY_GO },
	{ SDLK_RETURN,		JIVE_KEY_GO },
	{ SDLK_LEFT,		JIVE_KEY_BACK },
	{ SDLK_i,		JIVE_KEY_UP },
	{ SDLK_k,		JIVE_KEY_DOWN },
	{ SDLK_j,		JIVE_KEY_LEFT },
	{ SDLK_l,		JIVE_KEY_RIGHT },
	{ SDLK_p,		JIVE_KEY_PLAY },
	{ SDLK_x,		JIVE_KEY_PLAY },
	{ SDLK_c,		JIVE_KEY_PAUSE },
	{ SDLK_SPACE,		JIVE_KEY_PAUSE },
	{ SDLK_a,		JIVE_KEY_ADD },
	{ SDLK_z,		JIVE_KEY_REW },
	{ SDLK_LESS,		JIVE_KEY_REW },
	{ SDLK_b,		JIVE_KEY_FWD },
	{ SDLK_GREATER,		JIVE_KEY_FWD },
	{ SDLK_PLUS,		JIVE_KEY_VOLUME_UP },
	{ SDLK_EQUALS,		JIVE_KEY_VOLUME_UP },
	{ SDLK_MINUS,		JIVE_KEY_VOLUME_DOWN },
	{ SDLK_UNKNOWN,		JIVE_KEY_NONE },
};


static int process_event(lua_State *L, SDL_Event *event);
int jiveL_update_screen(lua_State *L);



static int jiveL_init(lua_State *L) {
	SDL_Rect r;
	JiveSurface *srf;
	int bpp;
	char *ptr;
	const char *lua_path;


	/* screen properties */
	lua_getfield(L, 1, "screen");
	if (lua_isnil(L, -1)) {
		luaL_error(L, "Framework.screen is ni");
	}

	lua_getfield(L, -1, "bounds");
	jive_torect(L, -1, &r);
	lua_pop(L, 1);

	lua_getfield(L, -1, "bpp");
	bpp = luaL_optint(L, -1, 16);
	lua_pop(L, 1);

	/* initialise SDL */
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
		fprintf(stderr, "SDL_Init(V|T|A): %s\n", SDL_GetError());
		SDL_Quit();
		exit(-1);
	}

	SDL_WM_SetCaption("Jive", "Jive");

	srf = jive_surface_set_video_mode(r.w, r.h, bpp);
	if (!srf) {
		SDL_Quit();
		exit(-1);
	}

	SDL_ShowCursor (SDL_DISABLE);
	SDL_EnableKeyRepeat (100, 100);

	tolua_pushusertype(L, srf, "Surface");
	lua_setfield(L, -2, "surface");


	/* background image */
	jive_background = jive_surface_newRGB(r.w, r.h);


	/* jive.ui.style = {} */
	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");
	lua_newtable(L);
	lua_setfield(L, -2, "style");
	lua_pop(L, 2);


	/* set jiveui_path from lua path */
	lua_getglobal(L, "package");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 0;
	}
	
	lua_getfield(L, -1, "path");
	if (!lua_isstring(L, -1)) {
		lua_pop(L, 2);
		return 0;
	}

	lua_path = lua_tostring(L, -1);

	if (jive_resource_path) {
		free(jive_resource_path);
	}
	jive_resource_path = malloc(strlen(lua_path) + 1);

	/* convert from lua path into jive path */
	ptr = jive_resource_path;
	while (*lua_path) {
		switch (*lua_path) {
		case '?':
			while (*lua_path && *lua_path != ';') {
				lua_path++;
			}
			break;
			
		case ';':
			*ptr++ = ';';
			while (*lua_path && *lua_path == ';') {
				lua_path++;
			}
			break;
			
		default:
			*ptr++ = *lua_path++;
		}
	}
	*ptr = '\0';
	
	lua_pop(L, 2);

	return 0;
}


static int jiveL_quit(lua_State *L) {

	/* de-reference all windows */
	jiveL_getframework(L);
	lua_pushnil(L);
	lua_setfield(L, -2, "windowStack");
	lua_pop(L, 1);

	/* force lua GC */
	lua_gc(L, LUA_GCCOLLECT, 0);

	free(jive_resource_path);

	/* quit SDL */
	SDL_Quit();

	return 0;
}


static int jiveL_process_events(lua_State *L) {
	Uint32 ticks, frameticks;

	/* stack:
	 * 1 : jive.ui.Framework
	 */

	frameepoch = SDL_GetTicks();

	/* FIXME check we have Framework */

	while (1) {
		Uint32 r = 0;

		JIVEL_STACK_CHECK_BEGIN(L);

		/* Exit if we have no windows */
		lua_getfield(L, 1, "windowStack");
		if (lua_objlen(L, -1) == 0) {
			lua_pop(L, 1);
			return 0;
		}
		lua_rawgeti(L, -1, 1);


		/* Process an event from SDL */
		ticks = SDL_GetTicks();
		frameticks = frameepoch + (Uint32)(framecount * framerate);

		if (ticks > frameticks) {
			printf("Dropped frames. framerate=%dms delay=%dms\n", (Uint32)framerate, (ticks - frameticks));
			frameepoch = ticks;
			framecount = 0;
		}

		do {
			SDL_Event event;
			if (SDL_PollEvent(&event)) {
				r |= process_event(L, &event);
			}

			ticks = SDL_GetTicks();
			if (ticks < frameticks) {
				SDL_Delay(10);
			}
		} while (ticks < frameticks);
		
		lua_pop(L, 2);

		JIVEL_STACK_CHECK_END(L);


		/* Draw the top window. */
		jiveL_update_screen(L);


		if (r & JIVE_EVENT_QUIT) {
			return 0;
		}
	}

	return 0;
}


int jiveL_update_screen(lua_State *L) {
	JiveSurface *srf;

	JIVEL_STACK_CHECK_BEGIN(L);

	/* stack is:
	 * 1: framework
	 * 2: screen surface
	 */

	lua_getfield(L, 1, "screen");
	lua_getfield(L, -1, "surface");
	srf = tolua_tousertype(L, -1, 0);
	lua_replace(L, -2);


	/* Exit if we have no windows. We need to check
	 * again as the event handlers may have changed
	 * the window stack */
	lua_getfield(L, 1, "windowStack");
	if (lua_objlen(L, -1) == 0) {
		lua_pop(L, 1);

		JIVEL_STACK_CHECK_ASSERT(L);
		return 0;
	}
	lua_rawgeti(L, -1, 1);

	/* Check if the window needs layout */
	lua_getfield(L, -1, "layoutCount");
	lua_getfield(L, 1, "layoutCount");
	if (!lua_equal(L, -1, -2)) {
		printf("PACKING...\n");
		if (jive_getmethod(L, -3, "pack")) {
			lua_pushvalue(L, -4);	// widget
			lua_call(L, 1, 0);
		}

		lua_pushvalue(L, 1);
		lua_pushnil(L);
		jiveL_dirty(L);
		lua_pop(L, 2);
	}
	lua_pop(L, 2);


	/* Draw screen */
	framecount++;


	/* Widget animations */
	lua_getfield(L, 1, "animations");
	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		lua_getfield(L, -1, "animations");
		lua_pushnil(L);
		while (lua_next(L, -2) != 0) {
			int frame;

			/* stack is:
			 * -2: key
			 * -1: table
			 */
			lua_rawgeti(L, -1, 2);
			frame = lua_tointeger(L, -1) - 1;

			if (frame == 0) {
				lua_rawgeti(L, -2, 1); // function
				lua_pushvalue(L, -6); // widget
				lua_call(L, 1, 0);
				// function is poped by lua_call
				
				lua_rawgeti(L, -2, 3);
				lua_rawseti(L, -3, 2);
			}
			else {
				lua_pushinteger(L, frame);
				lua_rawseti(L, -3, 2);
			}
			lua_pop(L, 2);
		}
		lua_pop(L, 2);
	}
	lua_pop(L, 1);


	/* Window transitions */
	lua_getfield(L, 1, "transition");
	if (!lua_isnil(L, -1)) {
		/* Draw background */
		jive_surface_set_clip(srf, NULL);
		jive_surface_blit(jive_background, srf, 0, 0);
		
		/* Animate screen transition */
		lua_pushvalue(L, -1);
		lua_pushvalue(L, -3);  	// widget
		lua_pushvalue(L, 2);	// surface
		lua_call(L, 2, 0);
		
		jive_surface_flip(srf);
	}
	else if (jive_dirty_region.w) {
		printf("REDRAW: %d,%d %dx%d\n", jive_dirty_region.x, jive_dirty_region.y, jive_dirty_region.w, jive_dirty_region.h);

		// FIXME using the clip area does not work with 
		// double buffering
		//SDL_SetClipRect(srf, &jive_dirty_region);
		jive_surface_set_clip(srf, NULL);

		/* Draw background */
		jive_surface_blit(jive_background, srf, 0, 0);

		/* Draw screen */
		if (jive_getmethod(L, -2, "draw")) {
			lua_pushvalue(L, -3);	// widget
			lua_pushvalue(L, 2);	// surface
			lua_pushinteger(L, JIVE_LAYER_ALL); // layer
			lua_call(L, 3, 0);
		}
		jive_dirty_region.w = 0;

		/* Flip buffer */
		jive_surface_flip(srf);
	}
	
	lua_pop(L, 4);

	JIVEL_STACK_CHECK_END(L);

	return 0;
}


int jiveL_dirty(lua_State *L) {
	SDL_Rect r;

	/* stack top:
	 * -2: framework
	 * -1: rectangle or nil
	 */

	if (lua_isnil(L, -1)) {
		lua_getfield(L, -2, "screen");
		lua_getfield(L, -1, "bounds");
		jive_torect(L, -1, &r);
		lua_pop(L, 2);
	}
	else {
		jive_torect(L, 2, &r);
	}

	if (jive_dirty_region.w) {
		jive_rect_union(&jive_dirty_region, &r, &jive_dirty_region);
	}
	else {
		memcpy(&jive_dirty_region, &r, sizeof(jive_dirty_region));
	}

	printf("DIRTY: %d,%d %dx%d\n", jive_dirty_region.x, jive_dirty_region.y, jive_dirty_region.w, jive_dirty_region.h);

	return 0;
}


void jive_push_event(JiveEvent *evt) {
	SDL_Event user_event;
	user_event.type = SDL_USEREVENT;

	user_event.user.code = JIVE_USER_EVENT_EVENT;
	user_event.user.data1 = malloc(sizeof(JiveEvent));
	memcpy(user_event.user.data1, evt, sizeof(JiveEvent));

	SDL_PushEvent(&user_event);
}


int jiveL_push_event(lua_State *L) {

	/* stack is:
	 * 1: framework
	 * 2: JiveEvent
	 */

	JiveEvent *evt = lua_touserdata(L, 2);
	jive_push_event(evt);

	return 0;
}


int jiveL_dispatch_event(lua_State *L) {
	Uint32 r = 0;

	/* stack is:
	 * 1: framework
	 * 2: widget
	 * 3: event
	 */

	// call global event listeners
	if (jive_getmethod(L, 1, "_event")) {
		lua_pushvalue(L, 1); // framework
		lua_pushvalue(L, 3); // event

		if (lua_pcall(L, 2, 1, 0) != 0) {
			fprintf(stderr, "error in event function:\n\t%s\n", lua_tostring(L, -1));
			return 0;
		}

		r |= lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

	// call widget event handler
	if (jive_getmethod(L, 2, "_event")) {
		lua_pushvalue(L, 2); // widget
		lua_pushvalue(L, 3); // event

		if (lua_pcall(L, 2, 1, 0) != 0) {
			fprintf(stderr, "error in event function:\n\t%s\n", lua_tostring(L, -1));


			return 0;
		}

		r |= lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

	lua_pushinteger(L, r);
	return 1;
}


int jiveL_get_background(lua_State *L) {
	tolua_pushusertype(L, jive_background, "Surface");
	return 1;
}

int jiveL_set_background(lua_State *L) {
	/* stack is:
	 * 1: framework
	 * 2: background image
	 */
	if (jive_background) {
		jive_surface_free(jive_background);
	}
	jive_background = jive_surface_ref(tolua_tousertype(L, 2, 0));

	lua_getfield(L, 1, "layoutCount");
	lua_pushinteger(L, lua_tointeger(L, -1) + 1);
	lua_setfield(L, 1, "layoutCount");
	lua_pop(L, 2);

	return 0;
}

int jiveL_get_ticks(lua_State *L) {
	lua_pushinteger(L, SDL_GetTicks());
	return 1;
}


int jiveL_find_file(lua_State *L) {
	/* stack is:
	 * 1: framework
	 * 2: path
	 */

	const char *path = lua_tostring(L, 2);
	char* fullpath = malloc(PATH_MAX);

	if (jive_find_file(path, fullpath)) {
		lua_pushstring(L, fullpath);
	}
	else {
		lua_pushnil(L);
	}
	free(fullpath);

	return 1;
}


int jive_find_file(const char *path, char *fullpath) {
	char *resource_path = strdup(jive_resource_path);

	char *ptr = strtok(resource_path, ";");
	while (ptr) {
		FILE *fp;
#if defined(WIN32)
		char *tmp;
#endif

		strcpy(fullpath, ptr);
		strcat(fullpath, path);

#if defined(WIN32)
		/* Convert from UNIX style paths */
		tmp = fullpath;
		while (*tmp) {
			if (*tmp == '/') {
				*tmp = '\\';
			}
			++tmp;
		}
#endif

		fp = fopen(fullpath, "r");
		if (fp) {
			fclose(fp);
			free(resource_path);
			return 1;
		}

		ptr = strtok(NULL, ";");
	}

	free(resource_path);
	printf("NOT FOUND %s\n", path);
	return 0;
}


static Uint32 keyhold_callback(Uint32 interval, void *param) {
	SDL_Event user_event;
	memset(&user_event, 0, sizeof(SDL_Event));

	user_event.type = SDL_USEREVENT;
	user_event.user.code = JIVE_USER_EVENT_KEY_HOLD;
	user_event.user.data1 = param;

	SDL_PushEvent(&user_event);

	return 0;
}

static int process_event(lua_State *L, SDL_Event *event) {
	Uint32 t0, t1;
	JiveEvent jevent;
	int r;

	memset(&jevent, 0, sizeof(JiveEvent));

	switch (event->type) {
	case SDL_QUIT:
		jiveL_quit(L);
		exit(0);
		break;

	case SDL_MOUSEBUTTONDOWN:
		/* map the mouse scroll wheel to up/down */
		if (event->button.button == SDL_BUTTON_WHEELUP) {
			jevent.type = JIVE_EVENT_SCROLL;
			--(jevent.scroll_rel);
			break;
		}
		else if (event->button.button == SDL_BUTTON_WHEELDOWN) {
			jevent.type = JIVE_EVENT_SCROLL;
			++(jevent.scroll_rel);
			break;
		}
		// Fall through

	case SDL_MOUSEBUTTONUP:
		// FIXME mouse down/up detection
		break;

	case SDL_KEYDOWN:
		if (event->key.keysym.sym == SDLK_UP) {
			jevent.type = JIVE_EVENT_SCROLL;
			--(jevent.scroll_rel);
			break;
		}
		else if (event->key.keysym.sym == SDLK_DOWN) {
			jevent.type = JIVE_EVENT_SCROLL;
			++(jevent.scroll_rel);
			break;
		}
		// Fall through

	case SDL_KEYUP: {
		struct jive_keymap *entry = keymap;
		while (entry->keysym != SDLK_UNKNOWN) {
			if (entry->keysym == event->key.keysym.sym) {
				break;
			}
			entry++;
		}
		if (entry->keysym == SDLK_UNKNOWN) {
			return 0;
		}


		if (event->type == SDL_KEYDOWN) {
			if (key_mask & entry->keycode) {
				// ignore key repeats
				return 0;
			}
			if (key_mask == 0) {
				key_state = KEY_STATE_NONE;
			}

			switch (key_state) {
			case KEY_STATE_NONE:
				key_state = KEY_STATE_DOWN;
				// fall through

			case KEY_STATE_DOWN: {
				key_mask |= entry->keycode;

				jevent.type = JIVE_EVENT_KEY_DOWN;
				jevent.key_code = entry->keycode;

				if (key_timer) {
					SDL_RemoveTimer(key_timer);
				}

				key_timer = SDL_AddTimer(HOLD_TIMEOUT, &keyhold_callback, (void *)key_mask);
				break;
			 }

			case KEY_STATE_SENT:
				break;
			}
		}
		else /* SDL_KEYUP */ {
			if (! (key_mask & entry->keycode)) {
				// ignore repeated key ups
				return 0;
			}

			switch (key_state) {
			case KEY_STATE_NONE:
				break;

			case KEY_STATE_DOWN: {
				/*
				 * KEY_PRESSED and KEY_UP events
				 */
				JiveEvent keyup;

				jevent.type = JIVE_EVENT_KEY_PRESS;
				jevent.key_code = key_mask;

				memset(&keyup, 0, sizeof(JiveEvent));
				keyup.type = JIVE_EVENT_KEY_UP;
				keyup.key_code = entry->keycode;
				jive_push_event(&keyup);

				key_state = KEY_STATE_SENT;
				break;
			}

			case KEY_STATE_SENT: {
				/*
				 * KEY_UP event
				 */
				jevent.type = JIVE_EVENT_KEY_UP;
				jevent.key_code = entry->keycode;
				break;
			}
			}

			if (key_timer) {
				SDL_RemoveTimer(key_timer);
				key_timer = NULL;
			}

			key_mask &= ~(entry->keycode);
			if (key_mask == 0) {
				key_state = KEY_STATE_NONE;
			}
		}
		break;
	}

	case SDL_USEREVENT:
		switch ( (int) event->user.code) {
		case JIVE_USER_EVENT_TIMER:
			JIVEL_STACK_CHECK_BEGIN(L);
			jive_timer_dispatch_event(L, event->user.data1);
			JIVEL_STACK_CHECK_END(L);
			return 0;

		case JIVE_USER_EVENT_KEY_HOLD:
			jevent.type = JIVE_EVENT_KEY_HOLD;
			jevent.key_code = (JiveKey) event->user.data1;
			key_state = KEY_STATE_SENT;
			break;

		case JIVE_USER_EVENT_EVENT:
			memcpy(&jevent, event->user.data1, sizeof(JiveEvent));
			free(event->user.data1);
			break;
		}
		break;

	default:
		return 0;
	}

			  
	/* Send event to lua widgets */
	r = JIVE_EVENT_UNUSED;
	lua_pushcfunction(L, jiveL_dispatch_event);
	jiveL_getframework(L);
	lua_pushvalue(L, -3);
	jive_pushevent(L, &jevent);
		
	t0 = SDL_GetTicks();

	lua_call(L, 3, 1);

	t1 = SDL_GetTicks();
	if (jevent.type & JIVE_EVENT_KEY_ALL) {
		printf("%d: EVENT type=%x key_code=%d took=%0.4fs\n", SDL_GetTicks(), jevent.type, jevent.key_code, ((double)(t1-t0))/1000);
	}
	else {
		printf("%d: EVENT type=%x took=%0.4fs\n", SDL_GetTicks(), jevent.type, ((double)(t1-t0))/1000);
	}

	r = lua_tointeger(L, -1);
	lua_pop(L, 1);

	return r;
}





static const struct luaL_Reg icon_methods[] = {
	{ "pack", jiveL_icon_pack },
	{ "draw", jiveL_icon_draw },
	{ NULL, NULL }
};

static const struct luaL_Reg label_methods[] = {
	{ "pack", jiveL_label_pack },
	{ "draw", jiveL_label_draw },
	{ NULL, NULL }
};

static const struct luaL_Reg menu_methods[] = {
	{ "pack", jiveL_menu_pack },
	{ "draw", jiveL_menu_draw },
	{ NULL, NULL }
};

static const struct luaL_Reg slider_methods[] = {
	{ "pack", jiveL_slider_pack },
	{ "draw", jiveL_slider_draw },
	{ NULL, NULL }
};

static const struct luaL_Reg textarea_methods[] = {
	{ "pack", jiveL_textarea_pack },
	{ "draw", jiveL_textarea_draw },
	{ NULL, NULL }
};

static const struct luaL_Reg widget_methods[] = {
	{ "stylePath", jiveL_style_path },
	{ "styleValue", jiveL_style_value },
	{ "styleInt", jiveL_style_value },
	{ "styleColor", jiveL_style_color },
	{ "styleImage", jiveL_style_value },
	{ "styleFont", jiveL_style_font },
	{ NULL, NULL }
};

static const struct luaL_Reg window_methods[] = {
	{ "pack", jiveL_window_pack },
	{ "draw", jiveL_window_draw },
	{ "_eventHandler", jiveL_window_event_handler },
	{ NULL, NULL }
};

static const struct luaL_Reg timer_methods[] = {
	{ "_addTimer", jiveL_timer_add_timer },
	{ "_removeTimer", jiveL_timer_remove_timer },
	{ NULL, NULL }
};

static const struct luaL_Reg event_methods[] = {
	{ "new", jiveL_event_new },
	{ "getType", jiveL_event_get_type },
	{ "getScroll", jiveL_event_get_scroll },
	{ "getKeycode", jiveL_event_get_keycode },
	{ "getMouse", jiveL_event_get_mouse },
	{ "tostring", jiveL_event_tostring },
	{ NULL, NULL }
};

static const struct luaL_Reg core_methods[] = {
	{ "init", jiveL_init },
	{ "quit", jiveL_quit },
	{ "processEvents", jiveL_process_events },
	{ "updateScreen", jiveL_update_screen },
	{ "dirty", jiveL_dirty },
	{ "pushEvent", jiveL_push_event },
	{ "dispatchEvent", jiveL_dispatch_event },
	{ "findFile", jiveL_find_file },
	{ "getTicks", jiveL_get_ticks },
	{ "getBackground", jiveL_get_background },
	{ "setBackground", jiveL_set_background },
	{ NULL, NULL }
};



static int jiveL_core_init(lua_State *L) {

	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");

	/* stack is:
	 * 1: jive table
	 * 2: ui table
	 */

	/* register methods */
	lua_getfield(L, 2, "Icon");
	luaL_register(L, NULL, icon_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Label");
	luaL_register(L, NULL, label_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Menu");
	luaL_register(L, NULL, menu_methods);
	lua_pop(L, 1);

	lua_getfield(L, -1, "Textarea");
	luaL_register(L, NULL, textarea_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Widget");
	luaL_register(L, NULL, widget_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Window");
	luaL_register(L, NULL, window_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Slider");
	luaL_register(L, NULL, slider_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Timer");
	luaL_register(L, NULL, timer_methods);
	lua_pop(L, 1);

	lua_getfield(L, -1, "Event");
	luaL_register(L, NULL, event_methods);
	lua_pop(L, 1);

	lua_getfield(L, 2, "Framework");
	luaL_register(L, NULL, core_methods);
	lua_pop(L, 1);
	
	return 0;
}

static const struct luaL_Reg core_funcs[] = {
	{ "frameworkOpen", jiveL_core_init },
	{ NULL, NULL }
};

int luaopen_jive_ui_framework(lua_State *L) {
	luaL_register(L, "jive", core_funcs);
	return 1;
}
