/* $Id: ares_version.c,v 1.3 2004-07-22 22:18:45 bagder Exp $ */

#include "setup.h"
#include "ares_version.h"

const char *ares_version(int *version)
{
  if(version)
    *version = ARES_VERSION;

  return ARES_VERSION_STR;
}
