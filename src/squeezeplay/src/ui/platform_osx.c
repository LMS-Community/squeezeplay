/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#ifdef __APPLE__

#include "common.h"
#include "jive.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#include <net/if_types.h>


#define PREF_DIR "/Library/Preferences/SqueezePlay"

char *platform_get_home_dir() {
    char *dir;
    const char *home = getenv("HOME");

    dir = malloc(strlen(home) + strlen(PREF_DIR) + 1);
    strcpy(dir, home);
    strcat(dir, PREF_DIR);

    return dir;
}

char *platform_get_mac_address() {
    struct ifaddrs* ifaphead;
    struct ifaddrs* ifap;
    char *macaddr = NULL;
    char *utmac;

    macaddr = malloc(18);

    utmac = getenv("UTMAC");
    if (utmac)
    {
        if ( strlen(utmac) == 17 )
        {
            strncpy ( macaddr, utmac, 17 );
            macaddr[17] = '\0';
            return macaddr;
        }
    }

    /* Set a fake macaddr to start, return fake instead of NULL on error */
    sprintf(macaddr, "00:00:00:00:99:01");

    if ( getifaddrs( &ifaphead ) != 0 )
      return macaddr;
    
    // iterate over the net interfaces
    for ( ifap = ifaphead; ifap; ifap = ifap->ifa_next )
    {
        struct sockaddr_dl* sdl = (struct sockaddr_dl*)ifap->ifa_addr;
        if ( sdl && ( sdl->sdl_family == AF_LINK ) && ( sdl->sdl_type == IFT_ETHER ))
        {
            //take the first found address. 
            //todo: can we be smarter about which is the correct address
            unsigned char * ptr = (unsigned char *)LLADDR(sdl);
            sprintf(macaddr, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
            break;
        }
    }
    
    freeifaddrs( ifaphead );

    return macaddr;
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
}

#endif
