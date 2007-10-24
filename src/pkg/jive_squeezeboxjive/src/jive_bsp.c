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
static const char *wheel_event_devname = "/dev/input/event2";
static const char *motion_event_devname = "/dev/input/event3";


static int bsp_fd = -1;
static int mixer_fd = -1;
static int bsp_event_fd = -1;
static int wheel_event_fd = -1;
static int motion_event_fd = -1;

static int last_x = 0;
static int last_y = 0;
static int last_z = 0;

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


static int handle_switch_events(int fd) {
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
		if (ev[i].type == EV_SW) {
			// switch event

			// XXXX update event struct when code is public
			event.type = (JiveEventType) JIVE_EVENT_SWITCH;
			event.key_code = ev[i].code;
			event.scroll_rel = ev[i].value;
			jive_queue_event(&event);
		}
	}

	return 0;
}


static int handle_wheel_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i, scroll = 0;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	for (i = 0; i < rd / sizeof(struct input_event); i++) {
		if (ev[i].type == EV_REL) {
			scroll += ev[i].value;
		}
	}

	event.type = (JiveEventType) JIVE_EVENT_SCROLL;
	event.scroll_rel = scroll;
	jive_queue_event(&event);

	return 0;
}


static int handle_motion_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i, n;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	// update event struct for motion
	n = 0;
	event.mouse_x = 0;
	event.mouse_y = 0;
	event.scroll_rel = 0;

	for (i = 0; i < rd / sizeof(struct input_event); i++) {
		if (ev[i].type == EV_SYN) {
			n++;
		}
		else if (ev[i].type == EV_ABS) {
			// motion event
			// accumulate with new values and unchanged values
			switch (ev[i].code) {
			
			case ABS_X:
				event.mouse_x += (Sint16) ev[i].value;
				event.mouse_y += last_y;
				event.scroll_rel += last_z;
				last_x = (Sint16) ev[i].value;
				break;
			case ABS_Y:
				event.mouse_x += last_x;
				event.mouse_y += (Sint16) ev[i].value;
				event.scroll_rel += last_z;
				last_y = (Sint16) ev[i].value;
				break;
			case ABS_Z:
				event.mouse_x += last_x;
				event.mouse_y += last_y;
				event.scroll_rel += (Sint16) ev[i].value;
				last_z = (Sint16) ev[i].value;
				break;
			}
		}
	}

	if (n > 0) {
		event.mouse_x /= n;
		event.mouse_y /= n;
		event.scroll_rel /= n;
		event.type = (JiveEventType) JIVE_EVENT_MOTION;
		jive_queue_event(&event);
	}
	
	return 0;
}


static int event_pump(lua_State *L) {
	fd_set fds;
	struct timeval timeout;

	FD_ZERO(&fds);
	memset(&timeout, 0, sizeof(timeout));

	if (bsp_event_fd != -1) {
		FD_SET(bsp_event_fd, &fds);
	}

	if (wheel_event_fd != -1) {
		FD_SET(wheel_event_fd, &fds);
	}

	if (motion_event_fd != -1) {
		FD_SET(motion_event_fd, &fds);
	}

	if (select(FD_SETSIZE, &fds, NULL, NULL, &timeout) < 0) {
		perror("jivebsp:");
		return -1;
	}

	if (bsp_event_fd != -1 && FD_ISSET(bsp_event_fd, &fds)) {
		handle_switch_events(bsp_event_fd);
	}

	if (wheel_event_fd != -1 && FD_ISSET(wheel_event_fd, &fds)) {
		handle_wheel_events(wheel_event_fd);
	}

	if (motion_event_fd != -1 && FD_ISSET(motion_event_fd, &fds)) {
		handle_motion_events(motion_event_fd);
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

	if ((wheel_event_fd = open(wheel_event_devname, O_RDONLY)) < 0) {
		perror("jivebsp:");
	}

	if ((motion_event_fd = open(motion_event_devname, O_RDONLY)) < 0) {
		perror("jivebsp motion:");
	}

	jive_sdlevent_pump = event_pump;

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
