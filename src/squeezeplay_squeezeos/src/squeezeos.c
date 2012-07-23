/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"

#include <linux/rtc.h>
#include <sys/ioctl.h>
#include <sys/reboot.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static int squeezeos_reboot(lua_State *L)
{
	sync();
	reboot(RB_AUTOBOOT);
	return 0;
}


static int squeezeos_poweroff(lua_State *L)
{
	sync();
	reboot(RB_POWER_OFF);
	return 0;
}

/* swclock_set_epoch - Sets the kernel's software
 *  wallclock from the first argument, which is
 *  standard integer *nix time (seconds since epoch in UTC)
 */
static int squeezeos_swclock_set_epoch(lua_State *L)
{
	const unsigned int epoch_secs = lua_tointeger(L, 1);
	const struct timeval tv = { epoch_secs, 0 };
	settimeofday(&tv, NULL);
	return 0;
}

/* private to the hwclock_ funcs below */
static int _open_rtc(const int flags)
{
	int rtc_fd = open("/dev/rtc", flags);
	if(rtc_fd < 0)
		rtc_fd = open("/dev/rtc0", flags);
	if(rtc_fd < 0)
		rtc_fd = open("/dev/misc/rtc", flags);

	return rtc_fd;
}

/* hwclock_sys2hc - Sets the hardware RTC from
 *  the kernel's software wallclock time.
 *  No arguments
 *  returns true on success
 *  returns false, errmsg on failure
 */
static int squeezeos_hwclock_sys2hc(lua_State *L)
{
	int rtc_fd;
	struct timeval tv;
	struct tm tm;

	/* open the rtc device for writing */
	rtc_fd = _open_rtc(O_WRONLY);
	if(rtc_fd < 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to open RTC device for writing");
		return 2;
	}

	/* Get system wallclock as a struct tm in UTC */
	gettimeofday(&tv, NULL);
	gmtime_r(&(tv.tv_sec), &tm);

	/* use ioctl on the rtc device to set the hwclock */
	if(ioctl(rtc_fd, RTC_SET_TIME, &tm)) {
		lua_pushnil(L);
		lua_pushstring(L, "ioctl(RTC_SET_TIME) failed");
	}
	else {
		lua_pushboolean(L, 1);
		lua_pushnil(L);
	}

	close(rtc_fd);
	return 2;
}

/* hwclock_hc2sys - Sets the kernel's software
 *  wallclock time from the hardware RTC.
 *  No arguments
 *  returns true on success
 *  returns false, errmsg on failure
 */
static int squeezeos_hwclock_hc2sys(lua_State *L)
{
	int rtc_fd;
	struct timeval tv;
	struct tm tm;

	/* open rtc device for reading */
	rtc_fd = _open_rtc(O_RDONLY);
	if(rtc_fd < 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to open RTC device for reading");
		return 2;
	}

	/* use ioctl on the rtc device to read the hwclock */
	if(ioctl(rtc_fd, RTC_RD_TIME, &tm)) {
		lua_pushnil(L);
		lua_pushstring(L, "ioctl(RTC_GET_TIME) failed");
		close(rtc_fd);
		return 2;
	}

	tm.tm_isdst  = 0;
	tm.tm_gmtoff = 0;

	/* convert tm to epoch seconds and set time */
	tv.tv_sec = timegm(&tm);
	tv.tv_usec = 0;
	settimeofday(&tv, NULL);

	/* Success */
	close(rtc_fd);
	lua_pushboolean(L, 1);
	lua_pushnil(L);
	return 2;
}


/* get_timezone - Returns the current Olson
 *  timezone, e.g. "America/Chicago"
 * No input arguments.
 * Return value can be nil in case of error or
 *  if the timezone has never validly been set before.
 */
static int squeezeos_get_timezone(lua_State *L)
{
	char* buf = malloc(PATH_MAX);
	char* tzptr;

	ssize_t len = readlink("/etc/localtime", buf, PATH_MAX - 1);
	if(len >= 0) {
		buf[len] = '\0';
		tzptr = strstr(buf, "zoneinfo/");
		if(tzptr) {
			tzptr += 9;
			if(strcmp(tzptr, "Factory")) {
				lua_pushstring(L, tzptr);
				free(buf);
				return 1;
			}
		}
	}

	free(buf);
	lua_pushnil(L);
	return 1;
}


/* set_timezone - Sets the current timezone
 * The only argument is the Olson-format timezone
 *  string, e.g. "America/Chicago".
 * Returns true on success
 * Returns false, errmsg on failure
 */
static int squeezeos_set_timezone(lua_State *L)
{
	const char* tz = lua_tostring(L, 1);
	char* tzfn = malloc(21 + strlen(tz));

	if(!tzfn) {
		lua_pushnil(L);
		lua_pushstring(L, "malloc() failed");
		return 2;
	}
	strcpy(tzfn, "/usr/share/zoneinfo/");
	strcat(tzfn, tz);

	if(unlink("/etc/localtime") && errno != ENOENT) {
		free(tzfn);
		lua_pushnil(L);
		lua_pushstring(L, "Cannot unlink(/etc/localtime)");
		return 2;
	}

	if(symlink(tzfn, "/etc/localtime")) {
		free(tzfn);
		lua_pushnil(L);
		lua_pushstring(L, "symlink() to /etc/localtime failed");
		return 2;
	}

	free(tzfn);
	lua_pushboolean(L, 1);
	return 1;
}

/* kill - Send a signal to a process
 *  pid, signal (both integers)
 */
static int squeezeos_kill(lua_State *L)
{
	const int pid = lua_tointeger(L, 1);
	const int signal = lua_tointeger(L, 2);
	const int ret = kill(pid, signal);
	if (ret < 0) {
		lua_pushinteger(L, errno);
		return 1;
	} else {
		lua_pushinteger(L, 0);
		return 1;
	}
}

static const struct luaL_Reg squeezeos_bsp_lib[] = {
	{ "reboot", squeezeos_reboot },
	{ "poweroff", squeezeos_poweroff },
	{ "swclockSetEpoch", squeezeos_swclock_set_epoch },
	{ "sys2hwclock", squeezeos_hwclock_sys2hc },
	{ "hwclock2sys", squeezeos_hwclock_hc2sys },
	{ "getTimezone", squeezeos_get_timezone },
	{ "setTimezone", squeezeos_set_timezone },
	{ "kill", squeezeos_kill },
	{ NULL, NULL }
};

int luaopen_squeezeos_bsp(lua_State *L) {
	luaL_register(L, "squeezeos.bsp", squeezeos_bsp_lib);
	return 1;
}
