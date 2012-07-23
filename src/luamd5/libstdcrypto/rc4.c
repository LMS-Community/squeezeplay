/* Public domain. */
/* Thanks to Thomas Pornin <pornin@bolet.org> */

#include "bytestr.h"
#include "rc4.h"

void rc4 (RC4Schedule_ref r, char const *in, char *out, unsigned int n)
{
  register unsigned int i = 0 ;
  for (; i < n ; i++)
  {
    register unsigned char t ;
    r->x = T8(r->x + 1) ;
    t = r->tab[r->x] ;
    r->y = T8(r->y + t) ;
    r->tab[r->x] = r->tab[r->y] ;
    r->tab[r->y] = t ;
    out[i] = (unsigned char)in[i] ^ T8(r->tab[r->x] + r->tab[r->y]) ;
  }
}
