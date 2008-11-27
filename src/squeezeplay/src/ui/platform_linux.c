/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#ifndef __APPLE__

#include "common.h"
#include "jive.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <netinet/in.h>
#include <linux/if.h>


char *platform_get_home_dir() {
    char *dir;
    const char *home = getenv("HOME");

    dir = malloc(strlen(home) + 14);
    strcpy(dir, home);
    strcat(dir, "/.squeezeplay");

    return dir;
}

char *platform_get_mac_address() {
    struct ifreq ifr;
    struct ifreq *IFR;
    struct ifconf ifc;
    char buf[1024];
    char *macaddr = NULL;
    int s, i;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s==-1) {
        return NULL;
    }

    ifc.ifc_len = sizeof(buf);
    ifc.ifc_buf = buf;
    ioctl(s, SIOCGIFCONF, &ifc);

    IFR = ifc.ifc_req;
    for (i = ifc.ifc_len / sizeof(struct ifreq); --i >= 0; IFR++) {

        strcpy(ifr.ifr_name, IFR->ifr_name);
        if (ioctl(s, SIOCGIFFLAGS, &ifr) == 0) {
            if (! (ifr.ifr_flags & IFF_LOOPBACK)) {
                if (ioctl(s, SIOCGIFHWADDR, &ifr) == 0) {
                    //take the first found address.
                    //todo: can we be smarter about which is the correct address
                    unsigned char * ptr = (unsigned char *) ifr.ifr_hwaddr.sa_data;

		    macaddr = malloc(18);
                    sprintf(macaddr, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
                    break;
                }
            }
        }
    }

    close(s);

    return macaddr;
}

char *platform_get_arch() {
    struct utsname name;
    char *arch;

    uname(&name);

    arch = strdup(name.machine);
    return arch;
}

void platform_init(lua_State *L) {
}

#endif
