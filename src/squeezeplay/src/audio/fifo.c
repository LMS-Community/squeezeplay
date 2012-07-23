/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"
#include "audio/fifo.h"

#include "valgrind.h"

//#define DEBUG_FIFO 1


/*

0  	rw	r	r	w		
1   		w			w	w
2			w			r
3
4
5				r	r

u:	0	1	2	1	2	5
f:	5	4	3	4	3	0
wrap(r):6	6	6	1	1	4  (note: can never be zero)

*/


#ifdef DEBUG_FIFO

#include <execinfo.h>

static void print_trace(void)
{
	void *array[4];
	size_t size;
	char **strings;
	size_t i;

	/* backtrace */
	size = backtrace(array, sizeof(array)/sizeof(void *));
	strings = backtrace_symbols(array, size);

	printf("Backtrack:\n");
	for (i = 0; i < size; i++) {
		printf("\t%s\n", strings[i]);
	}

	free(strings);
}

#endif



int fifo_init(struct fifo *fifo, size_t size, bool_t prio_inherit) {
#ifdef HAVE_LIBPTHREAD

#ifndef _POSIX_THREAD_PROCESS_SHARED
#error "no _POSIX_THREAD_PROCESS_SHARED"
#endif /* _POSIX_THREAD_PROCESS_SHARED */

	/* linux multi-process locking */
	pthread_mutexattr_t mutex_attr;
	pthread_condattr_t cond_attr;
	struct utsname utsname;
	int err;

	if ((err = pthread_mutexattr_init(&mutex_attr)) < 0) {
		return err;
	}
	if (prio_inherit) {
		if ((err = pthread_mutexattr_setpshared(&mutex_attr, PTHREAD_PROCESS_SHARED)) < 0) {
			return err;
		}
#ifdef _POSIX_THREAD_PRIO_INHERIT
		/* only on PREEMPT kernels */
		if ((err = uname(&utsname)) < 0) {
			return err;
		}
		if (!RUNNING_ON_VALGRIND && strstr(utsname.version, "PREEMPT") != NULL) {
			if ((err = pthread_mutexattr_setprotocol(&mutex_attr, PTHREAD_PRIO_INHERIT)) < 0) {
				return err;
			}
		}
#endif /* _POSIX_THREAD_PRIO_INHERIT */
	}
	if ((err = pthread_mutex_init(&fifo->mutex, &mutex_attr)) < 0) {
		return err;
	}

	if ((err = pthread_condattr_init(&cond_attr)) < 0) {
		return err;
	}
	if (prio_inherit) {
		if ((err = pthread_condattr_setpshared(&cond_attr, PTHREAD_PROCESS_SHARED)) < 0) {
			return err;
		}
	}
	if ((err = pthread_cond_init(&fifo->cond, &cond_attr)) < 0) {
		return err;
	}
#else
	/* cross platform locks */
	fifo->mutex = SDL_CreateMutex();
	fifo->cond = SDL_CreateCond();
#endif
	fifo->rptr = 0;
	fifo->wptr = 0;
	fifo->size = size;

	return 0;
}

void fifo_free(struct fifo *fifo) {
#ifdef HAVE_LIBPTHREAD
	/* linux multi-process locking */
	pthread_cond_destroy(&fifo->cond);
	pthread_mutex_destroy(&fifo->mutex);
#else
	/* cross platform locks */
	SDL_DestroyCond(fifo->cond);
	SDL_DestroyMutex(fifo->mutex);
#endif
	fifo->rptr = 0;
	fifo->wptr = 0;
	fifo->size = 0;
}

bool_t fifo_empty(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

	return (fifo->rptr == fifo->wptr);
}

size_t fifo_bytes_used(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

	return (fifo->wptr >= fifo->rptr) ? (fifo->wptr - fifo->rptr ) : (fifo->wptr - fifo->rptr + fifo->size);
}

size_t fifo_bytes_free(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

	return (fifo->rptr > fifo->wptr) ? (fifo->rptr - fifo->wptr - 1) : (fifo->rptr - fifo->wptr + fifo->size - 1);
}
	
size_t fifo_bytes_until_rptr_wrap(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

	return (fifo->size-fifo->rptr);
}

size_t fifo_bytes_until_wptr_wrap(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

	return (fifo->size-fifo->wptr);
}

void fifo_rptr_incby(struct fifo *fifo, size_t incby) {
	ASSERT_FIFO_LOCKED(fifo);

	if (fifo->rptr + incby == fifo->size) {
		fifo->rptr = 0;
	} else {
		fifo->rptr += incby;
	}	
}

void fifo_wptr_incby(struct fifo *fifo, size_t incby) {
	ASSERT_FIFO_LOCKED(fifo);

	if (fifo->wptr + incby == fifo->size) {
		fifo->wptr = 0;
	} else {
		fifo->wptr += incby;
	}	
}

int fifo_lock(struct fifo *fifo) {
	int r;

#ifdef DEBUG_FIFO
	if (DEBUG_FIFO > 0 ) {
		printf(">> LOCK %p\n", fifo);
		if (DEBUG_FIFO > 1) {
			print_trace();
		}
	}
#endif

#ifdef HAVE_LIBPTHREAD
	r = pthread_mutex_lock(&fifo->mutex);
#else
	r = SDL_LockMutex(fifo->mutex);
#endif

	fifo->lock++;
	return r;
}

int fifo_unlock(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

#ifdef DEBUG_FIFO
	if (DEBUG_FIFO > 0) {
		printf("<< UNLOCK %p\n", fifo);
	}
#endif

	fifo->lock--;
#ifdef HAVE_LIBPTHREAD
	/* linux multi-process locking */
	return pthread_mutex_unlock(&fifo->mutex);
#else
	/* cross platform locking */
	return SDL_UnlockMutex(fifo->mutex);
#endif
}

int fifo_signal(struct fifo *fifo) {
	ASSERT_FIFO_LOCKED(fifo);

#ifdef HAVE_LIBPTHREAD
	/* linux multi-process locking */
	return pthread_cond_signal(&fifo->cond);
#else
	/* cross platform locking */
	return SDL_CondSignal(fifo->cond);
#endif
}

int fifo_wait_timeout(struct fifo *fifo, Uint32 ms) {
#ifdef HAVE_LIBPTHREAD
	struct timeval delta;
	struct timespec abstime;
#endif
	int r;

	ASSERT_FIFO_LOCKED(fifo);
	fifo->lock--;

#ifdef HAVE_LIBPTHREAD
	/* linux multi-process locking */
	gettimeofday(&delta, NULL);

	abstime.tv_sec = delta.tv_sec + (ms/1000);
	abstime.tv_nsec = (delta.tv_usec + (ms%1000) * 1000) * 1000;
        if ( abstime.tv_nsec > 1000000000 ) {
		abstime.tv_sec += 1;
		abstime.tv_nsec -= 1000000000;
        }

	do {
		r = pthread_cond_timedwait(&fifo->cond, &fifo->mutex, &abstime);
	} while (r == EINTR);
#else
	/* cross platform locking */
	r = SDL_CondWaitTimeout(fifo->cond, fifo->mutex, ms);
#endif

	fifo->lock++;
	return 1;
}
