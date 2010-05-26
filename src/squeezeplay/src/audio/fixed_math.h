/**
 * Derived from Java version of:
 *
 * 16:16 fixed point math routines, for IAppli/CLDC platform.
 * A fixed point number is a 32 bit int containing 16 bits of integer
 * and 16 bits of fraction.
 *
 * (C) 2001 Beartronics 
 * Author: Henry Minsky (hqm@alum.mit.edu)
 *
 * Licensed under terms "Artistic License"
 * http://www.opensource.org/licenses/artistic-license.html
 *
 * Numerical algorithms based on
 * http://www.cs.clemson.edu/html_docs/SUNWspro/common-tools/numerical_comp_guide/ncg_examples.doc.html
 *
 * Trig routines based on numerical algorithms described in 
 * http://www.magic-software.com/MgcNumerics.html
 *
 * http://www.dattalo.com/technical/theory/logs.html
 *
 */

/*
 * Modification history:
 * 12/02/04 - vidur - Ported fixed math routines to use Ubicom SDK types
 * 1/12/05 - vidur - Added log10 and exp10 implementations
 */

#ifndef __FIXED_MATH_H__
#define __FIXED_MATH_H__

#include "common.h"

typedef s32_t fft_fixed;

#define FIXED_ONE 0x10000
#define FIXED_FRAC_BITS 16

static inline s32_t fixed_to_s32(fft_fixed x) {
	return x >> 16;
}

static inline fft_fixed s32_to_fixed(s32_t x) {
	return x << 16;
}

static inline double fixed_to_double(fft_fixed x) {
	return ((double)((x) / (double) (1L << 16)));
}

static inline fft_fixed double_to_fixed(double x) {
	return ((fft_fixed) ((x) * (double) (1L << 16) + 0.5));
}

#if defined(__GNUC__) && defined (__arm__)
/* This is about 50% faster than the C version */
static inline fft_fixed fixed_mul(fft_fixed x, fft_fixed y) {
	register s32_t __hi, __lo, __result;
	asm(
		"smull %0, %1, %3, %4\n\t"
		"movs %0, %0, lsr #16\n\t"
		"adc %2, %0, %1, lsl #16"
		: "=&r" (__lo), "=&r" (__hi), "=r" (__result)
		: "%r" (x), "r" (y)
		: "cc"
	);
	return __result;
}
#else
static inline fft_fixed fixed_mul(fft_fixed x, fft_fixed y) {
	s64_t z = (s64_t)x * (s64_t)y;
	return (s32_t) (z >> 16);
}
#endif

static inline fft_fixed fixed_div(fft_fixed x, fft_fixed y) {
	s64_t z = ((s64_t)x << 32);
	return (s32_t) ((z / y) >> 16);
}

extern fft_fixed fixed_sqrt(fft_fixed n);

extern fft_fixed fixed_round(fft_fixed n);

/** Computes SIN(f), f is a fixed point number in radians.
 * 0 <= f <= 2PI
 */
extern fft_fixed fixed_sin(fft_fixed f);

/** Computes COS(f), f is a fixed point number in radians.
 * 0 <= f <= PI/2
 */
extern fft_fixed fixed_cos(fft_fixed f);

extern fft_fixed fixed_pow(fft_fixed x, fft_fixed y);

extern fft_fixed fixed_exp(fft_fixed x);

extern fft_fixed fixed_ln(fft_fixed x);

extern fft_fixed fixed_log10(fft_fixed x);

extern fft_fixed fixed_exp10(fft_fixed x);

#endif // __FIXED_MATH_H__
