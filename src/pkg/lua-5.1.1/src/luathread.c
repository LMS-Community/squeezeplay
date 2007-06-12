/*======================================================================*\
* LuaThreads: multi-(platform|threading) support for the Lua language.
* Diego Nehab, 12/3/2001
* RCS Id: $Id: luathread.c 2419 2007-03-07 10:40:38Z titmuss $
\*======================================================================*/

#include <stdlib.h>

#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"

#include "pt.h"
#include "srm.h"
#include "auxiliar.h"

#include "luathread.h"

typedef struct t_states {
    lua_State *parent;
    lua_State *child;
} t_states;
typedef t_states *p_states;

static void *thread_entry(void *arg) {
    lua_State *child = (lua_State *) arg;
    int n = 1; 
    /* right now, we have the args table and the function on the stack */
    /* extract function arguments from args table */
    while (1) {
        lua_rawgeti(child, 1, n++);
        if (lua_isnil(child, -1)) break;
    }
    /* args table is garbage now */
    lua_remove(child, 1); 
    /* detach thread and invoke lua function with args */
    pthread_detach(pthread_self());
    lua_call(child, n-1, 0);
    /* kill registry reference to thread object */
    lua_pushlightuserdata(child, child);
    lua_pushnil(child);
    lua_settable(child, LUA_REGISTRYINDEX);
    /* announce the fact we are not running anymore */
    lt_activedownandsignal(child);
    pthread_cleanup(pthread_self());
    return NULL;
}

static int newthread(lua_State *parent) {
    lua_State *child = NULL;
    pthread_t thread;
    luaL_checktype(parent, 1, LUA_TFUNCTION);
    luaL_checktype(parent, 2, LUA_TTABLE);
    lua_settop(parent, 2);
    child = lua_newthread(parent);
    if (child == NULL) luaL_error(parent, "cannot create new stack");
    /* create a hard reference to the thread object into the registry */
    lua_pushlightuserdata(parent, child);
    lua_insert(parent, -2);
    lua_settable(parent, LUA_REGISTRYINDEX);
    /* move args table and function to child's stack */
    lua_xmove(parent, child, 1);
    lua_xmove(parent, child, 1);
    /* increase the count of active threads */
    lt_activeup(parent);
    /* create a new thread of execution and we are done */
    if (pthread_create(&thread, NULL, thread_entry, child) != 0) {
        /* undo lt_activeup because we failed */
        lt_activedown(parent);
        /* report our failure */
        luaL_error(parent, "cannot create new thread");
    }
    return 0;
}

static int newmutex(lua_State *L) {
    srm_t *srm = (srm_t *) lua_newuserdata(L, sizeof(srm_t)); 
    if (srm_init(srm) != 0) luaL_error(L, "unable to create mutex");
    auxiliar_setclass(L, "mutex", -1);
    return 1;
}

static int mutex_destroy(lua_State *L) {
    srm_destroy((srm_t *) lua_touserdata(L, 1));
    return 0;
}

static int mutex_lock(lua_State *L) {
    srm_t *srm = (srm_t *) auxiliar_checkclass(L, "mutex", 1);
    if (srm_lock(srm) != 0) luaL_error(L, "unable to lock mutex");
    return 0;
}

static int mutex_unlock(lua_State *L) {
    srm_t *srm = (srm_t *) auxiliar_checkclass(L, "mutex", 1);
    if (srm_unlock(srm) != 0) luaL_error(L, "unable to unlock mutex");
    return 0;
}

static int newcond(lua_State *L) {
    pthread_cond_t *cond = (pthread_cond_t *) 
        lua_newuserdata(L, pthread_cond_sizeof());
    auxiliar_setclass(L, "cond", -1);
    if (pthread_cond_init(cond, NULL) != 0)
        luaL_error(L, "unable to create cond");
    return 1;
}

static int cond_wait(lua_State *L) {
    pthread_cond_t *cond = (pthread_cond_t *) auxiliar_checkclass(L, "cond", 1);
    srm_t *srm = (srm_t *) auxiliar_checkclass(L, "mutex", 2);
    if (srm_cond_wait(cond, srm) != 0)
        luaL_error(L, "unable to wait");
    return 0;
}

static int cond_signal(lua_State *L) {
    pthread_cond_t *cond = (pthread_cond_t *) auxiliar_checkclass(L, "cond", 1);
    if (pthread_cond_signal(cond) != 0) luaL_error(L, "unable to signal");
    return 0;
}

static int cond_broadcast (lua_State *L) {
    pthread_cond_t *cond = (pthread_cond_t *) auxiliar_checkclass(L, "cond", 1);
    if (pthread_cond_broadcast(cond) != 0) luaL_error(L, "unable to broadcast");
    return 0;
}

static int cond_destroy (lua_State *L) {
    pthread_cond_destroy((pthread_cond_t *) lua_touserdata(L, 1));
    return 0;
}

static struct luaL_reg lib_ops[] = {
    {"newthread", newthread},
    {"newmutex", newmutex},
    {"newcond", newcond},
    {NULL, NULL}
};

static struct luaL_reg mutex_ops[] = {
    {"lock", mutex_lock},
    {"unlock", mutex_unlock},
    {"__gc", mutex_destroy},
    {NULL, NULL}
};

static struct luaL_reg cond_ops[] = {
    {"wait", cond_wait},
    {"signal", cond_signal},
    {"broadcast", cond_broadcast},
    {"__gc", cond_destroy},
    {NULL, NULL}
};

LUATHREAD_API int luaopen_thread_core(lua_State *L) {
    auxiliar_open(L);
    auxiliar_newclass(L, "mutex", mutex_ops);
    auxiliar_newclass(L, "cond", cond_ops);
    luaL_openlib(L,  "thread", lib_ops, 0);
    lua_pushstring(L, "_VERSION");
    lua_pushstring(L, LUATHREAD_VERSION);
    lua_settable(L, -3);
    return 1;
}
