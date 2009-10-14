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


int decode_spectrum(lua_State *L) {
	return 0;
}







#if 0

/*
 * visualizer_spectrum.c
 *
 */

#include "visualizer_spectrum.h"
#include "decode.h"
#include "decode_priv.h"
#include "audio.h"
#include "paged.h"
#include "../fft/kiss_fftr.h"

THIS_FILE("visualizer_spectrum.c");

#define RUNTIME_DEBUG 0

/////////////////////////////////////////////////////////
//
// Package constants
//
/////////////////////////////////////////////////////////

// Pixel values to use to draw a histogram bar. Primary index is the 
// height of the bar. Secondary index is lower or upper half of the
// screen. Largest height is a full height (32 pixel) bar.
u32_t spectrum_pixels[32][2] __attribute__((section(".progmem.data.spectrum_pixels")))= {
  { 0x00000000, 0x00000000 },
  { 0x00000001, 0x00000000 },
  { 0x00000005, 0x00000000 },
  { 0x00000015, 0x00000000 },
  { 0x00000055, 0x00000000 },
  { 0x00000155, 0x00000000 },
  { 0x00000555, 0x00000000 },
  { 0x00001555, 0x00000000 },
  { 0x00005555, 0x00000000 },
  { 0x00015555, 0x00000000 },
  { 0x00055555, 0x00000000 },
  { 0x00155555, 0x00000000 },
  { 0x00555555, 0x00000000 },
  { 0x01555555, 0x00000000 },
  { 0x05555555, 0x00000000 },
  { 0x15555555, 0x00000000 },
  { 0x55555555, 0x00000000 },
  { 0x55555555, 0x00000001 },
  { 0x55555555, 0x00000005 },
  { 0x55555555, 0x00000015 },
  { 0x55555555, 0x00000055 },
  { 0x55555555, 0x00000155 },
  { 0x55555555, 0x00000555 },
  { 0x55555555, 0x00001555 },
  { 0x55555555, 0x00005555 },
  { 0x55555555, 0x00015555 },
  { 0x55555555, 0x00055555 },
  { 0x55555555, 0x00155555 },
  { 0x55555555, 0x00555555 },
  { 0x55555555, 0x01555555 },
  { 0x55555555, 0x05555555 },
  { 0x55555555, 0x15555555 }
};

// Calculated as (x ^ 2.5) * (0x1fffff) where x is in the range
// 0..1 in 32 steps. This creates a curve weighted towards
// lower values.
static u32_t power_map[32] __attribute__((section(".progmem.data.power_map"))) = {
  0, 362, 2048, 5643, 11585, 20238, 31925, 46935, 65536, 87975, 114486, 
  145290, 180595, 220603, 265506, 315488, 370727, 431397, 497664, 
  569690, 647634, 731649, 821886, 918490, 1021605, 1131370, 1247924, 
  1371400, 1501931, 1639645, 1784670, 1937131
}; 

// The number of frames per second
#define FRAME_RATE 30

// The maximum number of input samples sent to the FFT.
// This is the actual number of input points for a combined
// stereo signal.
// For separate stereo signals, the number of input points for
// each signal is half of the value.
#define MAX_SAMPLE_WINDOW 512 

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

// The size of a chunk in bytes that we read from the
// SDRAM fifo buffer at a time. This number should be 
// less than or equal to the size of the minimum sample 
// window.
#define CHUNK_SIZE 256


/////////////////////////////////////////////////////////
//
// Package state variables
//
/////////////////////////////////////////////////////////

// Rendering related state variables

// The position of the channel histogram in pixels
static u32_t channel_position[2];

// The width of the channel histogram in pixels
static u32_t channel_width[2];

// The width of an individual histogram bar in pixels
static u32_t bar_width[2];

// The spacing between histogram bars in pixels
static u32_t bar_spacing[2];

// The number of subbands displayed by a single histogram bar
static u32_t subbands_in_bar[2];

// The number of histogram to display
static u32_t num_bars[2];

// Is the channel histogram flipped 
static u32_t channel_flipped[2];

// Do we clip the number of subbands shown based on the width
// or show all of them?
static u32_t clip_subbands[2];

// Grey level of the bar and bar cap
static u32_t bar_grey_level[2];
static u32_t bar_cap_grey_level[2];

// FFT related state variables

// The number of output points of the FFT. In clipped mode, we
// may not display all of them.
static u32_t num_subbands;

// The number of input points to the FFT.
static u32_t sample_window;

// The number of sample windows that we will average across.
static u32_t num_windows;

// Should we compute the FFT based on the full bandwidth (0 to
// Nyquist frequency) or half of it (0 to half Nyquist frequency)?
static u32_t bandwidth_half;

// Should we combine the channel histograms and only show a single
// channel?
static u32_t is_mono;

// The value to use for computing preemphasis 
static fft_fixed preemphasis_db_per_khz;

// The number of samples in a stack-based chunk read from the
// audio buffer.
static u32_t samples_in_chunk;

// The number of chunked reads to get a complete sample window.
static u32_t num_reads;

/////////////////////////////////////////////////////////
//
// Package buffers
//
/////////////////////////////////////////////////////////

// A Hamming window used on the input samples. This could be
// precalculated for a fixed window size. Right now, we're
// computing it in the begin() method.
PAGED_DECLARE(filter_window, MAX_SAMPLE_WINDOW*sizeof(fft_fixed), 128, 0)

// Preemphasis applied to the subbands. This is precomputed
// based on a db/KHz value.
PAGED_DECLARE(preemphasis, MAX_SUBBANDS*sizeof(fft_fixed), 128, 0);

// The last set of values in the visualizer
PAGED_DECLARE(last_values, 2*MAX_SUBBANDS*sizeof(u32_t), 128, 0);

// Used in power computation across multiple sample windows.
// For a small window size, this could be stack based.
PAGED_DECLARE(avg_power, 2*MAX_SUBBANDS*sizeof(u32_t), 128, 0);

static u8_t fft_state[KISS_FFT_CFG_SIZE(MAX_SAMPLE_WINDOW)] MEM_PRAM_ATTRIBUTE;

static mem_addr_t cfg = NULL;

// Scale power value to bar height
static inline u32_t scale_value(u32_t value) {
	for (int i = 31; i > 0; i--) {
		if (value >= mem_read_u32(MEM_DYNAMIC,(mem_addr_t) &power_map[i])) {
			return i;
		}
	}
	return 0;
}

#define ENSURE_VIZ_PAGE							\
	framebuf_page_boundary = FRAMEBUF_OFFSET_COLUMNS(decode_framebuf_viz, offset + 2 * (bar_width[channel] + bar_spacing[channel])) - decode_framebuf_viz->pagesize;								\
	if (framebuf_page_boundary < decode_framebuf_viz->aligned) {	\
		framebuf_page_boundary = decode_framebuf_viz->aligned;	\
	}								\
	paged_ensure(decode_framebuf_viz, framebuf_page_boundary,	\
		     decode_framebuf_viz->pagesize)



// Render a single channel from power values
static 
void render_channel(u32_t channel,
		    framebuf_addr_t fb,
		    u32_t offset) {
	u64_t power_sum = 0;
	u32_t in_bar = 0, cur_bar = 0;
	mem_addr_t lvptr = (mem_addr_t)last_values->aligned + (channel * num_subbands * sizeof(u32_t));
	mem_addr_t avgptr = (mem_addr_t)avg_power->aligned + (channel * sizeof(u32_t));
	mem_addr_t framebuf_page_boundary = NULL;

	if (channel_flipped[channel]) {
		offset += ((num_bars[channel]-1) * 2 * (bar_width[channel] + bar_spacing[channel]));
		ENSURE_VIZ_PAGE;
	}
	for (u32_t subband = 0; subband < num_subbands; subband++) {
		// Average out the power for all subbands represented
		// by a bar.
		// XXX Maybe it should not be a pure mean
		power_sum += paged_read_u32(avg_power, avgptr) / subbands_in_bar[channel];
		if (is_mono) {
			power_sum += paged_read_u32(avg_power, avgptr+sizeof(u32_t)) / subbands_in_bar[channel];
		}
		if (++in_bar == subbands_in_bar[channel]) {
			if (is_mono) {
				power_sum >>= 1;
			}
			u32_t cur_value = scale_value(power_sum);
			// Decrement the bar top value
			u32_t lv = paged_read_u32(last_values, lvptr);
			if (lv > 0) {
				--lv;
			}
			// If the current value is greater than the
			// bar top, adjust the bar top.
			if (lv < cur_value) {
				lv = cur_value;
			}

			if (channel_flipped[channel] &&
			    FRAMEBUF_OFFSET_COLUMNS(decode_framebuf_viz, offset) < framebuf_page_boundary) {
				ENSURE_VIZ_PAGE;
			}

			// Render the lower part of the bar
			u32_t column = mem_read_u32(MEM_DYNAMIC,(mem_addr_t) &spectrum_pixels[cur_value][0]);
			if (bar_grey_level[channel] <= 1) {
				column <<= 1;
			}
			else if (bar_grey_level[channel] >= 3) {
				column = column || (column << 1);
			}
			if (lv < 16) {
				column |= bar_cap_grey_level[channel] << (lv << 1);
			}
			for (u32_t i = 0; i < bar_width[channel]; i++) {
				graphics_framebuf_write_u32(fb, offset+(i * 2), column);
			}	

			// And the upper part
			column = mem_read_u32(MEM_DYNAMIC, (mem_addr_t) &spectrum_pixels[cur_value][1]);
			if (bar_grey_level[channel] <= 1) {
				column <<= 1;
			}
			else if (bar_grey_level[channel] >= 3) {
				column = column || (column << 1);
			}
			if (lv >= 16) {
				column |= bar_cap_grey_level[channel] << ((lv - 16) << 1);
			}

			for (u32_t i = 0; i < bar_width[channel]; i++) {
				graphics_framebuf_write_u32(fb, offset+1+(i * 2), column);
			}
			if (channel_flipped[channel]) {
				offset -= 2 * (bar_width[channel] + bar_spacing[channel]);
			}
			else {
				offset += 2 * (bar_width[channel] + bar_spacing[channel]);
			}
			paged_write_u32(last_values, lvptr, lv);

			if (++cur_bar == num_bars[channel]) {
				break;
			}
			in_bar = 0;
			power_sum = 0;
			lvptr += sizeof(u32_t);
		}
		avgptr += 2 * sizeof(u32_t);
	}
}

// Timer callback for every frame
void visualizer_spectrum_callback(void) {
	s32_t chunk[CHUNK_SIZE/sizeof(u32_t)];
	kiss_fft_cpx fout_buf[MAX_FFT_INPUT_POINTS+1];
	mem_addr_t fft_output = mem_dptr_to_mem_addr(fout_buf);

	u32_t iterations = 0;

	// Clear out the buffers
	mem_addr_t avgptr = (mem_addr_t)avg_power->aligned;
	for (int ch = 0; ch < 2; ch++) {
		for (u32_t s = 0; s < num_subbands; s++) {
			paged_write_u32(avg_power, avgptr, 0);
			avgptr += sizeof(u32_t);
		}
	}
	u32_t sample_window_size = sample_window * 2 * sizeof(u16_t);

	// Since we have stereo real sequences, we use the scheme
	// detailed in http://www.eptools.com/tn/T0001/PT10.HTM and
	// http://www.library.cornell.edu/nr/bookcpdf/c12-3.pdf to do
	// a single complex fft and extract the separate complex
	// frequency sequences.
	if (decode_audio_state() & DECODE_STATE_RUNNING) {
		// To reduce noise, we do multiple windows of samples
		for (u32_t w = 0; w < num_windows; w++) {
			mem_addr_t sptr = (mem_addr_t)fft_input->aligned;
			addr_t ptr = NULL;

			mem_addr_t fw = (mem_addr_t)filter_window->aligned;

			// Read samples in chunks
			for (u32_t r = 0; r < num_reads; r++) {
				int bytes_read = decode_read_noincr(&ptr, chunk, CHUNK_SIZE);
				if (bytes_read < CHUNK_SIZE) {
					break;
				}
				// Pack the channels so that they represent
				// the real and imaginary parts of the input
				// sequence.
				for (u32_t s = 0; s < samples_in_chunk; s++) {
					// Apply a window as they are copied over
					fft_fixed window = (fft_fixed)paged_read_u32(filter_window, fw);
					kiss_fft_cpx input_cpx;
					s32_t sample;
					if (bandwidth_half) {
						// XXX Need to worry about overflow if we have 32-bit samples
						sample = chunk[4 * s];
						sample += chunk[(4 * s) + 2];
						sample >>= 9;
						input_cpx.r = (s16_t)fixed_to_s32(fixed_mul(window, s32_to_fixed(sample)));

						sample = chunk[(4 * s) + 1];
						sample += chunk[(4 * s) + 3];
						sample >>= 9;
						input_cpx.i = (s16_t)fixed_to_s32(fixed_mul(window, s32_to_fixed(sample)));
						FFT_SET_IN_CPX(sptr, input_cpx);
					}
					else {
						sample = chunk[2 * s] >> 8;
						input_cpx.r = (s16_t)fixed_to_s32(fixed_mul(window, s32_to_fixed(sample)));
						sample = chunk[(2 * s)+1] >> 8;
						input_cpx.i = (s16_t)fixed_to_s32(fixed_mul(window, s32_to_fixed(sample)));
						FFT_SET_IN_CPX(sptr, input_cpx);
					}
					fw += sizeof(fft_fixed);
					sptr = FFT_OFFSET_MEM(sptr, 1);

				} 
			}

			if (sptr != (fft_input->aligned + sample_window_size)) {
				break;
			}
			iterations++;

			// Perform the complex to complex FFT. The result
			// is N complex values in the frequency domain that
			// need to be separated into two N/2 signals for
			// each of the channels.
			kiss_fft(cfg, fft_output);

			// Ingore the 0th (DC value) and shift the
			// rest up
			//avg_power[0][0] += freq[0].r * freq[0].r;
			//avg_power[1][0] += freq[0].i * freq[0].i;

			// Extract the two separate frequency domain signals
			// and keep track of the power per bin.
			avgptr = (mem_addr_t)avg_power->aligned;
			for (u32_t s = 1; s <= num_subbands; s++) {
				kiss_fft_cpx ck, cnk;
				FFT_GET_OUT_CPX(FFT_OFFSET_MEM(fft_output, s), ck);
				FFT_GET_OUT_CPX(FFT_OFFSET_MEM(fft_output, sample_window-s), cnk);

				s32_t r = (ck.r + cnk.r)/2;
				s32_t i = (ck.i - cnk.i)/2;

				u32_t avg = paged_read_u32(avg_power, avgptr);
				avg += (r * r + i * i)/num_windows;
				paged_write_u32(avg_power, avgptr, avg);
				avgptr += sizeof(u32_t);

				r = (cnk.i + ck.i)/2;
				i = (cnk.r - ck.r)/2;

				avg = paged_read_u32(avg_power, avgptr);
				avg += (r * r + i * i)/num_windows;
				paged_write_u32(avg_power, avgptr, avg);
				avgptr += sizeof(u32_t);
			}
		}
	}

	mem_addr_t pptr = (mem_addr_t)preemphasis->aligned;
	avgptr = (mem_addr_t)avg_power->aligned;
	for (u32_t p = 0; p < num_subbands; p++) {
		// XXX Need to check for clipping
		u64_t product = (u64_t)paged_read_u32(avg_power, avgptr) * (u64_t)paged_read_u32(preemphasis, pptr);
		product >>= 16;
		paged_write_u32(avg_power, avgptr, (u32_t)product);
		avgptr += sizeof(u32_t);

		product = (u64_t)paged_read_u32(avg_power, avgptr) * (u64_t)paged_read_u32(preemphasis, pptr);
		product >>= 16;
		paged_write_u32(avg_power, avgptr, (u32_t)product);
		avgptr += sizeof(u32_t);
		pptr += sizeof(fft_fixed);
	}

	// Draw the power spectrum. We do this in an allocated buffer,
	// though, with some effort, it could be done directly into
	// the VFD frame buffer.
	framebuf_addr_t fb = decode_framebuf_viz;
	
	// Offset by the frame position
	int offset = channel_position[0] * WORDS_PER_COLUMN;

	// Render the first channel
	render_channel(0, fb, offset);

	if (!is_mono) {
		// And the second channel
		offset = channel_position[1] * WORDS_PER_COLUMN;
		render_channel(1, fb, offset);	
	}

	paged_flush(decode_framebuf_viz);
	graphics_update();
}

u32_t visualizer_spectrum_frame_rate(void) {
	return FRAME_RATE;
}

void visualizer_spectrum_end(void) {

	DEBUG_PRINTF("killing spectrum analyzer");
	if (cfg) {
		cfg = NULL;
	}
}

typedef struct {
	u32_t *ptr;
	u32_t value;
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

#define NUM_DEFAULTS 3

static spectrum_defaults_t defaults[NUM_DEFAULTS] = {
  { &is_mono, 0 },
  { &bandwidth_half, 0 },
  { &preemphasis_db_per_khz, 0x10000 }
};


#define NUM_CHANNEL_DEFAULTS 8

static spectrum_defaults_t channel_defaults[2][NUM_CHANNEL_DEFAULTS] = {
  {
    { &channel_position[0],  24 },
    { &channel_width[0], 128 },
    { &channel_flipped[0], FALSE },
    { &bar_width[0], 1 },
    { &bar_spacing[0], 0 },
    { &clip_subbands[0], FALSE },
    { &bar_grey_level[0], 1 },
    { &bar_cap_grey_level[0], 3 }
  },
  {
    { &channel_position[1],  168 },
    { &channel_width[1], 128 },
    { &channel_flipped[1], TRUE },
    { &bar_width[1], 1 },
    { &bar_spacing[1], 0 },
    { &clip_subbands[1], FALSE },
    { &bar_grey_level[1], 1 },
    { &bar_cap_grey_level[1], 3 }
  }
};


void visualizer_spectrum_begin(u32_t *params, u32_t num_params) {
	filter_window_init();
	preemphasis_init();
	last_values_init();
	avg_power_init();

	// Get visualizer parameters (or defaults)
	u32_t d, p = 0;
	for (d = 0; d < NUM_DEFAULTS; d++) {
		if (p < num_params) {
			*(defaults[d].ptr) = params[p];
		}
		else {
			*(defaults[d].ptr) = defaults[d].value;
		}
		p++;
	}

	// Get the first channel parameters (or defaults)
	for (d = 0; d < NUM_CHANNEL_DEFAULTS; d++) {
		if (p < num_params) {
			*(channel_defaults[0][d].ptr) = params[p];
		}
		else {
			*(channel_defaults[0][d].ptr) = channel_defaults[0][d].value;
		}
		p++;
	}

	if (!is_mono) {
		// Get the second channel parameters (or defaults)
		for (d = 0; d < NUM_CHANNEL_DEFAULTS; d++) {
			if (p < num_params) {
				*(channel_defaults[1][d].ptr) = params[p];
			}
			else {
				*(channel_defaults[1][d].ptr) = channel_defaults[1][d].value;
			}
			p++;
		}
	}

	// Convert bar cap values to actual pixel values
	for (int ch = 0; ch < 2; ch++) {
		if (bar_cap_grey_level[ch] <= 1) {
			bar_cap_grey_level[ch] = 2;
		}
		else if (bar_cap_grey_level[ch] == 2) {
			bar_cap_grey_level[ch] = 1;
		}
		else {
			bar_cap_grey_level[ch] = 3;
		}
	}

	for (int ch = 0; ch < 2; ch++) {
		if (channel_width[ch] > COLUMNS_PER_FRAME) {
			channel_width[ch] = COLUMNS_PER_FRAME;
		}
	
		if ((channel_position[ch] + channel_width[ch]) > COLUMNS_PER_FRAME) {
			channel_position[ch] = COLUMNS_PER_FRAME - channel_width[ch];
		}
	}

	// Approximate the number of subbands we'll display based
	// on the width available and the size of the histogram
	// bars.
	u32_t bar_size = bar_width[0] + bar_spacing[0];
	num_subbands = channel_width[0] / bar_size;

	// Calculate the integer component of the log2 of the num_subbands
	u32_t l2int = 0;
	u32_t shiftsubbands = num_subbands;
	while (shiftsubbands != 1) {
		l2int++;
		shiftsubbands >>= 1;
	}

	// The actual number of subbands is the largest power
	// of 2 smaller than the specified width.
	num_subbands = 1L << l2int;

	// In the case where we're going to clip the higher
	// frequency bands, we choose the next highest
	// power of 2. 
	if (clip_subbands[0]) {
		num_subbands <<= 1;
	}

	// The number of histogram bars we'll display is nominally
	// the number of subbands we'll compute.
	num_bars[0] = num_subbands;

	// Though we may have to compute more subbands to meet
	// a minimum and average them into the histogram bars.
	if (num_subbands < MIN_SUBBANDS) {
		subbands_in_bar[0] = MIN_SUBBANDS / num_subbands;
		num_subbands = MIN_SUBBANDS;
	}
	else {
		subbands_in_bar[0] = 1;
	}

	// If we're clipping off the higher subbands we cut down
	// the actual number of bars based on the width available.
	if (clip_subbands[0]) {
		num_bars[0] = channel_width[0] / bar_size;
	}

	// Since we now have a fixed number of subbands, we choose
	// values for the second channel based on these.
	if (!is_mono) {
		bar_size = bar_width[1] + bar_spacing[1];
		num_bars[1] = channel_width[1] / bar_size;
		subbands_in_bar[1] = 1;
		// If we have enough space for all the subbands, great.
		if (num_bars[1] > num_subbands) {
			num_bars[1] = num_subbands;  
		}
		// If not, we find the largest factor of the
		// number of subbands that we can show.
		else if (!clip_subbands[1]) {
			u32_t s = num_subbands;
			subbands_in_bar[1] = 1;
			while (s > num_bars[1]) {
				s >>= 1;
				subbands_in_bar[1]++;
			}
			num_bars[1] = s;
		}
	}

	// Calculate the number of samples we'll need to send in as
	// input to the FFT. If we're halving the bandwidth (by
	// averaging adjacent samples), we're going to need twice
	// as many.
	sample_window = num_subbands * 2;

	if (sample_window < MIN_FFT_INPUT_SAMPLES) {
		num_windows = MIN_FFT_INPUT_SAMPLES / sample_window;
	}
	else {
		num_windows = 1;
	}

	samples_in_chunk = CHUNK_SIZE / (2 * sizeof(u32_t));
	if (bandwidth_half) {
		samples_in_chunk >>= 1;
	}
	
	if (sample_window <= samples_in_chunk) {
		num_reads = 1;
	}
	else {
		num_reads = sample_window / samples_in_chunk;
	}

	if (!cfg) {
		cfg = (mem_addr_t)fft_state;
		kiss_fft_init(sample_window, 0, cfg);

		mem_addr_t lvptr = (mem_addr_t)last_values->aligned;
		for (int ch = 0; ch < 2; ch++) {
			for (u32_t s = 0; s < num_subbands; s++) {
				paged_write_u32(last_values, lvptr, 0);
				lvptr += sizeof(u32_t);
			}
		}

		// Compute the Hamming window. This could be precomputed.
		fft_fixed const1 = double_to_fixed(0.54);
		fft_fixed const2 = double_to_fixed(0.46);
		mem_addr_t fw = (mem_addr_t)filter_window->aligned;
		for (u32_t w = 0; w < sample_window; w++) {
			const double twopi = 6.283185307179586476925286766;

			fft_fixed window = const1 - (fixed_mul(const2, fixed_cos(double_to_fixed(twopi*(double)w/(double)sample_window))));
			paged_write_u32(filter_window, fw, window);
			fw += sizeof(fft_fixed);
		}

#define FIXED_22050 0x56220000
#define FIXED_1000 0x3E80000

		// Compute the preemphasis
		// XXX Assume a 22.05KHz Nyquist frequency...we should
		// look this up dynamically.
		fft_fixed subband_width = fixed_div(FIXED_22050,
						    s32_to_fixed(num_subbands));
		fft_fixed freq_sum = 0;
		fft_fixed scale_db = 0;
		mem_addr_t pptr = (mem_addr_t)preemphasis->aligned;
		for (u32_t s = 0; s < num_subbands; s++) {
			while (freq_sum > FIXED_1000) {
				freq_sum -= FIXED_1000;
				scale_db += preemphasis_db_per_khz;
			}
			if (scale_db) {
				fft_fixed pre = fixed_div(scale_db, s32_to_fixed(10));
				paged_write_u32(preemphasis, pptr, fixed_exp10(pre));
			}
			else {
				paged_write_u32(preemphasis, pptr, FIXED_ONE);
			}
			pptr += sizeof(fft_fixed);
			freq_sum += subband_width;
		}
	}
}

#endif

