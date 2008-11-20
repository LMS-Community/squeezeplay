/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#ifdef __APPLE__

#include "common.h"
#include "jive.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#include <net/if_types.h>

static void osx_get_app_home_dir(char *path);
void osx_get_mac_address(char *address);

static void osx_get_app_home_dir(char *path) {
    const char *home = getenv("HOME");
    strcpy(path, home);
    strcat(path, "/Library/Preferences/SqueezePlay");
}

void osx_get_mac_address(char *address) {
    struct ifaddrs* ifaphead;
    struct ifaddrs* ifap;
    if ( getifaddrs( &ifaphead ) != 0 )
      return;
    
    // iterate over the net interfaces
    for ( ifap = ifaphead; ifap; ifap = ifap->ifa_next )
    {
        struct sockaddr_dl* sdl = (struct sockaddr_dl*)ifap->ifa_addr;
        if ( sdl && ( sdl->sdl_family == AF_LINK ) && ( sdl->sdl_type == IFT_ETHER ))
        {
            //take the first found address. 
            //todo: can we be smarter about which is the correct address
            unsigned char * ptr = (unsigned char *)LLADDR(sdl);
            sprintf(address, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
            break;
        }
    }
    
    freeifaddrs( ifaphead );
}


void jive_platform_init(lua_State *L) {
	get_app_home_dir_platform = osx_get_app_home_dir;
	get_mac_address = osx_get_mac_address;
}

#endif


