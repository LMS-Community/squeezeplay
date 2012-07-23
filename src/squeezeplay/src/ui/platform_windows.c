/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"
#include "jive.h"

#include <SDL_syswm.h>
#include <intrin.h>
#include <iphlpapi.h>

#ifndef WM_APPCOMMAND
#define WM_APPCOMMAND	0x0319
#endif

char *platform_get_home_dir() {
    char *dir;
    const char *home = getenv("APPDATA");

    dir = malloc(strlen(home) + strlen("/SqueezePlay") + 1);
    strcpy(dir, home);
    strcat(dir, "/SqueezePlay");

    return dir;
}

char *platform_get_mac_address() {
    PIP_ADAPTER_INFO pAdapterInfo;
    IP_ADAPTER_INFO AdapterInfo[32];
    DWORD dwBufLen = sizeof( AdapterInfo );
    char *macaddr = NULL;
    
    DWORD dwStatus = GetAdaptersInfo( AdapterInfo, &dwBufLen );
    if ( dwStatus != ERROR_SUCCESS )
      return NULL; // no adapters.
    
    pAdapterInfo = AdapterInfo;
    while ( pAdapterInfo )
    {
        //take the first found address. 
        //todo: can we be smarter about which is the correct address
        unsigned char * ptr = (unsigned char *) pAdapterInfo->Address;
	macaddr = malloc(18);
        sprintf(macaddr, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
        break;
        //pAdapterInfo = pAdapterInfo->Next;
    }

    return macaddr;
}

static int windows_filter_pump(const SDL_Event *event) {
	//handle multimedia button events
	if (event->type == SDL_SYSWMEVENT)
	{
		SDL_SysWMmsg *wmmsg;
		wmmsg = event->syswm.msg;
		
		if (wmmsg->msg == WM_APPCOMMAND) {
			switch (GET_APPCOMMAND_LPARAM(wmmsg->lParam)) {
				case APPCOMMAND_MEDIA_NEXTTRACK:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_FWD, jive_jiffies());
					return 0; // return non-zero, because we have handled the message (see MSDN doc)
				case APPCOMMAND_MEDIA_PREVIOUSTRACK:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_REW, jive_jiffies());
					return 0;
				case APPCOMMAND_MEDIA_PLAY_PAUSE:
					jive_send_key_event(JIVE_EVENT_KEY_PRESS, JIVE_KEY_PAUSE, jive_jiffies());
					return 0;
				case APPCOMMAND_VOLUME_DOWN:
					jive_send_key_event(JIVE_EVENT_KEY_DOWN, JIVE_KEY_VOLUME_DOWN, jive_jiffies());
					jive_send_key_event(JIVE_EVENT_KEY_UP, JIVE_KEY_VOLUME_DOWN, jive_jiffies());
					return 0;
				case APPCOMMAND_VOLUME_UP:
					jive_send_key_event(JIVE_EVENT_KEY_DOWN, JIVE_KEY_VOLUME_UP, jive_jiffies());
					jive_send_key_event(JIVE_EVENT_KEY_UP, JIVE_KEY_VOLUME_UP, jive_jiffies());
					return 0;
				//todo: APPCOMMAND_MEDIA_STOP or JIVE_KEY_VOLUME_UP - do anything for these?
				default : break;
			}
		}
    }
	return 1;
}

char *platform_get_arch() {
    // FIXME
    return "unknown";
}

int watchdog_get() {
	return -1;
}

int watchdog_keepalive(int watchdog_id, int count) {
	return -1;
}

void platform_init(lua_State *L) {
	jive_sdlfilter_pump = windows_filter_pump;
}
