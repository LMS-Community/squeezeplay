/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/mqueue.h"
#include "audio/decode/decode_priv.h"


void mqueue_init(struct mqueue *mqueue, void *buffer, size_t buffer_size) {
	fifo_init(&mqueue->fifo, buffer_size, false);
	mqueue->buffer = buffer;
}


static void mqueue_read_buf(struct mqueue *mqueue, Uint8 *b, size_t n) {
	size_t bytes_read;

	while (n) {
		bytes_read = fifo_bytes_until_rptr_wrap(&mqueue->fifo);
		if (n < bytes_read) {
			bytes_read = n;
		}

		memcpy(b, mqueue->buffer + mqueue->fifo.rptr, bytes_read);
		fifo_rptr_incby(&mqueue->fifo, bytes_read);

		b += bytes_read;
		n -= bytes_read;
	}
}


mqueue_func_t mqueue_read_request(struct mqueue *mqueue, Uint32 timeout) {
	int err;

	if (fifo_lock(&mqueue->fifo) == -1) {
		LOG_ERROR(log_audio_decode, "Failed to lock mutex %s", SDL_GetError());
		return NULL;
	}

	/* Any queued messages? */
	if (fifo_bytes_used(&mqueue->fifo)) {
		mqueue_func_t func;
		mqueue_read_buf(mqueue, (Uint8 *)&func, sizeof(func));

		/* Mutex remains locked until mqueue_read_complete */
		return func;
	}

	if (!timeout) {
		fifo_unlock(&mqueue->fifo);
		return NULL;
	}

	/* Wait until timeout */
	err = fifo_wait_timeout(&mqueue->fifo, timeout);
	if (err == SDL_MUTEX_TIMEDOUT) {
		fifo_unlock(&mqueue->fifo);
		return NULL;
	}
	else if (err == -1) {
		LOG_ERROR(log_audio_decode, "Failed to wait on condition %s", SDL_GetError());

		fifo_unlock(&mqueue->fifo);
		return NULL;
	}
	else {
		mqueue_func_t func;
		mqueue_read_buf(mqueue, (Uint8 *)&func, sizeof(func));

		/* Mutex remains locked until mqueue_read_complete */
		return func;
	}
}


void mqueue_read_complete(struct mqueue *mqueue) {
	/* Unlock mutex */
	fifo_unlock(&mqueue->fifo);
}


Uint8 mqueue_read_u8(struct mqueue *mqueue) {
	Uint8 v;
	mqueue_read_buf(mqueue, (Uint8 *)&v, sizeof(v));
	return v;
}


Uint16 mqueue_read_u16(struct mqueue *mqueue) {
	Uint16 v;
	mqueue_read_buf(mqueue, (Uint8 *)&v, sizeof(v));
	return v;
}


Uint32 mqueue_read_u32(struct mqueue *mqueue) {
	Uint32 v;
	mqueue_read_buf(mqueue, (Uint8 *)&v, sizeof(v));
	return v;
}


void mqueue_read_array(struct mqueue *mqueue, Uint8 *array, size_t len)
{
	mqueue_read_buf(mqueue, array, len);
}


static void mqueue_write_buf(struct mqueue *mqueue, Uint8 *b, size_t n) {
	size_t bytes_write;

	while (n) {
		bytes_write = fifo_bytes_until_wptr_wrap(&mqueue->fifo);
		if (n < bytes_write) {
			bytes_write = n;
		}

		memcpy(mqueue->buffer + mqueue->fifo.wptr, b, bytes_write);
		fifo_wptr_incby(&mqueue->fifo, bytes_write);

		b += bytes_write;
		n -= bytes_write;
	}
}


int mqueue_write_request(struct mqueue *mqueue, mqueue_func_t func, size_t len) {
	if (fifo_lock(&mqueue->fifo) == -1) {
		LOG_ERROR(log_audio_decode, "Failed to lock mutex %s", SDL_GetError());
		return 0;
	}

	/* Check there is enough room in the mqueue */
	if (len > fifo_bytes_free(&mqueue->fifo)) {
		fifo_unlock(&mqueue->fifo);
		return 0;
	}

	/* Write handler function */
	mqueue_write_buf(mqueue, (Uint8 *)&func, sizeof(func));

	/* Mutex remains locked until mqueue_write_complete */
	return 1;
}


void mqueue_write_complete(struct mqueue *mqueue) {
	/* Signal reader and unlock mutex */
	fifo_signal(&mqueue->fifo);
	fifo_unlock(&mqueue->fifo);
}


void mqueue_write_u8(struct mqueue *mqueue, Uint8 val) {
	mqueue_write_buf(mqueue, (Uint8 *)&val, sizeof(val));
}


void mqueue_write_u16(struct mqueue *mqueue, Uint16 val) {
	mqueue_write_buf(mqueue, (Uint8 *)&val, sizeof(val));
}


void mqueue_write_u32(struct mqueue *mqueue, Uint32 val) {
	mqueue_write_buf(mqueue, (Uint8 *)&val, sizeof(val));
}

void mqueue_write_array(struct mqueue *mqueue, Uint8 *array, size_t len)
{
	mqueue_write_buf(mqueue, array, len);
}

