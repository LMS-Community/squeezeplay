/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "stdio.h"

#ifndef SQUEEZEPLAY_LOG_H
#define SQUEEZEPLAY_LOG_H

/*
 * Lightweight logging api with a compatible api to log4c
 */

#ifdef _WIN32
	#define __func__ __FUNCTION__
#endif

/* Priority levels, that correspond to syslog */
enum log_priority {
	LOG_PRIORITY_OFF	= 0,
	LOG_PRIORITY_ERROR	= 300,
	LOG_PRIORITY_WARN	= 400,
	LOG_PRIORITY_INFO	= 600,
	LOG_PRIORITY_DEBUG	= 700,
};


struct log_category {
	struct log_category *next;
	enum log_priority priority;
	char name[0];
};


extern void log_init();
extern void log_free();
extern struct log_category *log_category_get(const char *name);
extern void log_category_vlog(struct log_category *category, enum log_priority priority, const char *format, va_list args);
extern const char *log_category_get_name(struct log_category *category);
extern enum log_priority log_category_get_priority(struct log_category *category);
extern void log_category_set_priority(struct log_category *category, enum log_priority priority);
extern const char *log_priority_to_string(enum log_priority priority);
extern enum log_priority log_priority_to_int(const char *str);


static __inline void log_category_log(struct log_category *category, enum log_priority priority, const char *format, ...) {
	if (category->priority >= priority) {
		va_list va;
		va_start(va, format);
		log_category_vlog(category, priority, format, va);
		va_end(va);
	}
}


/*
 * Log using these defines in the C code, this will allow switching to a
 * different logging api if needed in the future.
 */

#define LOG_CATEGORY struct log_category

/* note that loggers must be created in the main thread only */
#define LOG_CATEGORY_GET(name) log_category_get(name)

#define LOG_ERROR(cat, fmt, ...) \
	log_category_log(cat, LOG_PRIORITY_ERROR, "%s:%d " fmt, __func__, __LINE__, ##__VA_ARGS__)

#define LOG_WARN(cat, fmt, ...) \
	log_category_log(cat, LOG_PRIORITY_WARN, "%s:%d " fmt, __func__, __LINE__, ##__VA_ARGS__)

#define LOG_INFO(cat, fmt, ...) \
	log_category_log(cat, LOG_PRIORITY_INFO, "%s:%d " fmt, __func__, __LINE__, ##__VA_ARGS__)

#define LOG_DEBUG(cat, fmt, ...) \
	log_category_log(cat, LOG_PRIORITY_DEBUG, "%s:%d " fmt, __func__, __LINE__, ##__VA_ARGS__)

#define IS_LOG_PRIORITY(cat, priority) \
	(log_category_get_priority(cat) >= priority)

#endif // SQUEEZEPLAY_LOG_H
