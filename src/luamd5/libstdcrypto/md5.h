/* Public domain. */

#ifndef MD5_H
#define MD5_H

//#include "uint32.h"
#include "common.h"

typedef struct MD5Schedule MD5Schedule, *MD5Schedule_ref ;
struct MD5Schedule
{
  uint32 buf[4] ;
  uint32 bits[2] ;
  unsigned char in[64] ;
} ;

#define MD5_INIT() { {0x67452301UL, 0xefcdab89UL, 0x98badcfeUL, 0x10325476UL}, {0, 0}, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" }
extern void md5_init (MD5Schedule_ref) ;
extern void md5_update (MD5Schedule_ref, char const *, unsigned int) ;
extern void md5_final (MD5Schedule_ref, char * /* 16 chars */) ;

#endif
