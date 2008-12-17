/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

/*
 * Debug macros
 */

/*
 * RUNTIME_DEBUG
 * If defined, program will output debugging information
 */
//#define RUNTIME_DEBUG
//#define RUNTIME_DEBUG_GARBAGE
//#define RUNTIME_DEBUG_VERBOSE
//#define RUNTIME_DEBUG_DRAW

#define DEBUG_ERROR(fmt, ...) fprintf(stderr, "%s:%d ERROR " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);

#if RUNTIME_DEBUG
#define DEBUG_TRACE(fmt, ...) fprintf(stderr, "%s:%d DEBUG " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);
#else
#define DEBUG_TRACE(fmt, ...)
#endif

#if RUNTIME_DEBUG_GARBAGE
#define DEBUG_GARBAGE(fmt, ...) fprintf(stderr, "%s:%d DEBUG " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);
#else
#define DEBUG_GARBAGE(fmt, ...)
#endif

#if RUNTIME_DEBUG_VERBOSE
#define DEBUG_VERBOSE(fmt, ...) fprintf(stderr, "%s:%d VERBOSE " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);
#else
#define DEBUG_VERBOSE(fmt, ...)
#endif

#if RUNTIME_DEBUG_DRAW
#define DEBUG_DRAW(fmt, ...) fprintf(stderr, "%s:%d DRAW " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__);
#else
#define DEBUG_DRAW(fmt, ...)
#endif
