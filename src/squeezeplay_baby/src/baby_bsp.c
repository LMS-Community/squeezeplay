/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/
#define RUNTIME_DEBUG 1

#include "common.h"
#include "ui/jive.h"

#include <linux/input.h>
#include <sys/time.h>
#include <time.h>


static int msp430_event_fd = -1;

#define TIMEVAL_TO_TICKS(tv) ((tv.tv_sec * 1000) + (tv.tv_usec / 1000))


/* in ir.c */
void ir_input_code(Uint32 code, Uint32 time);
void ir_input_complete(Uint32 time);


static Uint32 bsp_get_realtime_millis() {
	Uint32 millis;
	struct timespec now;
	clock_gettime(CLOCK_REALTIME,&now);
	millis=now.tv_sec*1000+now.tv_nsec/1000000;
	return(millis);
}


static int handle_msp430_events(int fd) {
	struct input_event ev[64];
	size_t rd;
	int i;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	for (i = 0; i < rd / sizeof(struct input_event); i++) {	
		Uint32 ev_time = TIMEVAL_TO_TICKS(ev[i].time);

		if (ev[i].type == EV_MSC) {
			//TIMEVAL_TO_TICKS doesn't not really return ticks since these ev times are jiffies, but we won't be comparing against real ticks.
			Uint32 ir_code = ev[i].value;

			ir_input_code(ir_code, ev_time);

		}
		else if (ev[i].type == EV_REL) {
			if (ev[i].code == REL_WHEEL) {
				JiveEvent event;
				memset(&event, 0, sizeof(JiveEvent));
	
				event.type = JIVE_EVENT_SCROLL;
				event.ticks = ev_time;
				event.u.scroll.rel = -ev[i].value;
				jive_queue_event(&event);
			}
			else if (ev[i].code == REL_MISC) {
				jive_send_key_event(JIVE_EVENT_KEY_PRESS, (ev[i].value < 0) ? JIVE_KEY_VOLUME_UP : JIVE_KEY_VOLUME_DOWN);
			}
		}
		// ignore EV_SYN
	}

	return 0;
}


static int open_input_devices(void) {
	char path[PATH_MAX];
	struct stat sbuf;
	char name[254];
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

		if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) < 0) {
			perror("ioctrl");
			close(fd);
			continue;
		}

		if (strstr(name, "msp430")) {
			msp430_event_fd = fd;
		}
		else {
			close(fd);
		}
	}

	return (msp430_event_fd != -1);
}

static int event_pump(lua_State *L) {
	fd_set fds;
	struct timeval timeout;

	Uint32 now;
	
	FD_ZERO(&fds);
	memset(&timeout, 0, sizeof(timeout));

	if (msp430_event_fd != -1) {
		FD_SET(msp430_event_fd, &fds);
	}

	if (select(FD_SETSIZE, &fds, NULL, NULL, &timeout) < 0) {
		perror("babybsp:");
		return -1;
	}

	now = bsp_get_realtime_millis();

	if (msp430_event_fd != -1 && FD_ISSET(msp430_event_fd, &fds)) {
		handle_msp430_events(msp430_event_fd);
	}
	ir_input_complete(now);

	return 0;
}


int luaopen_baby_bsp(lua_State *L) {
	if (open_input_devices()) {
		jive_sdlevent_pump = event_pump;
	}

	return 1;
}
