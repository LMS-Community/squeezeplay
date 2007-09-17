/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"

#include <linux/input.h>
#include <sys/soundcard.h>


#ifndef EV_SW
#define EV_SW 0x05
#endif


static const char *bsp_devname = "/dev/misc/jive_mgmt";
static const char *mixer_devname = "/dev/sound/mixer";

// XXXX these probably should be discovered based on supported events, not hard coded
static const char *bsp_event_devname = "/dev/input/event1";
static const char *motion_event_devname = "/dev/input/event3";


static int bsp_fd = -1;
static int mixer_fd = -1;
static int bsp_event_fd = -1;
static int motion_event_fd = -1;

static bool motion_update = false;
static JiveEvent motion_event;

extern int (*jive_sdlevent_handler)(lua_State *L, SDL_Event *event, JiveEvent *jevent);


static int process_event(lua_State *L, SDL_Event *event, JiveEvent *jevent) {

	// process wheel events
	switch (event->type) {
	case SDL_MOUSEMOTION:
		// mouse motion is used for scroll events
		jevent->type = JIVE_EVENT_SCROLL;
		jevent->scroll_rel = event->motion.yrel;
		return 1;
	}

	return 0;
}


static int l_jivebsp_ioctl(lua_State *L) {
	int c, v;

	/* stack is:
	 * 1: c
	 * 2: v
	 */

	if (bsp_fd == -1) {
		lua_pushstring(L, "JiveBSP device is not open");
		lua_error(L);
	}

	c = luaL_checkinteger(L, 1);
	v = luaL_optinteger(L, 2, 0);

	ioctl(bsp_fd, c, &v);

	lua_pushinteger(L, v);
	return 1;
}


static int l_jivebsp_mixer(lua_State *L) {
	unsigned int channel, l, r, volume;

	if (mixer_fd == -1) {
		lua_pushstring(L, "Mixer device is not open");
		lua_error(L);
	}

	channel = luaL_checkinteger(L, 1); // mixer
	l = luaL_checkinteger(L, 2); // left
	r = luaL_checkinteger(L, 3); // right

	if (l > 100) {
		l = 100;
	}
	if (r > 100) {
		r = 100;
	}

	volume = l | (r << 8);
	if (ioctl(mixer_fd, MIXER_WRITE(channel), &volume) == -1) {
		lua_pushstring(L, "Mixer ioctl failed");
		lua_error(L);
	}

	return 0;
}


static int handle_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	for (i = 0; i < rd / sizeof(struct input_event); i++) {
		if (ev[i].type == EV_SYN) {
			// sync event
			if (motion_update) {
				motion_update = false;

				motion_event.type = (JiveEventType) JIVE_EVENT_MOTION;
				jive_queue_event(&motion_event);
			}
		}
		else if (ev[i].type == EV_SW) {
			// switch event

			// XXXX update event struct when code is public
			event.type = (JiveEventType) JIVE_EVENT_SWITCH;
			event.key_code = ev[i].code;
			event.scroll_rel = ev[i].value;
			jive_queue_event(&event);
		}
		else if (ev[i].type == EV_ABS) {
			// motion event

			// XXXX update event struct when code is public
			motion_update = true;
			switch (ev[i].code) {
			case ABS_X:
				motion_event.mouse_x = (Sint16) ev[i].value;
				break;
			case ABS_Y:
				motion_event.mouse_y = (Sint16) ev[i].value;
				break;
			case ABS_Z:
				motion_event.scroll_rel = (Sint16) ev[i].value;
				break;
			}
		}
	}

	return 0;
}

static int event_loop(void *unused) {
	fd_set fds;

	while (1) {
		FD_ZERO(&fds);

		if (bsp_event_fd != -1) {
			FD_SET(bsp_event_fd, &fds);
		}

		if (motion_event_fd != -1) {
			FD_SET(motion_event_fd, &fds);
		}

		if (select(FD_SETSIZE, &fds, NULL, NULL, NULL) < 0) {
			perror("jivebsp:");
			return -1;
		}

		if (bsp_event_fd != -1 && FD_ISSET(bsp_event_fd, &fds)) {
			handle_events(bsp_event_fd);
		}

		if (motion_event_fd != -1 && FD_ISSET(motion_event_fd, &fds)) {
			handle_events(motion_event_fd);
		}
	}

	return 0;
}


// XXXX move this when code goes public
int jiveL_event_get_motion(lua_State *L) {
        JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
        if (event == NULL) {
                luaL_error(L, "invalid Event");
        }

        switch (event->type) {
        case (JiveEventType) JIVE_EVENT_MOTION:
                lua_pushinteger(L, (Sint16) event->mouse_x);
                lua_pushinteger(L, (Sint16) event->mouse_y);
                lua_pushinteger(L, (Sint16) event->scroll_rel);
                return 3;

        default:
                luaL_error(L, "Not a motion event");
        }
        return 0;
}


// XXXX move this when code goes public
int jiveL_event_get_switch(lua_State *L) {
        JiveEvent* event = (JiveEvent*)lua_touserdata(L, 1);
        if (event == NULL) {
                luaL_error(L, "invalid Event");
        }

        switch (event->type) {
        case (JiveEventType) JIVE_EVENT_SWITCH:
                lua_pushinteger(L, (Sint16) event->key_code);
                lua_pushinteger(L, (Sint16) event->scroll_rel);
                return 2;

        default:
                luaL_error(L, "Not a motion event");
        }
        return 0;
}


// XXXX move this when code goes public
static const struct luaL_Reg event_methods[] = {
	{ "getMotion", jiveL_event_get_motion },
	{ "getSwitch", jiveL_event_get_switch },
	{ NULL, NULL }
};


static const struct luaL_Reg jivebsplib[] = {
	{ "ioctl", l_jivebsp_ioctl },
	{ "mixer", l_jivebsp_mixer },
	{ NULL, NULL }
};

int luaopen_jiveBSP(lua_State *L) {
	bsp_fd = open(bsp_devname, O_RDWR);
	if (bsp_fd == -1) {
		perror("jivebsp:");
		goto err1;
	}

	mixer_fd = open(mixer_devname, O_RDWR);
	if (mixer_fd == -1) {
		perror("jivebsp mixer:");
		goto err2;
	}

	if ((bsp_event_fd = open(bsp_event_devname, O_RDONLY)) < 0) {
		perror("jivebsp:");
	}

	if ((motion_event_fd = open(motion_event_devname, O_RDONLY)) < 0) {
		perror("jivebsp motion:");
	}

	// additional thread to monitor events
	SDL_CreateThread(event_loop, NULL);

	// hook to allow wheel processing for SDL events
	jive_sdlevent_handler = process_event;


	// XXXX remove this when code is public
	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");
	lua_getfield(L, -1, "Event");
	luaL_register(L, NULL, event_methods);
	lua_pop(L, 2);


	luaL_register(L, "jivebsp", jivebsplib);

	return 1;

 err2:
	close(bsp_fd);

 err1:
	return 0;
}
