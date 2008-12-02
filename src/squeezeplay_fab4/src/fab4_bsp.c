/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "jive.h"

#include <linux/input.h>


static int clearpad_event_fd = -1;
static int ir_event_fd = -1;

/* touchpad state */
static JiveEvent clearpad_event;
static int clearpad_state = 0;
static int clearpad_max_x, clearpad_max_y;


#define TIMEVAL_TO_TICKS(tv) ((tv.tv_sec * 1000) + (tv.tv_usec / 1000))


static int handle_clearpad_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	memcpy(&event, &clearpad_event, sizeof(JiveEvent));

	for (i = 0; i <= rd / sizeof(struct input_event); i++) {    
		if (ev[i].type == EV_ABS) {
			switch (ev[i].code) {
			case ABS_X:
				event.u.mouse.x = (Uint16) 480 - ((ev[i].value / (double)clearpad_max_x) * 480);
				break;
			case ABS_Y:
				event.u.mouse.y = (Uint16) 272 - ((ev[i].value / (double)clearpad_max_y) * 272);
				break;
			case ABS_MISC: /* finger_count */
				event.u.mouse.finger_count = ev[i].value;
				break;
			case ABS_PRESSURE:
				event.u.mouse.finger_pressure = ev[i].value;
				break;
			case ABS_TOOL_WIDTH:
				event.u.mouse.finger_width = ev[i].value;
				break;
			}


		}
		else if (ev[i].type == EV_REL) {
			// FIXME just temporary until we've worked out
			// how to handle gestures correctly
			switch (ev[i].code) {
			case REL_RX:
				if (ev[i].value > 0) {
					JiveEvent event;

					event.type = (JiveEventType) JIVE_EVENT_KEY_PRESS;
					event.u.key.code = JIVE_KEY_BACK;
					event.ticks = TIMEVAL_TO_TICKS(ev[i].time);
					jive_queue_event(&event);
				}
				break;
			}
		}
		else if (ev[i].type == EV_SYN) {
			/* We must move more than 10 pixels to enter a 
			 * finger drag.
			 */
			if (clearpad_state == 1 &&
			    abs(event.u.mouse.x - clearpad_event.u.mouse.x) < 10
			    && abs(event.u.mouse.y - clearpad_event.u.mouse.y) < 10
			    && event.u.mouse.finger_count == clearpad_event.u.mouse.finger_count
			    ) {
				continue;
			}

			event.ticks = TIMEVAL_TO_TICKS(ev[i].time);

			if (event.u.mouse.finger_count == 0) {
				if (clearpad_state == 1) {
					event.type = (JiveEventType) JIVE_EVENT_MOUSE_PRESS;
					jive_queue_event(&event);
				}

				event.type = (JiveEventType) JIVE_EVENT_MOUSE_UP;
				clearpad_state = 0;
			}
			else if (clearpad_state == 0) {
				event.type = (JiveEventType) JIVE_EVENT_MOUSE_DOWN;
				clearpad_state = 1;
			}
			else if (clearpad_state == 1) {
				event.type = (JiveEventType) JIVE_EVENT_MOUSE_DRAG;
				clearpad_state = 3;
			}

			memcpy(&clearpad_event, &event, sizeof(JiveEvent));
			jive_queue_event(&event);
		}
	}

	return 0;
}


static int handle_ir_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	for (i = 0; i <= rd / sizeof(struct input_event); i++) {    
		if (ev[i].type == EV_MSC) {
			event.type = (JiveEventType) JIVE_EVENT_IR_PRESS;
			event.u.ir.code = ev[i].value;
			event.ticks = TIMEVAL_TO_TICKS(ev[i].time);
			jive_queue_event(&event);
		}
		// ignore EV_SYN
	}

	return 0;
}

static int open_input_devices(void) {
	char path[PATH_MAX];
	struct stat sbuf;
	char name[254];
	int n, fd, abs[5];

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

		if (strstr(name, "ClearPad")) {
			clearpad_event_fd = fd;

			ioctl(fd, EVIOCGABS(ABS_X), abs);
			clearpad_max_x = abs[2]; 

			ioctl(fd, EVIOCGABS(ABS_Y), abs);
			clearpad_max_y = abs[2];
		}
		else if (strstr(name, "FAB4 IR")) {
			ir_event_fd = fd;
		}
		else {
			close(fd);
		}
	}

	return (clearpad_event_fd != -1);
}


static int event_pump(lua_State *L) {
	fd_set fds;
	struct timeval timeout;

	FD_ZERO(&fds);
	memset(&timeout, 0, sizeof(timeout));

	if (clearpad_event_fd != -1) {
		FD_SET(clearpad_event_fd, &fds);
	}
	if (ir_event_fd != -1) {
		FD_SET(ir_event_fd, &fds);
	}

	if (select(FD_SETSIZE, &fds, NULL, NULL, &timeout) < 0) {
		perror("jivebsp:");
		return -1;
	}

	if (clearpad_event_fd != -1 && FD_ISSET(clearpad_event_fd, &fds)) {
		handle_clearpad_events(clearpad_event_fd);
	}

	if (ir_event_fd != -1 && FD_ISSET(ir_event_fd, &fds)) {
		handle_ir_events(ir_event_fd);
	}

	return 0;
}


int luaopen_fab4_bsp(lua_State *L) {
	if (open_input_devices()) {
		jive_sdlevent_pump = event_pump;
	}

	return 1;
}
