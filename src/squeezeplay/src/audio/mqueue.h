/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "audio/fifo.h"


struct mqueue {
	char *buffer;
	struct fifo fifo;
};

typedef void (*mqueue_func_t)(void);


extern void mqueue_init(struct mqueue *mqueue, void *buffer, size_t buffer_size);

extern mqueue_func_t mqueue_read_request(struct mqueue *mqueue, Uint32 timeout);

extern Uint8 mqueue_read_u8(struct mqueue *mqueue);
extern Uint16 mqueue_read_u16(struct mqueue *mqueue);
extern Uint32 mqueue_read_u32(struct mqueue *mqueue);
extern void mqueue_read_array(struct mqueue *mqueue, Uint8 *array, size_t len);
extern void mqueue_read_complete(struct mqueue *mqueue);

extern int mqueue_write_request(struct mqueue *mqueue, mqueue_func_t func, size_t len);
extern void mqueue_write_u8(struct mqueue *mqueue, Uint8 val);
extern void mqueue_write_u16(struct mqueue *mqueue, Uint16 val);
extern void mqueue_write_u32(struct mqueue *mqueue, Uint32 val);
extern void mqueue_write_array(struct mqueue *mqueue, Uint8 *array, size_t len);
extern void mqueue_write_complete(struct mqueue *mqueue);
