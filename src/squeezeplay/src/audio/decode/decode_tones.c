/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

//#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#define BLOCKSIZE 2048

struct decode_tones {
	sample_t *write_buffer;
	u32_t sample_rate;
	int mode;
	int tones_multitone_test;
	int count;
	u32_t theta;
};


#define DECODE_TONES_MODE_SINE40	1
#define DECODE_TONES_MODE_MULTITONE	2
#define DECODE_TONES_MODE_LEFT_CHANNEL	3


#define INVERT24(n) ( ((n & 0x00ffffff)==0x00800000) ? \
			  0x007fffff : 			\
			  (~n + 1)			\
			)


/* 40-step (360¡) sine is used for 1102.5 Hz, 2205.0, etc */
/* TODO make 90¡ */
static const u32_t sine40[] = {	/* amplitude 2^24-2.  40 samples per cycle gives 1102.5Hz */
0,1312267,2592222,3808348,4930699,5931641,6786526,7474304,7978039,8285329,8388607,8285329,7978039,7474304,6786526,5931641,4930700,3808348,2592222,1312267,
0,-1312267,-2592222,-3808348,-4930699,-5931641,-6786526,-7474304,-7978039,-8285329,-8388607,-8285329,-7978039,-7474304,-6786526,-5931641,-4930700,-3808348,-2592222,-1312267
};

/* 16-step (90¡) sine s used for calculated sines at arbitrary frequencies */

#define SINE_FREQ_TO_STEP_44100(f) (Uint32)(f * 0x10000 / 44100)
u32_t sinetable[] = {0,822227,1636536,2435084,3210181,3954361,4660460,5321675,5931640,6484480,6974871,7398090,7750061,8027395,8227421,8348213,8388606,0};


/* 360 degrees == 0x10000 */
static s32_t decode_tones_sine90 (u32_t theta) {
        u32_t i = (theta & 0x00007c00) >> 10;
        u32_t j = i+1;

#if 0
	DEBUG_TRACE("theta=%08x, i=%02d, j=%02d, frac = %08x, ret = %d", theta, i, j, 
		    (((sinetable[j] - sinetable[i]) * (theta & 0x3ff)) >> 10 ),
		    (sinetable[i] + (((sinetable[j] - sinetable[i]) * (theta & 0x3ff)) >> 10 ))
		);
#endif
	
	return (sinetable[i] + (((sinetable[j] - sinetable[i]) * (theta & 0x3ff)) >> 10 ));
}

static s32_t decode_tones_sine (u32_t theta) {
        u32_t quadrant;
        s32_t result;

        theta &= 0x0000ffff;

        quadrant = (theta & 0x0000c000) >> 14;

        if (quadrant & 1)
                theta = 0x8000 - theta;

        result = decode_tones_sine90(theta);

        if (quadrant & 2) {
			return(INVERT24(result));
        } else {
	        return result;
    	}
    	
        /* Extra credit: the error at this point can be approximated by the function:
	 *
	 *    (result) * 10500 * (abs(sin( 32 * theta)))
	 *
	 * make a higher precision version of this function using a couple more lookups
	 */
}


static bool_t decode_tones_callback(void *data) {
	struct decode_tones *self = (struct decode_tones *) data;
	sample_t sample, left, right;
	sample_t *write_pos;
	int i;


	if (!decode_output_can_write(sizeof(sample_t) * BLOCKSIZE, self->sample_rate)) {
		return FALSE;
	}

	write_pos = self->write_buffer;

	switch (self->mode) {
		case DECODE_TONES_MODE_SINE40:
			for (i = 0; i < BLOCKSIZE; i+=2) {
				sample = sine40[self->count];
		
				if (++self->count == 40)
					self->count = 0;

				*write_pos++ = sample << 8;
				*write_pos++ = sample << 8;
			}
			break;

		case DECODE_TONES_MODE_LEFT_CHANNEL:
		case DECODE_TONES_MODE_MULTITONE:
			for (i = 0; i < BLOCKSIZE; i+=2) {

				if (++self->count == (44100 * 400 / 1000)) { /* 400 ms elapsed */
					self->count = 0;
					
					self->tones_multitone_test++;
					if ((self->mode == DECODE_TONES_MODE_LEFT_CHANNEL && self->tones_multitone_test > 5) || self->tones_multitone_test > 15) {
						self->tones_multitone_test = 1;
					}
				}
				
				switch (self->tones_multitone_test % 5) {				
					case 0: self->theta += SINE_FREQ_TO_STEP_44100(392.0); break;	
					case 1: self->theta += SINE_FREQ_TO_STEP_44100(261.6); break;	
					case 2: self->theta += SINE_FREQ_TO_STEP_44100(293.7); break;	
					case 3: self->theta += SINE_FREQ_TO_STEP_44100(329.6); break;	
					case 4: self->theta += SINE_FREQ_TO_STEP_44100(349.2); break;	
				}

				sample = decode_tones_sine(self->theta);
				
				/* Select which channel */
				if (self->tones_multitone_test <= 5) {
					/* Left channel only */
					left = sample;
					right = 0;
				} else if (self->tones_multitone_test <= 10) {
					/* Right channel only */
					left = 0;
					right = sample;
				} else {
					/* Both channels */
					left = sample;
					right = sample;
				}
				
				*write_pos++ = left << 8;
				*write_pos++ = right << 8;
			}
			
			DEBUG_TRACE("count: %08x, theta: %08x", self->count, self->theta);
			break;
	}		

	decode_output_samples(self->write_buffer, BLOCKSIZE / 2, self->sample_rate);
					      
	return TRUE;
}		


static u32_t decode_tones_period(void *data) {
    //	struct decode_tones *self = (struct decode_tones *) data;

	return 1;

#if 0
	if (self->sample_rate <= 48000) {
		return 8;
	}
	else {
		return 4;
	}
#endif
}


static void *decode_tones_start(u8_t *params, u32_t num_params) {
	struct decode_tones *self;

	DEBUG_TRACE("decode_tones_start()");

	self = malloc(sizeof(struct decode_tones));
	memset(self, 0, sizeof(struct decode_tones));

	self->write_buffer = malloc(sizeof(sample_t) * 2 * BLOCKSIZE);
	
	switch (params[0]) {
	default:
	case TESTTONES_MULTITONE:
	    self->mode = DECODE_TONES_MODE_MULTITONE;
	    self->sample_rate = 44100;
	    break;
	case TESTTONES_LEFT_CHANNEL:
	    self->mode = DECODE_TONES_MODE_LEFT_CHANNEL;
	    self->sample_rate = 44100;
	    break;
	case TESTTONES_SINE40_44100:
	    self->mode = DECODE_TONES_MODE_SINE40;
	    self->sample_rate = 44100;
	    break;
	case TESTTONES_SINE40_48000:
	    self->mode = DECODE_TONES_MODE_SINE40;
	    self->sample_rate = 48000;
	    break;
	case TESTTONES_SINE40_88200:
	    self->mode = DECODE_TONES_MODE_SINE40;
	    self->sample_rate = 88200;
	    break;
	case TESTTONES_SINE40_96000:
	    self->mode = DECODE_TONES_MODE_SINE40;
	    self->sample_rate = 96000;
	    break;
	case TESTTONES_SINE40_192000:
	    self->mode = DECODE_TONES_MODE_SINE40;
	    self->sample_rate = 192000;
	    break;
	}

	return self;
}


static void decode_tones_stop(void *data) {
	struct decode_tones *self = (struct decode_tones *) data;

	DEBUG_TRACE("decode_tones_stop()");

	// XXXX streambuf_flush();
	
	free(self->write_buffer);
	free(self);
}


struct decode_module decode_tones = {
	't',
	"tone",
	decode_tones_start,
	decode_tones_stop,
	decode_tones_period,
	decode_tones_callback,
};
