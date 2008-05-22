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

#include "fixed_math.h"

fft_fixed fixed_sqrt(fft_fixed n) {
	int i;
	fft_fixed s;

	s = (n + 65536) >> 1;
	for (i = 0; i < 8; i++) {
	    //converge six times
	    s = (s + fixed_div(n, s)) >> 1;
	}
	return s;
}

fft_fixed fixed_round(fft_fixed n) {
	if (n > 0) {
		if ((n & 0x8000) != 0) {
			return (((n+0x10000)>>16)<<16);
		} else {
			return (((n)>>16)<<16);
		}
	} else {
		fft_fixed k;
		n = -n;
		if ((n & 0x8000) != 0) {
			k = (((n+0x10000)>>16)<<16);
		} else {
			k = (((n)>>16)<<16);
		}
		return -k;
	}
}

#define FIXED_PI	205887
#define FIXED_PI_OVER_2	FIXED_PI/2
#define FIXED_E		178145
#define FIXED_HALF	2<<15

#define SK1	498
#define SK2	10882


/** Computes SIN(f), f is a fixed point number in radians.
 * 0 <= f <= 2PI
 */
fft_fixed fixed_sin(fft_fixed f) {
	int sign;
	fft_fixed sqr, result;

	// If in range -pi/4 to pi/4: nothing needs to be done.
	// otherwise, we need to get f into that range and account for
	// sign change.

	sign = 1;
	if (f < 0) {
		f = -f;
		sign = -1;
	}
	if ((f > FIXED_PI_OVER_2) && (f <= FIXED_PI)) {
	    f = FIXED_PI - f;
	} else if ((f > FIXED_PI) && (f <= (FIXED_PI + FIXED_PI_OVER_2))) {
	    f = f - FIXED_PI;
	    sign *= -1;
	} else if (f > (FIXED_PI + FIXED_PI_OVER_2)) {
	    f = (FIXED_PI<<1)-f;
	    sign *= -1;
	}

	sqr = fixed_mul(f,f);
	result = SK1;
	result = fixed_mul(result, sqr);
	result -= SK2;
	result = fixed_mul(result, sqr);
	result += (1<<16);
	result = fixed_mul(result, f);
	return sign * result;
}

#define CK1	2328
#define CK2	32551

/** Computes COS(f), f is a fixed point number in radians.
 * 0 <= f <= PI/2
 */
fft_fixed fixed_cos(fft_fixed f) {
	int sign;
	fft_fixed sqr, result;

	if (f < 0) {
		f = -f;
	}
	sign = 1;
	if ((f > FIXED_PI_OVER_2) && (f <= FIXED_PI)) {
	    f = FIXED_PI - f;
	    sign = -1;
	} else if ((f > FIXED_PI_OVER_2) && (f <= (FIXED_PI + FIXED_PI_OVER_2))) {
	    f = f - FIXED_PI;
	    sign = -1;
	} else if (f > (FIXED_PI + FIXED_PI_OVER_2)) {
	    f = (FIXED_PI<<1)-f;
	}

	sqr = fixed_mul(f,f);
	result = CK1;
	result = fixed_mul(result, sqr);
	result -= CK2;
	result = fixed_mul(result, sqr);
	result += (1<<16);
	return result * sign;
}

static fft_fixed fpfact[] = { 
	1<<16,
	1<<16,
	2<<16,
	6<<16,
	24<<16,
	120<<16,
	720<<16,
	5040<<16,
	40320<<16
};

fft_fixed fixed_exp(fft_fixed x) {
	fft_fixed result = 1<<16;
	fft_fixed x2 = fixed_mul(x,x);
	fft_fixed x3 = fixed_mul(x2,x);
	fft_fixed x4 = fixed_mul(x2,x2);
	fft_fixed x5 = fixed_mul(x4,x);
	fft_fixed x6 = fixed_mul(x4,x2);
	fft_fixed x7 = fixed_mul(x6,x);
	fft_fixed x8 = fixed_mul(x4,x4);
	return result + x 
	    + fixed_div(x2,fpfact[2]) 
	    + fixed_div(x3,fpfact[3]) 
	    + fixed_div(x4,fpfact[4])
	    + fixed_div(x5,fpfact[5]) 
	    + fixed_div(x6,fpfact[6]) 
	    + fixed_div(x7,fpfact[7])
	    + fixed_div(x8,fpfact[8]);
}

fft_fixed fixed_pow(fft_fixed x, fft_fixed y) {
    if (x == 0) {
	return 0;
    }
    
    if (y == 0) {
	return FIXED_ONE;
    }

    return fixed_exp(fixed_mul(y, fixed_ln(x)));
}

static fft_fixed log2arr[] = {
	26573,
	14624,
	7719,
	3973,
	2017,
	1016,
	510,
	256,
	128,
	64,
	32,
	16,
	8,
	4,
	2,
	1,
	0,
	0,
	0
};

static fft_fixed lnscale[] = {
	0,
	45426,
	90852,
	136278,
	181704,
	227130,
	272557,
	317983,
	363409,
	408835,
	454261,
	499687,
	545113,
	590539,
	635965,
	681391,
	726817
};

fft_fixed fixed_ln(fft_fixed x) {
	// prescale so x is between 1 and 2
	int i, shift = 0;
	fft_fixed g, d;

	while (x > 1<<17) {
	    shift++;
	    x >>= 1;
	}

	g = 0;
	d = FIXED_HALF;
	for (i = 1; i < 16; i++) {
	    if (x > ((1<<16) + d)) {
		x = fixed_div(x, ( (1<<16) + d));
		g += log2arr[i-1];   // log2arr[i-1] = log2(1+d);
	    }
	    d >>= 1;
	}
	return g + lnscale[shift];
}

#define FIXED_LOG_E 0x6f2e

// log10 is log10(e) * ln(x)
fft_fixed fixed_log10(fft_fixed x) {
	return fixed_mul(FIXED_LOG_E, fixed_ln(x));
}

#define FIXED_LN_10 0x24d76

// exp10(x) is exp(x * ln(10))
fft_fixed fixed_exp10(fft_fixed x) {
	return fixed_exp(fixed_mul(x, FIXED_LN_10));
}
