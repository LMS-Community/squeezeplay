/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"

#include <SDL_syswm.h>
#include <intrin.h>
#include <iphlpapi.h>

#ifndef WM_APPCOMMAND
#define WM_APPCOMMAND	0x0319
#endif
static int windows_filter_pump(const SDL_Event *event);
static void windows_get_app_home_dir(char *path);
void windows_get_mac_address(char *address);

static void windows_get_app_home_dir(char *path) {
    const char *home = getenv("APPDATA");
    strcpy(path, home);
    strcat(path, "/SqueezePlay");
}

void windows_get_mac_address(char *address) {
    PIP_ADAPTER_INFO pAdapterInfo;
    IP_ADAPTER_INFO AdapterInfo[32];
    DWORD dwBufLen = sizeof( AdapterInfo );
    
    DWORD dwStatus = GetAdaptersInfo( AdapterInfo, &dwBufLen );
    if ( dwStatus != ERROR_SUCCESS )
      return; // no adapters.
    
    pAdapterInfo = AdapterInfo;
    while ( pAdapterInfo )
    {
        //take the first found address. 
        //todo: can we be smarter about which is the correct address
        unsigned char * ptr = (unsigned char *) pAdapterInfo->Address;
        sprintf(address, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
        break;
        //pAdapterInfo = pAdapterInfo->Next;
    }    
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
	get_app_home_dir_platform = windows_get_app_home_dir;
	get_mac_address = windows_get_mac_address;
}
