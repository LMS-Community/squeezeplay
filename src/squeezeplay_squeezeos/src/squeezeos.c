/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


#include "common.h"

#include <sys/reboot.h>


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


static const struct luaL_Reg squeezeos_bsp_lib[] = {
	{ "reboot", squeezeos_reboot },
	{ "poweroff", squeezeos_poweroff },
	{ NULL, NULL }
};


int luaopen_squeezeos_bsp(lua_State *L) {
	luaL_register(L, "squeezeos.bsp", squeezeos_bsp_lib);
	return 1;
}
