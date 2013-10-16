#ifndef _COMMON_H
#define _COMMON_H

#include <string.h>

typedef unsigned int uint32;
#define T8(x)   ((x) & 0xffU)

#define uint32_little_endian(s, n) //uint32_reverse((s), (n))

void uint32_pack_big (char *, uint32);

#endif // _COMMON_H
