/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
** delete this line-touched to trigger auto-build
*/

#include "common.h"
#include "ui/jive.h"

#include <linux/input.h>
#include <sys/time.h>
#include <time.h>
#include <alsa/asoundlib.h>


static int msp430_event_fd = -1;
static snd_hctl_t *hctl = NULL;

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
	JiveEvent event;
	struct input_event ev[64];
	size_t rd;
	int i;
	Sint16 scroll = 0;

	rd = read(fd, ev, sizeof(struct input_event) * 64);

	if (rd < (int) sizeof(struct input_event)) {
		perror("read error");
		return -1;
	}

	event.type = (JiveEventType) JIVE_EVENT_SCROLL;

	for (i = 0; i < rd / sizeof(struct input_event); i++) {	
		Uint32 ev_time = TIMEVAL_TO_TICKS(ev[i].time);
		event.ticks = ev_time;

		if (ev[i].type == EV_MSC) {
			//TIMEVAL_TO_TICKS doesn't not really return ticks since these ev times are jiffies, but we won't be comparing against real ticks.
			Uint32 ir_code = ev[i].value;

			ir_input_code(ir_code, ev_time);

		}
		else if (ev[i].type == EV_REL) {
			if (ev[i].code == REL_WHEEL) {
				int value = -ev[i].value;
				if ((scroll < 0 && value > 0) ||
				    (scroll > 0 && value < 0)
				    ) {
					event.u.scroll.rel = scroll;
					jive_queue_event(&event);

					scroll = 0;
				}

				scroll += value;
			}
			else if (ev[i].code == REL_MISC) {
				jive_send_key_event(JIVE_EVENT_KEY_PRESS, (ev[i].value < 0) ? JIVE_KEY_VOLUME_UP : JIVE_KEY_VOLUME_DOWN, ev_time);
			}
		}
		else if (ev[i].type == EV_SW && ev[i].code == 1 /* SW_1 */) {
			event.type = (JiveEventType) JIVE_EVENT_SWITCH;
			event.ticks = TIMEVAL_TO_TICKS(ev[i].time);
			event.u.sw.code = 3; /* battery state event */
			event.u.sw.value = ev[i].value;
			jive_queue_event(&event);
		}
		// ignore EV_SYN
	}

	if (scroll != 0) {
		event.u.scroll.rel = scroll;
		jive_queue_event(&event);
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
			perror("ioctl");
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


static snd_hctl_elem_t *find_element(snd_hctl_t *hctl, snd_ctl_elem_id_t *id)
{
	snd_hctl_elem_t *elem;
	int err;

	elem = snd_hctl_find_elem(hctl, id);
	if (elem) {
		return elem;
	}

	/* try reloading the element */
	if ((err = snd_hctl_free(hctl)) != 0) {
		fprintf(stderr, "snd_hctl_free err=%d\n", err);
		return NULL;
	}

	if ((err = snd_hctl_load(hctl)) != 0) {
		fprintf(stderr, "snd_hctl_load err=%d\n", err);
		return NULL;
	}

	return snd_hctl_find_elem(hctl, id);
}


static int handle_mixer_events()
{
	snd_ctl_event_t *event;
	snd_ctl_elem_id_t *id;
	snd_ctl_elem_value_t *value;
	snd_hctl_elem_t *elem;
	JiveEvent jevent;

	/* dies with warning on GCC 4.2:
	 * snd_ctl_*_alloca(event);
	 */
	event = (snd_ctl_event_t *) alloca(snd_ctl_event_sizeof());
	memset(event, 0, snd_ctl_event_sizeof());

	value = (snd_ctl_elem_value_t *) alloca(snd_ctl_elem_value_sizeof());
	memset(value, 0, snd_ctl_elem_value_sizeof());

	id = (snd_ctl_elem_id_t *) alloca(snd_ctl_elem_id_sizeof());
	memset(id, 0, snd_ctl_elem_id_sizeof());


	snd_ctl_read(snd_hctl_ctl(hctl), event);

	if (snd_ctl_event_elem_get_mask(event) != SND_CTL_EVENT_MASK_VALUE) {
		return 0;
	}

	snd_ctl_event_elem_get_id(event, id);
	elem = find_element(hctl, id);
	if (!elem) {
		return 0;
	}

	snd_hctl_elem_read(elem, value);

	if (strcmp(snd_ctl_event_elem_get_name(event), "Headphone Switch") == 0) {
		jevent.type = JIVE_EVENT_SWITCH;
		jevent.ticks = bsp_get_realtime_millis();
		jevent.u.sw.code = 1; /* headphone detect */
		jevent.u.sw.value = snd_ctl_elem_value_get_integer(value, 0);
		jive_queue_event(&jevent);
	}
	else if (strcmp(snd_ctl_event_elem_get_name(event), "Line In Switch") == 0) {
		jevent.type = JIVE_EVENT_SWITCH;
		jevent.ticks = bsp_get_realtime_millis();
		jevent.u.sw.code = 2; /* line in detect */
		jevent.u.sw.value = snd_ctl_elem_value_get_integer(value, 0);
		jive_queue_event(&jevent);
	}

	return 0;
}


static int open_mixer(void) {
	int err;

	if ((err = snd_hctl_open(&hctl, "default", 0)) != 0) {
		fprintf(stderr, "snd_hctl_open err=%d\n", err);
		goto err0;
	}

	if ((err = snd_hctl_load(hctl)) != 0) {
		fprintf(stderr, "snd_ctl_load err=%d\n", err);
		goto err1;
	}

	return 1;

 err1:
	snd_hctl_close(hctl);
 err0:
	return 0;
}


static int event_pump(lua_State *L) {
	struct pollfd pfds[5];
	int i, nfds = 0;
	Uint32 now;

	if (msp430_event_fd != -1) {
		pfds[nfds].fd = msp430_event_fd;
		pfds[nfds].events = POLLIN;
		nfds++;
	}

	if (hctl) {
		nfds += snd_hctl_poll_descriptors(hctl, &pfds[nfds], 5 - nfds);
	}

	if (poll(pfds, nfds, 0) == -1) {
		perror("poll");
		return 0;
	}

	now = bsp_get_realtime_millis();

	for (i=0; i<nfds; i++) {
		if (pfds[i].revents == 0) {
			continue;
		}

		if (pfds[i].fd == msp430_event_fd) {
			handle_msp430_events(msp430_event_fd);
		}
		else {
			handle_mixer_events();
		}
	}

	ir_input_complete(now);

	return 0;
}


static int l_get_mixer(lua_State *L)
{
	snd_ctl_elem_id_t *id;
	snd_ctl_elem_info_t *info;
	snd_ctl_elem_value_t *value;
	snd_hctl_elem_t *elem;
	snd_ctl_t *ctl = snd_hctl_ctl(hctl);
	int i, count, e;

	/* stack is:
	 * 1: self
	 * 2: mixer name
	 */

	/* dies with warning on GCC 4.2:
	 * snd_ctl_*_alloca(event);
	 */
	id = (snd_ctl_elem_id_t *) alloca(snd_ctl_elem_id_sizeof());
	memset(id, 0, snd_ctl_elem_id_sizeof());

	info = (snd_ctl_elem_info_t *) alloca(snd_ctl_elem_info_sizeof());
	memset(info, 0, snd_ctl_elem_info_sizeof());

	value = (snd_ctl_elem_value_t *) alloca(snd_ctl_elem_value_sizeof());
	memset(value, 0, snd_ctl_elem_value_sizeof());

	/* element id */
	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, lua_tostring(L, 2));

	/* find element and info */
	elem = find_element(hctl, id);
	if (!elem) {
		return luaL_error(L, "mixer element %s not found", lua_tostring(L, 2));
	}

	snd_ctl_elem_info_set_id(info, id);
	if (snd_ctl_elem_info(ctl, info) < 0) {
		return luaL_error(L, "info element %s not found", lua_tostring(L, 2));
	}

	count = snd_ctl_elem_info_get_count(info);
	snd_hctl_elem_read(elem, value);	

	for (i=0; i<count; i++) {
		/* set value */
		switch (snd_ctl_elem_info_get_type(info)) {
		case SND_CTL_ELEM_TYPE_BOOLEAN:
			lua_pushboolean(L, snd_ctl_elem_value_get_boolean(value, i));
			break;

		case SND_CTL_ELEM_TYPE_INTEGER:
			lua_pushinteger(L, snd_ctl_elem_value_get_integer(value, i));
			break;

		case SND_CTL_ELEM_TYPE_ENUMERATED:
			e = snd_ctl_elem_value_get_enumerated(value, i);
			// FIXME return string
			lua_pushinteger(L, e);
			break;

		default:
			fprintf(stderr, "element type not supported\n");
			return 0;
		}
	}

	return count;
}


static int get_ctl_enum_item_index(snd_ctl_t *handle, snd_ctl_elem_info_t *info,
                                   const char *ptr)
{
        int items, i, len;
        const char *name;
        
        items = snd_ctl_elem_info_get_items(info);
        if (items <= 0)
                return -1;

        for (i = 0; i < items; i++) {
                snd_ctl_elem_info_set_item(info, i);
                if (snd_ctl_elem_info(handle, info) < 0)
                        return -1;
                name = snd_ctl_elem_info_get_item_name(info);
                len = strlen(name);
                if (strncmp(name, ptr, len) == 0) {
			return i;
                }
        }
        return -1;
}


static int l_set_mixer(lua_State *L)
{
	snd_ctl_elem_id_t *id;
	snd_ctl_elem_info_t *info;
	snd_ctl_elem_value_t *value;
	snd_hctl_elem_t *elem;
	snd_ctl_t *ctl = snd_hctl_ctl(hctl);
	int i, e;

	/* stack is:
	 * 1: self
	 * 2: mixer name
	 * 3: mixer value, ...
	 */

	/* dies with warning on GCC 4.2:
	 * snd_ctl_*_alloca(event);
	 */
	id = (snd_ctl_elem_id_t *) alloca(snd_ctl_elem_id_sizeof());
	memset(id, 0, snd_ctl_elem_id_sizeof());

	info = (snd_ctl_elem_info_t *) alloca(snd_ctl_elem_info_sizeof());
	memset(info, 0, snd_ctl_elem_info_sizeof());

	value = (snd_ctl_elem_value_t *) alloca(snd_ctl_elem_value_sizeof());
	memset(value, 0, snd_ctl_elem_value_sizeof());

	/* element id */
	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, lua_tostring(L, 2));

	/* find element and info */
	elem = find_element(hctl, id);
	if (!elem) {
		return luaL_error(L, "mixer element %s not found", lua_tostring(L, 2));
	}

	snd_ctl_elem_info_set_id(info, id);
	if (snd_ctl_elem_info(ctl, info) < 0) {
		return luaL_error(L, "info element %s not found", lua_tostring(L, 2));
	}

	for (i=0; i<lua_gettop(L)-2; i++) {
		/* set value */
		switch (snd_ctl_elem_info_get_type(info)) {
		case SND_CTL_ELEM_TYPE_BOOLEAN:
			snd_ctl_elem_value_set_boolean(value, i, lua_toboolean(L, i+3));
			break;

		case SND_CTL_ELEM_TYPE_INTEGER:
			snd_ctl_elem_value_set_integer(value, i, lua_tointeger(L, i+3));
			break;

		case SND_CTL_ELEM_TYPE_ENUMERATED:
			e = get_ctl_enum_item_index(ctl, info, lua_tostring(L, i+3));
			snd_ctl_elem_value_set_enumerated(value, i, e);
			break;

		default:
			fprintf(stderr, "element type not supported\n");
			return 0;
		}
	}

	snd_hctl_elem_write(elem, value);	
	return 0;
}


static const struct luaL_Reg babybsp_lib[] = {
        { "getMixer", l_get_mixer },
        { "setMixer", l_set_mixer },
        { NULL, NULL }
};


int luaopen_baby_bsp(lua_State *L) {
	if (open_input_devices() | open_mixer()) {
		jive_sdlevent_pump = event_pump;
	}

	luaL_register(L, "baby_bsp", babybsp_lib);

	return 1;
}
