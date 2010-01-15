/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/
#define RUNTIME_DEBUG 1

#include "common.h"
#include "ui/jive.h"

#ifdef WITH_SPPRIVATE
#include "syna_chiral_api.h"
#endif

#include <linux/input.h>
#include <sys/time.h>
#include <time.h>



#include <netinet/in.h>
#include <linux/types.h>
#include <linux/netlink.h>


static int clearpad_event_fd = -1;
static int ir_event_fd = -1;
static int uevent_fd = -1;


/* touchpad state */
static JiveEvent clearpad_event;
static int clearpad_state = 0;
static int clearpad_max_x, clearpad_max_y;

Uint32 clearpad_down_millis = 0;

/* clearpad hold threshold 1 second - HOLD event is sent when no UP or PRESS has occurred before CLEARPAD_HOLD_TIMEOUT ms*/
#define CLEARPAD_HOLD_TIMEOUT 700

/* clearpad hold threshold  - A second HOLD event is sent when no UP or PRESS has occurred before CLEARPAD_HOLD_TIMEOUT ms*/
#define CLEARPAD_LONG_HOLD_TIMEOUT 3500

Uint32 last_change_clearpad_x = 0;
Uint32 last_change_clearpad_y = 0;

#define TIMEVAL_TO_TICKS(tv) ((tv.tv_sec * 1000) + (tv.tv_usec / 1000))

/* in ir.c */
void ir_input_code(Uint32 code, Uint32 time);
void ir_input_complete(Uint32 time);


static int handle_clearpad_events(int fd) {
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;

	int flick_y = 0;
	int flick_x = 0;

	int clearpad_x = -1;
	int clearpad_y = -1;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	memcpy(&event, &clearpad_event, sizeof(JiveEvent));

	for (i = 0; i <= rd / sizeof(struct input_event); i++) {    
		if (ev[i].type == EV_ABS) {
			Uint16 new_mouse_x;
			Uint16 new_mouse_y;
			switch (ev[i].code) {
			case ABS_X:
				new_mouse_x = (Uint16) 480 - ((ev[i].value / (double)clearpad_max_x) * 480);
				clearpad_x = ev[i].value;

				//jitter correction - for stablizing drag when finger is stopped
				if (abs(new_mouse_x - clearpad_event.u.mouse.x) == 1) {
					//movement by only one pixel, confirm finger has deviated far enough to trigger a switch
					//"far enough" is a fraction of the clearpad "distance" between mouse points
					if ( abs(ev[i].value - last_change_clearpad_x) > (.7 * clearpad_max_x/(double)480)) {
						event.u.mouse.x = new_mouse_x;
						last_change_clearpad_x = ev[i].value;
					} //else don't change x, since finger haven't deviated enough
				}
				else if (abs(new_mouse_x - clearpad_event.u.mouse.x) > 1) {
					event.u.mouse.x = new_mouse_x;
					last_change_clearpad_x = ev[i].value;
				}
				else {
					//no change
					event.u.mouse.x = new_mouse_x;
				}
				break;
			case ABS_Y:
				new_mouse_y = (Uint16) 272 - ((ev[i].value / (double)clearpad_max_y) * 272);
				clearpad_y = ev[i].value;
				
//				fprintf(stderr, "clearpad_event.u.mouse.y %d maxY %d  ev[i].value:%d y: %d fractional y: %f clearpad dev: %d required: %f \n",
//					clearpad_event.u.mouse.y, clearpad_max_y, ev[i].value, new_mouse_y, 272.0 - ((ev[i].value / (double)clearpad_max_y) * 272),
//					abs(ev[i].value - last_change_clearpad_y) , (.7 * clearpad_max_y/(double)272));

				//jitter correction - for stablizing drag when finger is stopped
				if (abs(new_mouse_y - clearpad_event.u.mouse.y) == 1) {
					//movement by only one pixel, confirm finger has traveled far enough to trigger a switch
					//"far enough" is a fraction of the clearpad "distance" between mouse points
					if ( abs(ev[i].value - last_change_clearpad_y) > (.75 * clearpad_max_y/(double)272)) {
						event.u.mouse.y = new_mouse_y;
						last_change_clearpad_y = ev[i].value;
					} //else don't change y, since finger haven't deviated enough
				}
				else if (abs(new_mouse_y - clearpad_event.u.mouse.y) > 1) {
					event.u.mouse.y = new_mouse_y;
					last_change_clearpad_y = ev[i].value;
				}
				else {
					//no change
					event.u.mouse.y = new_mouse_y;
				}

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
				flick_x = ev[i].value;
				break;
			case REL_RY:
				flick_y = ev[i].value;
				break;
			}
		}
		else if (ev[i].type == EV_SYN) {
			if (flick_x != 0) {
				if (abs(flick_x) > abs(flick_y)) { //must have more x than y component to be considered a vertical gesture
					if (flick_x > 2) {
						jive_send_gesture_event(JIVE_GESTURE_L_R);
					}
					if (flick_x < -2) {
						jive_send_gesture_event(JIVE_GESTURE_R_L);
					}
				}

				//reset flick data
				flick_x = 0;
				flick_y = 0;

			}
			else if (flick_y != 0) {

				//no y_click handling yet, so just ignore y flick data, still need to reset
				//reset flick data
				flick_x = 0;
				flick_y = 0;

			}



			/* Don't send repeated drag values when no movement or finger change occurred
			 */
			if (clearpad_state > 0 &&
			    event.u.mouse.x == clearpad_event.u.mouse.x
			    && event.u.mouse.y == clearpad_event.u.mouse.y
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

				if (clearpad_state == 0) {
					//ignore spurious up situations when clearpad stat is 0 - INIT
					continue;
				}

				event.type = (JiveEventType) JIVE_EVENT_MOUSE_UP;
				clearpad_state = 0;

                                #ifdef WITH_SPPRIVATE
//				fprintf(stderr, "    *****                            CHIRAL END\n");
				event.u.mouse.chiral_active = false;
				event.u.mouse.chiral_value = 0;
				syna_chiral_end();
                                #endif

			}
			else if (clearpad_state == 0) {
				event.type = (JiveEventType) JIVE_EVENT_MOUSE_DOWN;
				clearpad_state = 1;
				clearpad_down_millis = event.ticks;

				#ifdef WITH_SPPRIVATE
				/*
				*  Start the Chiral module.
				*/
				if(syna_chiral_start() == 0) {
					syna_chiral_set_direction(eDirectionHorizontal);
					syna_chiral_set_gain(50000);
					syna_chiral_set_min_radius(40);
					syna_chiral_set_noise_parameter(1);
					syna_chiral_set_release_change(7);
//					fprintf(stderr, "   *****      CHIRAL START\n");


				} else {
					fprintf(stderr, "   ***** CHIRAL START FAILED\n");

			        }
				#endif
			}
			else if (clearpad_state > 0) {
				event.type = (JiveEventType) JIVE_EVENT_MOUSE_DRAG;

				#ifdef WITH_SPPRIVATE
				if (clearpad_x >= 0 && clearpad_y >=0) {
					int chiral_value, chirality;
					chiral_value = syna_chiral_process_abs(clearpad_x, clearpad_y);
					chirality = syna_chiral_get_chirality();
					if (chiral_value * chirality < 0) {
						//when chirality and chiral val are opposite signs, invert the chiral value so CW is always the same direction
						chiral_value = chiral_value * -1;
					}

					//Invert chiral value polarity so CW motion is always positive
					event.u.mouse.chiral_value = -1 * chiral_value;
					if (chiral_value != 0) {
						event.u.mouse.chiral_active = true;
					}
//					fprintf(stderr, "CHIRAL CURRENT1: %d for clearpad_x: %d clearpad_y: %d in_origin:%d out_origin:%d direction:%d chirality:%d \n",  chiral_value , clearpad_x, clearpad_y, syna_chiral_get_input_origin(), syna_chiral_get_output_origin(), syna_chiral_get_direction(), syna_chiral_get_chirality());
				}
				#endif


			}

			memcpy(&clearpad_event, &event, sizeof(JiveEvent));
			jive_queue_event(&event);
		}
	}

	return 0;
}

static Uint32 bsp_get_realtime_millis() {
	Uint32 millis;
	struct timespec now;
	clock_gettime(CLOCK_REALTIME,&now);
	millis=now.tv_sec*1000+now.tv_nsec/1000000;
	return(millis);
}

static Uint32 queue_sw_event(Uint32 ticks, Uint32 code, Uint32 value) {
	JiveEvent event;

	memset(&event, 0, sizeof(JiveEvent));
	event.type = JIVE_EVENT_SWITCH;
	event.u.sw.code = code;
	event.u.sw.value = value;
	event.ticks = ticks;
	jive_queue_event(&event);

	return 0;
}

static int handle_ir_events(int fd) {
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
			//TIMEVAL_TO_TICKS doesn't not really return ticks since these ev times are jiffies, but we won't be comparing against real ticks.
			Uint32 input_time = TIMEVAL_TO_TICKS(ev[i].time);
			Uint32 ir_code = ev[i].value;

			ir_input_code(ir_code, input_time);

		} else if(ev[i].type == EV_SW) {	
			// Pass along all switch events to jive
			Uint32 input_time = TIMEVAL_TO_TICKS(ev[i].time);
			queue_sw_event(input_time, ev[i].code, ev[i].value);
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

	return ((clearpad_event_fd != -1) || (ir_event_fd != -1));
}


static int open_uevent_fd(void)
{
        struct sockaddr_nl saddr;
        const int buffersize = 16 * 1024 * 1024;
        int retval;

        memset(&saddr, 0x00, sizeof(struct sockaddr_nl));
        saddr.nl_family = AF_NETLINK;
        saddr.nl_pid = getpid();
        saddr.nl_groups = 1;

        uevent_fd = socket(PF_NETLINK, SOCK_DGRAM, NETLINK_KOBJECT_UEVENT);
        if (uevent_fd == -1) {
                fprintf(stderr, "error getting socket: %s", strerror(errno));
                return -1;
        }

        /* set receive buffersize */
        setsockopt(uevent_fd, SOL_SOCKET, SO_RCVBUFFORCE, &buffersize, sizeof(buffersize));

        retval = bind(uevent_fd, (struct sockaddr *) &saddr, sizeof(struct sockaddr_nl));
        if (retval < 0) {
                fprintf(stderr, "bind failed: %s", strerror(errno));
                close(uevent_fd);
                uevent_fd = -1;
                return -1;
        }
        return 0;
}


static void handle_uevent(lua_State *L, int sock)
{
        char *ptr, *end, buffer[2048];
        ssize_t size;

        size = recv(uevent_fd, &buffer, sizeof(buffer), 0);
        if (size <  0) {
                if (errno != EINTR)
                        printf("unable to receive kernel netlink message: %s", strerror(errno));
                return;
        }

	lua_getglobal(L, "ueventHandler");
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);
		fprintf(stderr, "No ueventHandler\n");
		return;
	}

	ptr = buffer;
	end = strchr(ptr, '\0');

	/* evt */
	lua_pushlstring(L, ptr, end-ptr);

	/* msg */
	lua_newtable(L);
	while (end + 1 < buffer + size) {
		ptr = end + 1;
		end = strchr(ptr, '=');

		lua_pushlstring(L, ptr, end-ptr);

		ptr = end + 1;
		end = strchr(ptr, '\0');

		lua_pushlstring(L, ptr, end-ptr);

		lua_settable(L, -3);
	}

	if (lua_pcall(L, 2, 0, 0) != 0) {
		fprintf(stderr, "error calling ueventHandler %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}


static int event_pump(lua_State *L) {
	fd_set fds;
	struct timeval timeout;

	Uint32 now;
	
	FD_ZERO(&fds);
	memset(&timeout, 0, sizeof(timeout));

	if (clearpad_event_fd != -1) {
		FD_SET(clearpad_event_fd, &fds);
	}
	if (ir_event_fd != -1) {
		FD_SET(ir_event_fd, &fds);
	}
	if (uevent_fd != -1) {
		FD_SET(uevent_fd, &fds);
	}

	if (select(FD_SETSIZE, &fds, NULL, NULL, &timeout) < 0) {
		perror("jivebsp:");
		return -1;
	}

	if (uevent_fd != -1 && FD_ISSET(uevent_fd, &fds)) {
		handle_uevent(L, uevent_fd);
	}

	if (clearpad_event_fd != -1 && FD_ISSET(clearpad_event_fd, &fds)) {
		handle_clearpad_events(clearpad_event_fd);
	}

	now = bsp_get_realtime_millis();

	if (ir_event_fd != -1 && FD_ISSET(ir_event_fd, &fds)) {
		handle_ir_events(ir_event_fd);
	}
	ir_input_complete(now);
	

	// check if hold should be sent
	if (clearpad_state == 1 && (now >= CLEARPAD_HOLD_TIMEOUT + clearpad_down_millis )) {
		JiveEvent event;
		//fprintf(stderr,"******************************HOLD triggered during pump check\n");

		clearpad_state = 2;

		memset(&event, 0, sizeof(JiveEvent));
		event.type = JIVE_EVENT_MOUSE_HOLD;
		event.ticks = bsp_get_realtime_millis();
		//todo: also set last mouse coords
		jive_queue_event(&event);
	}
	// check if a second hold (long hold) should be sent
	if (clearpad_state == 2 && (now >= CLEARPAD_LONG_HOLD_TIMEOUT + clearpad_down_millis )) {
		JiveEvent event;
		//fprintf(stderr,"******************************"Long" HOLD triggered during pump check\n");

		clearpad_state = 3;

		memset(&event, 0, sizeof(JiveEvent));
		event.type = JIVE_EVENT_MOUSE_HOLD;
		event.ticks = bsp_get_realtime_millis();
		//todo: also set last mouse coords
		jive_queue_event(&event);
	}

	return 0;
}


int luaopen_fab4_bsp(lua_State *L) {
	if (open_input_devices()) {
		jive_sdlevent_pump = event_pump;
	}

	open_uevent_fd();

	return 1;
}
