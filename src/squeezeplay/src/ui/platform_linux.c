/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#ifndef __APPLE__

#include "common.h"
#include "version.h"
#include "jive.h"

#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
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


static int wdog_sem_id = -1;

/*
 * Return a watchdog id, otherwise -1 if an error happens. If nowayout
 * is true the watchdog remain active when the process exits, causing
 * a reboot.
 */
static int watchdog_sem_get(key_t key, int nowayout)
{
	struct sembuf sops[] = {
		{ 0, -1, IPC_NOWAIT },
		{ 0, 1, IPC_NOWAIT }
	};
	int sem_num;

	if (wdog_sem_id == -1) {
		wdog_sem_id = semget(key, 10, 0666 | IPC_CREAT);
		if (wdog_sem_id == -1) {
			perror("semget");
			return -1;
		}
	}

	if (!nowayout) {
		sops[0].sem_flg |= SEM_UNDO;
	}

	sem_num = 0;
	while (1) {
		sops[0].sem_num = sem_num;
		sops[1].sem_num = sem_num + 1;

		if (semop(wdog_sem_id, sops, 2) == 0) {
			return sem_num;
		}

		if (errno == EFBIG) {
			return -1;
		}

		sem_num += 2;
	}
}

/*
 * Keep the watchdog alive for count intervals.
 */
static int watchdog_sem_keepalive(int wdog_id, int count)
{
	if (semctl(wdog_sem_id, wdog_id + 1, SETVAL, count) == -1) {
		perror("semctl");
		return -1;
	}

	return 0;
}

int watchdog_get() {
	return watchdog_sem_get(1234, 0);
}


int watchdog_keepalive(int watchdog_id, int count) {
	return watchdog_sem_keepalive(watchdog_id, count);
}


static LOG_CATEGORY *log_sp;
static lua_State *Lsig = NULL;
static lua_Hook Hf = NULL;
static int Hmask = 0;
static int Hcount = 0;


static void print_trace(void)
{
	void *array[50];
	size_t size;
	char **strings;
	size_t i;
	int mapfd;

	/* backtrace */
	size = backtrace(array, sizeof(array));
	strings = backtrace_symbols(array, size);

	log_category_log(log_sp, LOG_PRIORITY_INFO, "Backtrack:");

	for (i = 0; i < size; i++) {
		log_category_log(log_sp, LOG_PRIORITY_INFO, "%s", strings[i]);
	}

	free(strings);

	/* link map */
	mapfd = open("/proc/self/maps", O_RDONLY);
	if (mapfd != -1) {
		char buf[256];
		char *ptr, *str, *end;
		ssize_t n, offset;

		log_category_log(log_sp, LOG_PRIORITY_INFO, "Memory map:");

		offset = 0;
		while ((n = read(mapfd, buf + offset, sizeof(buf) - offset)) > 0) {
			str = ptr = buf;
			end = buf + n + offset;

			while (ptr < end) {
				while (ptr < end && *ptr != '\n') ptr++;

				if (ptr < end) {
					log_category_log(log_sp, LOG_PRIORITY_INFO, "%.*s", ptr-str, str);
					ptr++;
					str = ptr;
				}
			}

			offset = end - str;
			memmove(buf, str, offset);
		}
		close (mapfd);
	}
}


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
	print_trace();

	Hf = lua_gethook(Lsig);
	Hmask = lua_gethookmask(Lsig);
	Hcount = lua_gethookcount(Lsig);

	/* set handler hook */
	lua_sethook(Lsig, quit_hook, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE, 0);
}


static void segv_handler(int signum) {
	struct sigaction sa;

	sa.sa_handler = SIG_DFL;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(signum, &sa, NULL);

	LOG_ERROR(log_sp, "SIGSEGV squeezeplay %s", JIVE_VERSION);
	print_trace();

	/* dump core */
	raise(signum);
}


void platform_init(lua_State *L) {
	struct sigaction sa;

	Lsig = L;
	log_sp = LOG_CATEGORY_GET("squeezeplay");


	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESTART;

	sa.sa_handler = quit_handler;
	sigaction(SIGQUIT, &sa, NULL);

	sa.sa_handler = segv_handler;
	sigaction(SIGSEGV, &sa, NULL);
}

#endif
