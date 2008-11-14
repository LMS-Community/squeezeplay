/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"
#include "audio/fifo.h"

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


#define ASSERT_LOCKED() assert(fifo->lock)


void fifo_init(struct fifo *fifo, size_t size) {
	fifo->mutex = SDL_CreateMutex();
	fifo->cond = SDL_CreateCond();
	fifo->rptr = 0;
	fifo->wptr = 0;
	fifo->size = size;
}

void fifo_free(struct fifo *fifo) {
	SDL_DestroyCond(fifo->cond);
	SDL_DestroyMutex(fifo->mutex);
	fifo->rptr = 0;
	fifo->wptr = 0;
	fifo->size = 0;
}

bool_t fifo_empty(struct fifo *fifo) {
	ASSERT_LOCKED();

	return (fifo->rptr == fifo->wptr);
}

size_t fifo_bytes_used(struct fifo *fifo) {
	ASSERT_LOCKED();

	return (fifo->wptr >= fifo->rptr) ? (fifo->wptr - fifo->rptr ) : (fifo->wptr - fifo->rptr + fifo->size);
}

size_t fifo_bytes_free(struct fifo *fifo) {
	ASSERT_LOCKED();

	return (fifo->rptr > fifo->wptr) ? (fifo->rptr - fifo->wptr - 1) : (fifo->rptr - fifo->wptr + fifo->size - 1);
}
	
size_t fifo_bytes_until_rptr_wrap(struct fifo *fifo) {
	ASSERT_LOCKED();

	return (fifo->size-fifo->rptr);
}

size_t fifo_bytes_until_wptr_wrap(struct fifo *fifo) {
	ASSERT_LOCKED();

	return (fifo->size-fifo->wptr);
}

void fifo_rptr_incby(struct fifo *fifo, size_t incby) {
	ASSERT_LOCKED();

	if (fifo->rptr + incby == fifo->size) {
		fifo->rptr = 0;
	} else {
		fifo->rptr += incby;
	}	
}

void fifo_wptr_incby(struct fifo *fifo, size_t incby) {
	ASSERT_LOCKED();

	if (fifo->wptr + incby == fifo->size) {
		fifo->wptr = 0;
	} else {
		fifo->wptr += incby;
	}	
}

int fifo_lock(struct fifo *fifo) {
	int r = SDL_LockMutex(fifo->mutex);

	fifo->lock++;
	return r;
}

int fifo_unlock(struct fifo *fifo) {
	ASSERT_LOCKED();

	fifo->lock--;
	return SDL_UnlockMutex(fifo->mutex);
}

int fifo_signal(struct fifo *fifo) {
	ASSERT_LOCKED();

	return SDL_CondSignal(fifo->cond);
}

int fifo_wait_timeout(struct fifo *fifo, Uint32 ms) {
	int r;

	ASSERT_LOCKED();
	fifo->lock--;

	r = SDL_CondWaitTimeout(fifo->cond, fifo->mutex, ms);

	fifo->lock++;
	return 1;
}
