#ifndef LTCONF_H
#define LTCONF_H

#include <stdlib.h>
#include <stdio.h>
#include "pt.h"

/*-----------------------------------------------------------------------*\
* Macros do be included in EVERY Lua distribution file to be compiled.
\*-----------------------------------------------------------------------*/
/* Each lua_State holds a pointer to this structure */
typedef struct lt_extra_t {
    pthread_mutex_t *mutex;     /* exclusive access to lua_State */
    pthread_cond_t *completed;  /* signaled by completed threads */
    unsigned long active;       /* current number of active threads */
} lt_extra_t;

#undef LUAI_EXTRASPACE
#define LUAI_EXTRASPACE   sizeof(lt_extra_t *)

#define lt_back(L)        (((unsigned char *) L) - LUAI_EXTRASPACE)
#define lt_extra(L)       (*((lt_extra_t **) lt_back(L)))
#define lt_mutex(L)       (lt_extra(L)->mutex)
#define lt_completed(L)   (lt_extra(L)->completed)
#define lt_active(L)      (lt_extra(L)->active)

#undef lua_lock
#define lua_lock(L)       \
    do { \
        pthread_mutex_lock(lt_mutex(L)); \
    } while (0)

#undef lua_unlock
#define lua_unlock(L)  \
    do { \
        pthread_mutex_unlock(lt_mutex(L)); \
    } while (0)

#undef luai_userstateopen
#define luai_userstateopen(L) \
    do { \
        /* allocate all extra stuff we need */ \
        lt_extra(L) = (lt_extra_t *) malloc(sizeof(lt_extra_t)); \
        lt_mutex(L) = (pthread_mutex_t *)  malloc(pthread_mutex_sizeof()); \
        lt_completed(L) = (pthread_cond_t *) malloc(pthread_cond_sizeof()); \
        pthread_mutex_init(lt_mutex(L), NULL); \
        pthread_cond_init(lt_completed(L), NULL); \
        lt_active(L) = 0; \
    } while (0)

#undef luai_userstatewait
#define luai_userstatewait(L) \
    do { \
        pthread_mutex_lock(lt_mutex(L)); \
        /* wait until we are the only remaining thread */ \
        while (lt_active(L) > 0) { \
            pthread_cond_wait(lt_completed(L), lt_mutex(L)); \
        } \
        pthread_mutex_unlock(lt_mutex(L)); \
    } while (0)

#undef luai_userstateclose
#define luai_userstateclose(L) \
    do { \
        /* when that happens, destroy everything */ \
        pthread_mutex_unlock(lt_mutex(L)); \
        pthread_mutex_destroy(lt_mutex(L)); \
        pthread_cond_destroy(lt_completed(L)); \
        free(lt_mutex(L)); \
        free(lt_completed(L)); \
        free(lt_extra(L)); \
        lt_extra(L) = NULL; \
    } while (0)

#ifndef LUA_CORE
/*
 * FIXME This macro breaks the DLL exports for lua thread. I am not sure why
 * it's required, the application appears to work without it.
#define lua_close(L) \
    do { \
        luai_userstatewait(L); \
        (lua_close)(L); \
    } while (0)
*/
#endif

#undef luai_userstatethread
#define luai_userstatethread(L,L1)  \
    do { \
        lt_extra(L1) = lt_extra(L); \
    } while (0)

#define lt_activeup(L) \
    do { \
        lua_lock(L); \
        lt_active(L)++; \
        lua_unlock(L); \
    } while (0)

#define lt_activedown(L) \
    do { \
        lua_lock(L); \
        lt_active(L)--; \
        lua_unlock(L); \
    } while (0)

#define lt_activedownandsignal(L) \
    do { \
        lua_lock(L); \
        lt_active(L)--; \
        pthread_cond_signal(lt_completed(L)); \
        lua_unlock(L); \
    } while (0)

#endif
