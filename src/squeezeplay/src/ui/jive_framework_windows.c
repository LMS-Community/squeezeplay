/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"

#include <SDL_syswm.h>

#ifndef WM_APPCOMMAND
#define WM_APPCOMMAND	0x0319
#endif
static int windows_filter_pump(const SDL_Event *event);

static int windows_filter_pump(const SDL_Event *event) {
	//handle multimedia button events
	if (event->type == SDL_SYSWMEVENT)
	{
		SDL_SysWMmsg *wmmsg;
		wmmsg = event->syswm.msg;
		
		if (wmmsg->msg == WM_APPCOMMAND) {
			switch (GET_APPCOMMAND_LPARAM(wmmsg->lParam)) {
				case APPCOMMAND_MEDIA_NEXTTRACK:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_FWD);
					return 0; // return non-zero, because we have handled the message (see MSDN doc)
				case APPCOMMAND_MEDIA_PREVIOUSTRACK:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_REW);
					return 0;
				case APPCOMMAND_MEDIA_PLAY_PAUSE:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_PAUSE);
					return 0;
				case APPCOMMAND_VOLUME_DOWN:
					jive_send_key_event(JIVE_EVENT_KEY_DOWN, JIVE_KEY_VOLUME_DOWN);
					jive_send_key_event(JIVE_EVENT_KEY_UP, JIVE_KEY_VOLUME_DOWN);
					return 0;
				case APPCOMMAND_VOLUME_UP:
					jive_send_key_event(JIVE_EVENT_KEY_DOWN, JIVE_KEY_VOLUME_UP);
					jive_send_key_event(JIVE_EVENT_KEY_UP, JIVE_KEY_VOLUME_UP);
					return 0;
				//todo: APPCOMMAND_MEDIA_STOP or JIVE_KEY_VOLUME_UP - do anything for these?
				default : break;
			}
		}
    }
	return 1;
}

void jive_platform_init(lua_State *L) {
	jive_sdlfilter_pump = windows_filter_pump;
}
