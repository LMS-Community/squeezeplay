/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"
#include "ui/jive.h"

#include <linux/input.h>
#include <sys/soundcard.h>


#ifndef EV_SW
#define EV_SW 0x05
#endif


static const char *bsp_devname = "/dev/misc/jive_mgmt";


static int bsp_fd = -1;
static int switch_event_fd = -1;
static int wheel_event_fd = -1;
static int motion_event_fd = -1;

static Sint16 last_x = 0;
static Sint16 last_y = 0;
static Sint16 last_z = 0;

#define TIMEVAL_TO_TICKS(tv) ((tv.tv_sec * 1000) + (tv.tv_usec / 1000))

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

			event.type = (JiveEventType) JIVE_EVENT_SWITCH;
			event.ticks = TIMEVAL_TO_TICKS(ev[i].time);
			event.u.sw.code = ev[i].code;
			event.u.sw.value = ev[i].value;
			jive_queue_event(&event);
		}
	}

	return 0;
}


static int handle_wheel_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;
	Sint16 scroll = 0, last_value = 0;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	event.type = (JiveEventType) JIVE_EVENT_SCROLL;

	for (i = 0; i < rd / sizeof(struct input_event); i++) {
		if (ev[i].type == EV_SYN) {
			event.ticks = TIMEVAL_TO_TICKS(ev[0].time);

			/* changed direction? */
			if ((scroll < 0 && last_value > 0) ||
			    (scroll > 0 && last_value < 0)
			    ) {
				event.u.scroll.rel = scroll;
				jive_queue_event(&event);

				scroll = 0;
			}

			scroll += last_value;
			last_value = 0;
		}
		else if (ev[i].type == EV_REL) {
			last_value += ev[i].value;
		}
	}

	if (scroll != 0) {
		event.u.scroll.rel = scroll;
		jive_queue_event(&event);
	}

	return 0;
}


static int handle_motion_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;
	Sint16 n = 0;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	memset(&event, 0, sizeof(JiveEvent));

	for (i = 0; i < rd / sizeof(struct input_event); i++) {
		if (ev[i].type == EV_SYN) {
			event.ticks = TIMEVAL_TO_TICKS(ev[i].time);

			n++;
			// record all values at sync
			event.u.motion.x += last_x;
			event.u.motion.y += last_y;
			event.u.motion.z += last_z;
		}
		else if (ev[i].type == EV_ABS) {
			// motion event
			// accumulate with new values and unchanged values
			switch (ev[i].code) {
			case ABS_X:
				last_x = ev[i].value;
				break;
			case ABS_Y:
				last_y = ev[i].value;
				break;
			case ABS_Z:
				last_z = ev[i].value;
				break;
			}
		}
	}

	if (n > 0) {
		event.u.motion.x /= n;
		event.u.motion.y /= n;
		event.u.motion.z /= n;
		event.type = (JiveEventType) JIVE_EVENT_MOTION;
		jive_queue_event(&event);
	}
	
	return 0;
}


#define BITS_PER_LONG (sizeof(long) * 8)
#define NBITS(x) ((((x)-1)/BITS_PER_LONG)+1)
#define OFF(x)  ((x)%BITS_PER_LONG)
#define BIT(x)  (1UL<<OFF(x))
#define LONG(x) ((x)/BITS_PER_LONG)
#define test_bit(bit, array)	((array[LONG(bit)] >> OFF(bit)) & 1)

static void open_input_devices(void) {
	char path[PATH_MAX];
	struct stat sbuf;
	unsigned long evbit[40];
	int n, fd;

	for (n=0; n<10; n++) {
		snprintf(path, sizeof(path), "/dev/input/event%d", n);

		if ((stat(path, &sbuf) != 0) | !S_ISCHR(sbuf.st_mode)) {
			continue;
		}

		if ((fd = open(path, O_RDONLY, 0)) < 0) {
			perror("open");
			continue;
		}

		if (ioctl(fd, EVIOCGBIT(0, EV_MAX), &evbit) < 0) {
			perror("ioctrl");
			close(fd);
			continue;
		}

		/* we only have limited and known hardware so
		 * the tests here don't have to be too strict.
		 */
		if (test_bit(EV_REL, evbit)) {
			wheel_event_fd = fd;
		}
		else if (test_bit(EV_ABS, evbit)) {
			motion_event_fd = fd;
		}
		else if (test_bit(EV_SW, evbit)) {
			switch_event_fd = fd;
		}
		else {
			close(fd);
		}
	}
}


static int event_pump(lua_State *L) {
	fd_set fds;
	struct timeval timeout;

	FD_ZERO(&fds);
	memset(&timeout, 0, sizeof(timeout));

	if (switch_event_fd != -1) {
		FD_SET(switch_event_fd, &fds);
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

	if (switch_event_fd != -1 && FD_ISSET(switch_event_fd, &fds)) {
		handle_switch_events(switch_event_fd);
	}

	if (wheel_event_fd != -1 && FD_ISSET(wheel_event_fd, &fds)) {
		handle_wheel_events(wheel_event_fd);
	}

	if (motion_event_fd != -1 && FD_ISSET(motion_event_fd, &fds)) {
		handle_motion_events(motion_event_fd);
	}

	return 0;
}


static const struct luaL_Reg jivebsplib[] = {
	{ "ioctl", l_jivebsp_ioctl },
	{ NULL, NULL }
};

int luaopen_jiveBSP(lua_State *L) {
	bsp_fd = open(bsp_devname, O_RDWR);
	if (bsp_fd == -1) {
		perror("jivebsp:");
	}

	open_input_devices();

	jive_sdlevent_pump = event_pump;
	luaL_register(L, "jivebsp", jivebsplib);

	return 1;
}
