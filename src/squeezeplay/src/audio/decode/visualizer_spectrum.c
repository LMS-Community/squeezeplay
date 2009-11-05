/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"

#include "audio/mqueue.h"
#include "audio/fifo.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"
#include "audio/kiss_fft.h"

#include <math.h>


/////////////////////////////////////////////////////////
//
// Package constants
//
/////////////////////////////////////////////////////////

// Calculated as (x ^ 2.5) * (0x1fffff) where x is in the range
// 0..1 in 32 steps. This creates a curve weighted towards
// lower values.
static int power_map[32] = {
  0, 362, 2048, 5643, 11585, 20238, 31925, 46935, 65536, 87975, 114486, 
  145290, 180595, 220603, 265506, 315488, 370727, 431397, 497664, 
  569690, 647634, 731649, 821886, 918490, 1021605, 1131370, 1247924, 
  1371400, 1501931, 1639645, 1784670, 1937131
}; 

// The maximum number of input samples sent to the FFT.
// This is the actual number of input points for a combined
// stereo signal.
// For separate stereo signals, the number of input points for
// each signal is half of the value.
#define MAX_SAMPLE_WINDOW 1024

// The maximum number of subbands forming the output of the FFT.
// The is the actual number of output points for a combined
// stereo signal.
// For separate stereo signals, the number of output points for
// each signal is half of the value.
#define MAX_SUBBANDS MAX_SAMPLE_WINDOW / 2

// The minimum size of the FFT that we'll do.
#define MIN_SUBBANDS 32

// The minimum total number of input samples to consider for the FFT.
// If the sample window used is smaller, then we will use multiple
// sample windows.
#define MIN_FFT_INPUT_SAMPLES 128

/////////////////////////////////////////////////////////
//
// Package state variables
//
/////////////////////////////////////////////////////////

// Rendering related state variables

// The position of the channel histogram in pixels
static int channel_position[2];

// The width of the channel histogram in pixels
static int channel_width[2];

// The width of an individual histogram bar in pixels
static int bar_width[2];

// The spacing between histogram bars in pixels
static int bar_spacing[2];

// The number of subbands displayed by a single histogram bar
static int subbands_in_bar[2];

// The number of histogram to display
static int num_bars[2];

// Is the channel histogram flipped 
static int channel_flipped[2];

// Do we clip the number of subbands shown based on the width
// or show all of them?
static int clip_subbands[2];

// Grey level of the bar and bar cap
static int bar_grey_level[2];
static int bar_cap_grey_level[2];

// FFT related state variables

// The number of output points of the FFT. In clipped mode, we
// may not display all of them.
static int num_subbands;

// The number of input points to the FFT.
static int sample_window;

// The number of sample windows that we will average across.
static int num_windows;

// Should we compute the FFT based on the full bandwidth (0 to
// Nyquist frequency) or half of it (0 to half Nyquist frequency)?
static int bandwidth_half;

// Should we combine the channel histograms and only show a single
// channel?
static int is_mono;

// The value to use for computing preemphasis 
static int preemphasis_db_per_khz;

/////////////////////////////////////////////////////////
//
// Package buffers
//
/////////////////////////////////////////////////////////

// A Hamming window used on the input samples. This could be
// precalculated for a fixed window size. Right now, we're
// computing it in the begin() method.
double filter_window[MAX_SAMPLE_WINDOW];

// Preemphasis applied to the subbands. This is precomputed
// based on a db/KHz value.
double preemphasis[MAX_SUBBANDS];

//remove//// The last set of values in the visualizer
//remove//double last_values[2*MAX_SUBBANDS];

// Used in power computation across multiple sample windows.
// For a small window size, this could be stack based.
float avg_power[2 * MAX_SUBBANDS];

kiss_fft_cfg cfg = NULL;

typedef struct {
	int *ptr;
	int value;
} spectrum_defaults_t;


// Parameters for the spectrum analyzer:
//   0 - Channels: stereo == 0, mono == 1
//   1 - Bandwidth: 0..22050Hz == 0, 0..11025Hz == 1
//   2 - Preemphasis in dB per KHz
// Left channel parameters:
//   3 - Position in pixels
//   4 - Width in pixels
//   5 - orientation: left to right == 0, right to left == 1
//   6 - Bar width in pixels
//   7 - Bar spacing in pixels
//   8 - Clipping: show all subbands == 0, clip higher subbands == 1
//   9 - Bar intensity (greyscale): 1-3
//   10 - Bar cap intensity (greyscale): 1-3
// Right channel parameters (not required for mono):
//   11-18 - same as left channel parameters

// FIXME: when below compiler issue is fixed
#define NUM_DEFAULTS 3

static spectrum_defaults_t defaults[NUM_DEFAULTS] = {
  { &is_mono, 0 },
  { &bandwidth_half, 0 },
//  { &preemphasis_db_per_khz, 0x10000 }
  { &preemphasis_db_per_khz, ( 0x10000 >> 16) }
};


#define NUM_CHANNEL_DEFAULTS 8

static spectrum_defaults_t channel_defaults[2][NUM_CHANNEL_DEFAULTS] = {
  {
    { &channel_position[0],  24 },
//    { &channel_width[0], 128 },
    { &channel_width[0], 70 },
    { &channel_flipped[0], FALSE },
//    { &bar_width[0], 1 },
//    { &bar_spacing[0], 0 },
    { &bar_width[0], 2 },
    { &bar_spacing[0], 0 },
    { &clip_subbands[0], FALSE },
    { &bar_grey_level[0], 1 },
    { &bar_cap_grey_level[0], 3 }
  },
  {
    { &channel_position[1],  168 },
//    { &channel_width[1], 128 },
    { &channel_width[1], 70 },
    { &channel_flipped[1], TRUE },
//    { &bar_width[1], 1 },
//    { &bar_spacing[1], 0 },
    { &bar_width[1], 2 },
    { &bar_spacing[1], 0 },
    { &clip_subbands[1], FALSE },
    { &bar_grey_level[1], 1 },
    { &bar_cap_grey_level[1], 3 }
  }
};

#define SPECTRUM_MAX_NUM_BINS 32

int decode_spectrum( lua_State *L) {

	int sample_bin_ch0[MAX_SUBBANDS];
	int sample_bin_ch1[MAX_SUBBANDS];

	int i;
	int w;
	int ch;

	int num_bins = luaL_optinteger(L, 2, SPECTRUM_MAX_NUM_BINS);

//	printf( "**** decode_spectrum() 1 - num_bins: %d\n", num_bins);

	if( ( num_bins < 0) || ( num_bins > SPECTRUM_MAX_NUM_BINS)) {
		num_bins = SPECTRUM_MAX_NUM_BINS;
	}

//	printf( "**** decode_spectrum() 2a - num_windows: %d sample_window: %d\n", num_windows, sample_window);
//	printf( "**** decode_spectrum() 2b - num_bars[0]: %d num_subbands: %d\n", num_bars[0], num_subbands);

	// Init avg_power
	for( i = 0; i < (2 * MAX_SUBBANDS); i++) {
		avg_power[i] = 0;
	}

	for( w = 0; w < num_windows; w++) {
		kiss_fft_cpx fin_buf[MAX_SAMPLE_WINDOW];
		kiss_fft_cpx fout_buf[MAX_SAMPLE_WINDOW];

		int avg_ptr;
		int s;

		sample_t *ptr;
		size_t samples_until_wrap;

		int sample;

		decode_audio_lock();

		if( decode_audio->state & DECODE_STATE_RUNNING) {
			ptr = (sample_t *) (void *) ( decode_fifo_buf + decode_audio->fifo.rptr);
			samples_until_wrap = BYTES_TO_SAMPLES( fifo_bytes_until_rptr_wrap( &decode_audio->fifo));

			for( i = 0; i < sample_window; i++) {
				sample = (*ptr++) >> 16;
				fin_buf[i].r = (float) ( filter_window[i] * sample);

				sample = (*ptr++) >> 16;
				fin_buf[i].i = (float) ( filter_window[i] * sample);

				samples_until_wrap -= 2;
				if( samples_until_wrap <= 0) {
					ptr = (sample_t *) (void *) decode_fifo_buf;
				}
			}
		}

		decode_audio_unlock();


#if 0
// Test case
		{
			double freq = ( M_PI * 16) / 256;
			float ampl = ( (int) pow( 2, 16)) / 2;
			int i;

			for( i = 0; i < sample_window; i++) {
				fin_buf[i].r = ( ampl * (float) sin( i * freq)) + ( ampl * (float) cos( i * freq));
				fin_buf[i].i = ( ampl * (float) sin( i * freq)) + ( ampl * (float) cos( i * freq));
			}
		}
#endif

		kiss_fft( cfg, fin_buf, fout_buf);

		// Extract the two separate frequency domain signals
		// and keep track of the power per bin.
		avg_ptr = 0;
		for( s = 1; s <= num_subbands; s++) {
			kiss_fft_cpx ck, cnk;

			float r, i;

			ck = fout_buf[s];
			cnk = fout_buf[sample_window - s];

			r = ( ck.r + cnk.r) / 2;
			i = ( ck.i - cnk.i) / 2;

			avg_power[avg_ptr++] += ( r * r + i * i) / num_windows;

			r = ( cnk.i + ck.i) / 2;
			i = ( cnk.r - ck.r) / 2;

			avg_power[avg_ptr++] += ( r * r + i * i) / num_windows;
		}
	}


	{
		int pre_ptr = 0;
		int avg_ptr = 0;
		int p;

		for( p = 0; p < num_subbands; p++) {
			long product = (long) ( avg_power[avg_ptr] * preemphasis[pre_ptr]);
			product >>= 16;
			avg_power[avg_ptr++] = (int) product;

			product = (long) ( avg_power[avg_ptr] * preemphasis[pre_ptr]);
			product >>= 16;
			avg_power[avg_ptr++] = (int) product;

			pre_ptr++;
		}
	}

	for( ch = 0; ch < (( is_mono) ? 1 : 2); ch++) {
		int power_sum = 0;
		int in_bar = 0;
		int curr_bar = 0;

		int avg_ptr = ( ch == 0) ? 0 : 1;

		int s;

		for( s = 0; s < num_subbands; s++) {
			// Average out the power for all subbands represented
			// by a bar.
			power_sum += avg_power[avg_ptr] / subbands_in_bar[ch];

			if( is_mono) {
				power_sum += avg_power[avg_ptr + 1] / subbands_in_bar[ch];
			}

			if( ++in_bar == subbands_in_bar[ch]) {
				int val;
				int i;

				if( is_mono) {
					power_sum >>= 2;
				}

				power_sum <<= 6; // FIXME scaling

				val = 0;
				for( i = 31; i > 0; i--) {
					if( power_sum >= power_map[i]) {
						val = i;
						break;
					}
				}

				if( ch == 0) {
					sample_bin_ch0[curr_bar++] = val;
				}
				if( ch == 1) {
					sample_bin_ch1[curr_bar++] = val;
				}

//				printf( "*** ch: %d, curr_bar: %d, val: %d\n", ch, curr_bar, val);
//				curr_bar++;

				if( curr_bar == num_bars[ch]) {
					break;
				}

				in_bar = 0;
				power_sum = 0;
			}
			avg_ptr += 2;
		}
	}


	lua_newtable( L);
	for( i = 0; i < num_bins; i++) {
		if( channel_flipped[0] == FALSE) {
			lua_pushinteger( L, sample_bin_ch0[i]);
		} else {
			lua_pushinteger( L, sample_bin_ch0[num_bins - 1 - i]);
		}
		lua_rawseti( L, -2, i + 1);
	}

	lua_newtable( L);
	for( i = 0; i < num_bins; i++) {
		if( channel_flipped[1] == FALSE) {
			lua_pushinteger( L, sample_bin_ch1[i]);
		} else {
			lua_pushinteger( L, sample_bin_ch1[num_bins - 1 - i]);
		}
		lua_rawseti( L, -2, i + 1);
	}

	return 2;
}


int decode_spectrum_init( lua_State *L) {
// TODO: read params from lua
	int *params = NULL;
	int num_params = 0;

	// Get visualizer parameters (or defaults)
	int d, p = 0;

	int bar_size;
	int l2int = 0;
	int shiftsubbands;

	for( d = 0; d < NUM_DEFAULTS; d++) {
		if( p < num_params) {
			*(defaults[d].ptr) = params[p];
		} else {
			*(defaults[d].ptr) = defaults[d].value;
		}
		p++;
	}

	// Get the first channel parameters (or defaults)
	for( d = 0; d < NUM_CHANNEL_DEFAULTS; d++) {
		if( p < num_params) {
			*(channel_defaults[0][d].ptr) = params[p];
		} else {
			*(channel_defaults[0][d].ptr) = channel_defaults[0][d].value;
		}
		p++;
	}

	if( !is_mono) {
		// Get the second channel parameters (or defaults)
		for( d = 0; d < NUM_CHANNEL_DEFAULTS; d++) {
			if( p < num_params) {
				*(channel_defaults[1][d].ptr) = params[p];
			} else {
				*(channel_defaults[1][d].ptr) = channel_defaults[1][d].value;
			}
			p++;
		}
	}

	// Approximate the number of subbands we'll display based
	// on the width available and the size of the histogram
	// bars.
	bar_size = bar_width[0] + bar_spacing[0];
	num_subbands = channel_width[0] / bar_size;

	printf( "bar_width[0] %d bar_spacing[0] %d bar_size %d num_subbands %d\n", bar_width[0], bar_spacing[0], bar_size, num_subbands);

	// Calculate the integer component of the log2 of the num_subbands
	l2int = 0;
	shiftsubbands = num_subbands;
	while( shiftsubbands != 1) {
		l2int++;
		shiftsubbands >>= 1;
	}

	// The actual number of subbands is the largest power
	// of 2 smaller than the specified width.
	num_subbands = 1L << l2int;

	printf( "shiftsubbands %d l2int %d num_subbands %d\n", shiftsubbands, l2int, num_subbands);

	// In the case where we're going to clip the higher
	// frequency bands, we choose the next highest
	// power of 2.
	if( clip_subbands[0]) {
		num_subbands <<= 1;
	}

	// The number of histogram bars we'll display is nominally
	// the number of subbands we'll compute.
	num_bars[0] = num_subbands;

	printf( "num_bars[0] %d num_bars[1] %d\n", num_bars[0], num_bars[1]);

	// Though we may have to compute more subbands to meet
	// a minimum and average them into the histogram bars.
	if( num_subbands < MIN_SUBBANDS) {
		subbands_in_bar[0] = MIN_SUBBANDS / num_subbands;
		num_subbands = MIN_SUBBANDS;
	} else {
		subbands_in_bar[0] = 1;
	}

	printf( "subbands_in_bar[0] %d subbands_in_bar[1] %d\n", subbands_in_bar[0], subbands_in_bar[1]);

	// If we're clipping off the higher subbands we cut down
	// the actual number of bars based on the width available.
	if( clip_subbands[0]) {
		num_bars[0] = channel_width[0] / bar_size;
	}

	// Since we now have a fixed number of subbands, we choose
	// values for the second channel based on these.
	if( !is_mono) {
		bar_size = bar_width[1] + bar_spacing[1];
		num_bars[1] = channel_width[1] / bar_size;
		subbands_in_bar[1] = 1;
		// If we have enough space for all the subbands, great.
		if( num_bars[1] > num_subbands) {
			num_bars[1] = num_subbands;

		// If not, we find the largest factor of the
		// number of subbands that we can show.
		} else if( !clip_subbands[1]) {
			int s = num_subbands;
			subbands_in_bar[1] = 1;
			while( s > num_bars[1]) {
				s >>= 1;
				subbands_in_bar[1]++;
			}
			num_bars[1] = s;
		}
	}

	printf( "num_bars[0] %d num_bars[1] %d\n", num_bars[0], num_bars[1]);
	printf( "subbands_in_bar[0] %d subbands_in_bar[1] %d\n", subbands_in_bar[0], subbands_in_bar[1]);

	// Calculate the number of samples we'll need to send in as
	// input to the FFT. If we're halving the bandwidth (by
	// averaging adjacent samples), we're going to need twice
	// as many.
	sample_window = num_subbands * 2;

	if( sample_window < MIN_FFT_INPUT_SAMPLES) {
		num_windows = MIN_FFT_INPUT_SAMPLES / sample_window;
	} else {
		num_windows = 1;
	}

	if( cfg) {
		free( cfg);
		cfg = NULL;
	}

	if( !cfg) {
		double const1;
		double const2;
		int w;

		double subband_width;
		double freq_sum;
		double scale_db;
		int s;

		cfg = kiss_fft_alloc( sample_window, 0, NULL, NULL);

// Still needed?
//		mem_addr_t lvptr = (mem_addr_t) last_values->aligned;
//		for( int ch = 0; ch < 2; ch++) {
//			for( u32_t s = 0; s < num_subbands; s++) {
//				paged_write_u32( last_values, lvptr, 0);
//				lvptr += sizeof( u32_t);
//			}
//		}

		const1 = 0.54;
		const2 = 0.46;
		for( w = 0; w < sample_window; w++) {
			const double twopi = 6.283185307179586476925286766;
			filter_window[w] = const1 - ( const2 * cos( twopi * (double) w / (double) sample_window));
		}

		// Compute the preemphasis
		subband_width = 22.05 / num_subbands;
		freq_sum = 0;
		scale_db = 0;

		for( s = 0; s < num_subbands; s++) {
			while( freq_sum > 1) {
				freq_sum -= 1;
				scale_db += preemphasis_db_per_khz;
			}
			if( scale_db != 0) {
				preemphasis[s] = pow( 10, ( scale_db / 10.0));
			} else {
				preemphasis[s] = 1;
			}
			freq_sum += subband_width;
		}
	}

	return 0;
}

