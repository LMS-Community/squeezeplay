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
#include <netinet/in.h>
#include <linux/if.h>

static void linux_get_app_home_dir(char *path);
void linux_get_mac_address(char *address);

static void linux_get_app_home_dir(char *path) {
    const char *home = getenv("HOME");
    strcpy(path, home);
    strcat(path, "/.squeezeplay");
}
void linux_get_mac_address(char *address) {
    struct ifreq ifr;
    struct ifreq *IFR;
    struct ifconf ifc;
    char buf[1024];
    int s, i;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s==-1) {
        return ;
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
                    sprintf(address, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
                    break;
                }
            }
        }
    }

    close(s);
}

void jive_platform_init(lua_State *L) {
	get_app_home_dir_platform = linux_get_app_home_dir;
	get_mac_address = linux_get_mac_address;
}

#endif
