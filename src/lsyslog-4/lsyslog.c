/* Lua wrapper for the syslog C API
 * See syslog(3)
 */
#include <syslog.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"

#include <stdio.h>

/* openlog(ident, option[, facility]) 
 *	ident:		string
 *	option:		number, e.g. syslog.LOG_ODELAY + syslog.LOG_PID 
 *	facility:	string, one of "LOG_...", defaults to "LOG_USER"
 *
 */
static int l_openlog(lua_State *L) 
{
	static const int cfacility[] = { 
		LOG_AUTH,
		LOG_AUTHPRIV,
		LOG_CRON,
		LOG_DAEMON,
		LOG_FTP,
		LOG_KERN,
		LOG_LOCAL0,
		LOG_LOCAL1,
		LOG_LOCAL2,
		LOG_LOCAL3,
		LOG_LOCAL4,
		LOG_LOCAL5,
		LOG_LOCAL6,
		LOG_LOCAL7,
		LOG_LPR,
		LOG_MAIL,
		LOG_NEWS,
		LOG_SYSLOG,
		LOG_USER,
		LOG_UUCP
	};

	static const char *lfacility[] = { 
		"LOG_AUTH",
		"LOG_AUTHPRIV",
		"LOG_CRON",
		"LOG_DAEMON",
		"LOG_FTP",
		"LOG_KERN",
		"LOG_LOCAL0",
		"LOG_LOCAL1",
		"LOG_LOCAL2",
		"LOG_LOCAL3",
		"LOG_LOCAL4",
		"LOG_LOCAL5",
		"LOG_LOCAL6",
		"LOG_LOCAL7",
		"LOG_LPR",
		"LOG_MAIL",
		"LOG_NEWS",
		"LOG_SYSLOG",
		"LOG_USER",
		"LOG_UUCP",
		NULL
	};

	int option = luaL_checknumber(L, 2);
	int facility = cfacility[luaL_checkoption(L, 3, "LOG_USER", lfacility)];

	/* syslog() needs a pointer to the ident string that must outlive this
	 * function call */
	size_t len;
	const char *ident = luaL_checklstring(L, 1, &len);
	/* play safe and keep a copy of ident in a new userdatum, whose contents 
	 * won't be touched by Lua in any way, but let Lua manage the allocated
	 * memory */
	char *identcp = (char *)lua_newuserdata(L, len + 1);
	strcpy(identcp, ident);
	/* store it in our environment table, so that it is not garbage collected */
	lua_setfield(L, LUA_ENVIRONINDEX, "ident");

/*	printf("l_openlog(%s, %d, %d) len=%d\n", identcp, option, facility, len); */
	openlog(identcp, option, facility);
	return 0;
}

/* syslog(priority, message) 
 *	priority:	string, one of "LOG_..."
 *	message:	string
 *
 */
static int l_syslog(lua_State *L)
{
	static const int cprio[] = { 
		LOG_EMERG,
		LOG_ALERT,
		LOG_CRIT,
		LOG_ERR,
		LOG_WARNING,
		LOG_NOTICE,
		LOG_INFO,
		LOG_DEBUG
	};

	static const char *lprio[] = { 
		"LOG_EMERG",
		"LOG_ALERT",
		"LOG_CRIT",
		"LOG_ERR",
		"LOG_WARNING",
		"LOG_NOTICE",
		"LOG_INFO",
		"LOG_DEBUG",
		NULL
	};

	int priority = cprio[luaL_checkoption(L, 1, NULL, lprio)];
	const char *msg = luaL_checkstring(L, 2);	

/*	printf("l_syslog(%d, %s)\n", priority, msg); */
	syslog(priority, "%s", msg);
	return 0;
}

/* closelog() 
 *
 */
static int l_closelog(lua_State *L)
{
	/* release any memory reserved for ident in a previous call to l_openlog */
	lua_pushnil(L);
	lua_setfield(L, LUA_ENVIRONINDEX, "ident");
	closelog();
	return 0;
}

static const struct luaL_Reg mylib [] = {
	{ "openlog", l_openlog }, 
	{ "syslog", l_syslog }, 
	{ "closelog", l_closelog },
	{ NULL, NULL }
};

#define ADD_OPT(opt) \
	lua_pushnumber(L, opt); \
	lua_setfield(L, -2, #opt)

int luaopen_syslog (lua_State *L)
{
	/* create a module environment to keep the ident string */
	lua_newtable(L);
	lua_replace(L, LUA_ENVIRONINDEX);
	luaL_register(L, "syslog", mylib);
	/* add options used by openlog() to the lib table */
	ADD_OPT(LOG_CONS);
	ADD_OPT(LOG_NDELAY);
	ADD_OPT(LOG_NOWAIT);
	ADD_OPT(LOG_ODELAY);
	ADD_OPT(LOG_PERROR);
	ADD_OPT(LOG_PID);
	return 1;
}

#undef ADD_OPT
