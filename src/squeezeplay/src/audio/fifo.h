/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#ifndef AUDIO_FIFO_H
#define AUDIO_FIFO_H


#include "common.h"


struct fifo {
#ifdef HAVE_LIBPTHREAD
	/* linux multi-process locking */
	pthread_mutex_t mutex;
	pthread_cond_t cond;
#else
	/* cross platform locking */
	SDL_mutex *mutex;
	SDL_cond *cond;
#endif
	bool_t lock;

	size_t rptr;
	size_t wptr;
	size_t size;
};

#define ASSERT_FIFO_LOCKED(fifo) assert((fifo)->lock)

extern int fifo_init(struct fifo *fifo, size_t size, bool_t prio_inherit);
extern void fifo_free(struct fifo *fifo);
extern bool_t fifo_empty(struct fifo *fifo);
extern size_t fifo_bytes_used(struct fifo *fifo);
extern size_t fifo_bytes_free(struct fifo *fifo);
extern size_t fifo_bytes_until_rptr_wrap(struct fifo *fifo);
extern size_t fifo_bytes_until_wptr_wrap(struct fifo *fifo);
extern void fifo_rptr_incby(struct fifo *fifo, size_t incby);
extern void fifo_wptr_incby(struct fifo *fifo, size_t incby);

/* fifo thread support */
extern int fifo_lock(struct fifo *fifo);
extern int fifo_unlock(struct fifo *fifo);
extern int fifo_signal(struct fifo *fifo);
extern int fifo_wait_timeout(struct fifo *fifo, Uint32 ms);


#endif // AUDIO_FIFO_H
