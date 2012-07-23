
#ifndef ALAC_H
#define ALAC_H

#include "common.h"

/* compatibility with libavformat */
#define inline inline
#define av_always_inline inline
#define av_cold
#define av_const

#define INT_BIT 32
#define SAMPLE_FMT_S16 16
#define SAMPLE_FMT_S32 32

#define av_malloc(X) malloc(X)
#define av_free(X) free(X)

#define FFSIGN(a) ((a) > 0 ? 1 : -1)

#define av_log(A, B, ...) printf(__VA_ARGS__)


typedef struct {
    void *extradata;
    int extradata_size;
    void *priv_data;

    int channels;
    int sample_fmt;
    int samplerate;
} AVCodecContext;

typedef struct {
    void *data;
    int size;
} AVPacket;


int alac_decode_frame(AVCodecContext *avctx,
		      void *outbuffer, unsigned int *outputsize,
		      AVPacket *avpkt);

int alac_decode_init(AVCodecContext *avctx);

int alac_decode_close(AVCodecContext *avctx);

extern int alac_priv_data_size;

#endif // ALAC_H
