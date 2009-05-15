/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#ifndef __APPLE__

#include "common.h"
#include "version.h"
#include "jive.h"

#include <signal.h>
#include <syslog.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <netinet/in.h>
#include <linux/if.h>
#include <execinfo.h>


char *platform_get_home_dir() {
    char *dir;
    const char *home = getenv("HOME");

    dir = malloc(strlen(home) + 14);
    strcpy(dir, home);
    strcat(dir, "/.squeezeplay");

    return dir;
}



static char *iface_mac_address(int sock, char *name) {
    struct ifreq ifr;
    unsigned char *ptr;
    char *macaddr = NULL;

    strcpy(ifr.ifr_name, name);
    if (ioctl(sock, SIOCGIFFLAGS, &ifr) != 0) {
	return NULL;
    }

    if ((ifr.ifr_flags & IFF_LOOPBACK) == IFF_LOOPBACK) {
	return NULL;
    }

    if (ioctl(sock, SIOCGIFHWADDR, &ifr) != 0) {
	return NULL;
    }

    ptr = (unsigned char *) ifr.ifr_hwaddr.sa_data;

    macaddr = malloc(18);
    sprintf(macaddr, "%02x:%02x:%02x:%02x:%02x:%02x", *ptr,*(ptr+1), *(ptr+2),*(ptr+3), *(ptr+4), *(ptr+5));
	
    return macaddr;
}


static char *iface[] = { "eth0", "eth1", "wlan0", "wlan1" };

char *platform_get_mac_address() {
    FILE *fh;
    char buf[512], *macaddr = NULL;
    size_t i;
    int sock;


    sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        return NULL;
    }

    /* test the common interfaces first */
    for (i=0; i<sizeof(iface)/sizeof(char *); i++) {
	macaddr = iface_mac_address(sock, iface[i]);
	if (macaddr) {
	    close(sock);
	    return macaddr;
	}
    }

    /* SIOCGIFCONF does not always return interfaces without an ipv4 address
     * so we need to parse /proc/net/dev.
     */

    fh = fopen("/proc/net/dev", "r");
    if (!fh) {
	return NULL;
    }

    fgets(buf, sizeof(buf), fh); /* eat line */
    fgets(buf, sizeof(buf), fh);

    while (fgets(buf, sizeof(buf), fh)) {
	char *name, *s = buf;

	while (*s && isspace(*s)) {
	    s++;
	}
	name = s;
	while (*s && *s != ':') {
	    s++;
	}
	*s = '\0';

	macaddr = iface_mac_address(sock, name);
	if (macaddr) {
	    break;
	}
    }

    close(sock);
    fclose(fh);

    return macaddr;
}

char *platform_get_arch() {
    struct utsname name;
    char *arch;

    uname(&name);

    arch = strdup(name.machine);
    return arch;
}


static LOG_CATEGORY *log_sp;
static lua_State *Lsig = NULL;
static lua_Hook Hf = NULL;
static int Hmask = 0;
static int Hcount = 0;


static void quit_hook(lua_State *L, lua_Debug *ar) {
	/* set the old hook */
	lua_sethook(L, Hf, Hmask, Hcount);

	/* stack trace */
	lua_getglobal(L, "debug");
	lua_getfield(L, -1, "traceback");
	lua_call(L, 0, 1);

	log_sp = LOG_CATEGORY_GET("squeezeplay");

	LOG_WARN(log_sp, "%s", lua_tostring(L, -1));
}


static void quit_handler(int signum) {
	LOG_ERROR(log_sp, "SIGQUIT squeezeplay %s", JIVE_VERSION);

	Hf = lua_gethook(Lsig);
	Hmask = lua_gethookmask(Lsig);
	Hcount = lua_gethookcount(Lsig);

	/* set handler hook */
	lua_sethook(Lsig, quit_hook, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE, 0);
}


static void segv_handler(int signum) {
	LOG_ERROR(log_sp, "SIGSEGV squeezeplay %s", JIVE_VERSION);

	// TODO c stack trace

	/* dump core */
	abort();
}


void platform_init(lua_State *L) {
	Lsig = L;
	log_sp = LOG_CATEGORY_GET("squeezeplay");

	signal(SIGQUIT, quit_handler);
	signal(SIGSEGV, segv_handler);
}

#endif
