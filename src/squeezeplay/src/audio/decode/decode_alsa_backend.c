/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"

#ifdef HAVE_SYSLOG
#include <syslog.h>
#endif

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/mqueue.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBASOUND

#include <alsa/asoundlib.h>

/* for real-time behaviour */
#include <malloc.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/resource.h>


/* COMPAT */
#undef LOG_DEBUG
#undef LOG_INFO
#undef LOG_WARN
#undef LOG_ERROR
#undef IS_LOG_PRIORITY

static int is_debug = 0;

static __inline void log_printf(int level, const char *format, ...) {
	char buf[255];
	va_list va;

	va_start(va, format);
	vsnprintf(buf, sizeof(buf), format, va);
	va_end(va);

	if (is_debug) {
		char *lstr;

		switch (level) {
		case LOG_PRIORITY_ERROR:
			lstr = "ERROR";
			break;
		case LOG_PRIORITY_WARN:
			lstr = "WARN";
			break;
		case LOG_PRIORITY_INFO:
			lstr = "INFO";
			break;
		default:
		case LOG_PRIORITY_DEBUG:
			lstr = "DEBUG";
			break;
		}

		printf("%-6s %s\n", lstr, buf);
	}

#ifdef HAVE_SYSLOG
	syslog(level, "%s", buf);
#endif
}

#define LOG_DEBUG(FMT, ...) { if (is_debug) log_printf(LOG_PRIORITY_DEBUG, "%s:%d " FMT, __func__, __LINE__, ##__VA_ARGS__); }
#define LOG_INFO(FMT, ...) log_printf(LOG_PRIORITY_INFO, "%s:%d " FMT, __func__, __LINE__, ##__VA_ARGS__)
#define LOG_WARN(FMT, ...) log_printf(LOG_PRIORITY_WARN, "%s:%d " FMT, __func__, __LINE__, ##__VA_ARGS__)
#define LOG_ERROR(FMT, ...) log_printf(LOG_PRIORITY_ERROR, "%s:%d " FMT, __func__, __LINE__, ##__VA_ARGS__)
#define IS_LOG_PRIORITY(LEVEL) ((LEVEL==LOG_PRIORITY_DEBUG)?is_debug:1)


/* debug switches */
#define TEST_LATENCY 1


u8_t *decode_fifo_buf;
u8_t *effect_fifo_buf;
struct decode_audio *decode_audio;

#define FLAG_STREAM_PLAYBACK 0x01
#define FLAG_STREAM_EFFECTS  0x02
#define FLAG_STREAM_NOISE    0x04


struct decode_alsa {
	/* device configuration */
	const char *device;
	u32_t flags;
	unsigned int buffer_time;
	unsigned int period_count;

	/* alsa pcm state */
	snd_pcm_t *pcm;
	snd_pcm_hw_params_t *hw_params;
	snd_pcm_sframes_t period_size;

	/* alsa control state */
	snd_hctl_t *hctl;
	snd_hctl_elem_t *iec958_elem;

	/* playback state */
	u32_t pcm_sample_rate;

	/* parent */
	pid_t parent_pid;
};


/* alsa debugging */
static snd_output_t *output;

/* player state */
static struct decode_alsa state;


#ifndef timersub
#define	timersub(a, b, result) \
do { \
	(result)->tv_sec = (a)->tv_sec - (b)->tv_sec; \
	(result)->tv_usec = (a)->tv_usec - (b)->tv_usec; \
	if ((result)->tv_usec < 0) { \
		--(result)->tv_sec; \
		(result)->tv_usec += 1000000; \
	} \
} while (0)
#endif


#if TEST_LATENCY
#define TIMER_INIT(TOUT)			\
		struct timeval _t1, _t2, _td;	\
		float _tf, _tout = TOUT;	\
		gettimeofday(&_t1, 0);

#define TIMER_CHECK(NAME) {					\
		gettimeofday(&_t2, 0);					\
		timersub(&_t2, &_t1, &_td);				\
		_tf = _td.tv_sec * 1000 + _td.tv_usec / 1000.0;		\
		if (_tf > _tout) {					\
			LOG_WARN(NAME " took too long %.3f ms", _tf); \
		}							\
		memcpy(&_t1, &_t2, sizeof(struct timeval));		\
	}
#else
#define TIMER_INIT(TOUT)
#define TIMER_CHECK(NAME)
#endif


static void debug_pagefaults()
{
 	static struct rusage last_usage;
   	struct rusage usage;
	long majflt, minflt;
   
   	getrusage(RUSAGE_SELF, &usage);

	majflt = usage.ru_majflt - last_usage.ru_majflt;
	minflt = usage.ru_minflt - last_usage.ru_minflt;
	if (majflt > 0 || minflt > 0) {
		LOG_WARN("Pagefaults, Major:%ld Minor:%ld", majflt, minflt);
	}

	memcpy(&last_usage, &usage, sizeof(struct rusage));
}


/* noise source for testing */
static void generate_noise(void *outputBuffer,
			   unsigned long framesPerBuffer)
{
	sample_t val, *output_ptr = (sample_t *)outputBuffer;

	while (framesPerBuffer--) {
		val = rand() % 256 - 127;
		*output_ptr++ += val << 15;
		output_ptr++;
	}
}


static void decode_alsa_copyright(struct decode_alsa *state,
				  bool_t copyright)
{
	snd_ctl_elem_value_t *control;
	snd_aes_iec958_t iec958;
	int err;

	LOG_DEBUG("copyright %s asserted", (copyright)?"is":"not");

	if (!state->iec958_elem) {
		/* not supported */
		return;
	}

	/* dies with warning on GCC 4.2:
	 * snd_ctl_elem_value_alloca(&control);
	 */
	control = (snd_ctl_elem_value_t *) alloca(snd_ctl_elem_value_sizeof());
	memset(control, 0, snd_ctl_elem_value_sizeof());

	if ((err = snd_hctl_elem_read(state->iec958_elem, control)) < 0) {
		LOG_ERROR("snd_hctl_elem_read error: %s", snd_strerror(err));
		return;
	}

	snd_ctl_elem_value_get_iec958(control, &iec958);

	/* 0 = copyright, 1 = not copyright */
	if (copyright) {
		iec958.status[0] &= ~(1<<2);
	}
	else {
		iec958.status[0] |= (1<<2);
	}

	snd_ctl_elem_value_set_iec958(control, &iec958);

	LOG_DEBUG("iec958 status: %02x %02x %02x %02x",
		  iec958.status[0], iec958.status[1], iec958.status[2], iec958.status[3]);

	if ((err = snd_hctl_elem_write(state->iec958_elem, control)) < 0) {
		LOG_ERROR("snd_hctl_elem_write error: %s", snd_strerror(err));
		return;
	}
}


/*
 * This function is called by to copy samples from the output buffer to
 * the alsa buffer.
 *
 * Called with fifo-lock held.
 */
static void playback_callback(struct decode_alsa *state,
			      void *outputBuffer,
			      unsigned long framesPerBuffer) {
	size_t bytes_used, len, skip_bytes = 0, add_bytes = 0;
	int add_silence_ms;
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;

	// XXXX full port from ip3k

	ASSERT_AUDIO_LOCKED();

	len = SAMPLES_TO_BYTES(framesPerBuffer);

	/* audio running? */
	if (!(decode_audio->state & DECODE_STATE_RUNNING)) {
		memset(outputArray, 0, len);

		return;
	}

	add_silence_ms = decode_audio->add_silence_ms;
	if (add_silence_ms) {
		add_bytes = SAMPLES_TO_BYTES((u32_t)((add_silence_ms * state->pcm_sample_rate) / 1000));
		if (add_bytes > len) {
			add_bytes = len;
		}
		memset(outputArray, 0, add_bytes);
		outputArray += add_bytes;
		len -= add_bytes;
		add_silence_ms -= (BYTES_TO_SAMPLES(add_bytes) * 1000) / state->pcm_sample_rate;
		if (add_silence_ms < 2) {
			add_silence_ms = 0;
		}
		if (!len) {
			return;
		}
	}

	bytes_used = fifo_bytes_used(&decode_audio->fifo);
	
	/* only skip if it will not cause an underrun */
	if (bytes_used >= len && decode_audio->skip_ahead_bytes > 0) {
		skip_bytes = bytes_used - len;
		if (skip_bytes > decode_audio->skip_ahead_bytes) {
			skip_bytes = decode_audio->skip_ahead_bytes;
		}
	}

	if (bytes_used > len) {
		bytes_used = len;
	}

	/* audio underrun? */
	if (bytes_used == 0) {
		decode_audio->state |= DECODE_STATE_UNDERRUN;
		memset(outputArray, 0, len);
		LOG_ERROR("Audio underrun: used 0 bytes");

		return;
	}

	if (bytes_used < len) {
		decode_audio->state |= DECODE_STATE_UNDERRUN;
		memset(outputArray + bytes_used, 0, len - bytes_used);
		LOG_ERROR("Audio underrun: used %d bytes , requested %d bytes", (int)bytes_used, (int)len);
	}
	else {
		decode_audio->state &= ~DECODE_STATE_UNDERRUN;
	}
	
	if (skip_bytes) {
		size_t wrap;

		LOG_DEBUG("Skipping %d bytes", (int)skip_bytes);
		
		wrap = fifo_bytes_until_rptr_wrap(&decode_audio->fifo);

		if (wrap < skip_bytes) {
			fifo_rptr_incby(&decode_audio->fifo, wrap);
			skip_bytes -= wrap;
			decode_audio->skip_ahead_bytes -= wrap;
			decode_audio->elapsed_samples += BYTES_TO_SAMPLES(wrap);
		}

		fifo_rptr_incby(&decode_audio->fifo, skip_bytes);
		decode_audio->skip_ahead_bytes -= skip_bytes;
		decode_audio->elapsed_samples += BYTES_TO_SAMPLES(skip_bytes);
	}

	while (bytes_used) {
		size_t wrap, bytes_write, samples_write;
		sample_t *output_ptr, *decode_ptr;

		wrap = fifo_bytes_until_rptr_wrap(&decode_audio->fifo);

		bytes_write = bytes_used;
		if (wrap < bytes_write) {
			bytes_write = wrap;
		}

		samples_write = BYTES_TO_SAMPLES(bytes_write);

		output_ptr = (sample_t *)(void *)outputArray;
		decode_ptr = (sample_t *)(void *)(decode_fifo_buf + decode_audio->fifo.rptr);
		while (samples_write--) {
			*(output_ptr++) = fixed_mul(decode_audio->lgain, *(decode_ptr++));
			*(output_ptr++) = fixed_mul(decode_audio->rgain, *(decode_ptr++));
		}

		fifo_rptr_incby(&decode_audio->fifo, bytes_write);
		decode_audio->elapsed_samples += BYTES_TO_SAMPLES(bytes_write);

		outputArray += bytes_write;
		bytes_used -= bytes_write;
	}

	reached_start_point = decode_check_start_point();
	if (reached_start_point) {
		if (decode_audio->track_sample_rate != state->pcm_sample_rate) {
			decode_audio->set_sample_rate = decode_audio->track_sample_rate;
		}

		decode_alsa_copyright(state, decode_audio->track_copyright);
	}
}


static int pcm_close(struct decode_alsa *state) {
	int err;

	if (state->pcm) {
		if ((err = snd_pcm_drain(state->pcm)) < 0) {
			LOG_ERROR("snd_pcm_drain error: %s", snd_strerror(err));
		}

		if ((err = snd_pcm_close(state->pcm)) < 0) {
			LOG_ERROR("snd_pcm_close error: %s", snd_strerror(err));
		}

		snd_pcm_hw_params_free(state->hw_params);

		state->pcm = NULL;
	}

	if (state->hctl) {
		snd_hctl_close(state->hctl);
		state->hctl = NULL;
		state->iec958_elem = NULL;
	}

	return 0;
}


static int pcm_open(struct decode_alsa *state) {
	int err;
	unsigned int val;
	snd_pcm_uframes_t size;
	snd_ctl_elem_id_t *id;
	u32_t set_sample_rate;

	decode_audio_lock();
	set_sample_rate = decode_audio->set_sample_rate;
	decode_audio->set_sample_rate = 0;
	decode_audio_unlock();

	/* Close existing pcm (if any) */
	if (state->pcm) {
		pcm_close(state);
	}

	/* Open pcm */
	if ((err = snd_pcm_open(&state->pcm, state->device, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
		LOG_ERROR("Playback open error: %s", snd_strerror(err));
		return err;
	}

	/* Set hardware parameters */
	if ((err = snd_pcm_hw_params_malloc(&state->hw_params)) < 0) {
		LOG_ERROR("hwparam malloc error: %s", snd_strerror(err));
		return err;
	}

	/* set hardware resampling */
	if ((err = snd_pcm_hw_params_any(state->pcm, state->hw_params)) < 0) {
		LOG_ERROR("hwparam init error: %s", snd_strerror(err));
		return err;
	}

	if ((err = snd_pcm_hw_params_set_rate_resample(state->pcm, state->hw_params, 1)) < 0) {
		LOG_ERROR("Resampling setup failed: %s", snd_strerror(err));
		return err;
	}

	/* set mmap interleaved access format */
	if ((err = snd_pcm_hw_params_set_access(state->pcm, state->hw_params, SND_PCM_ACCESS_MMAP_INTERLEAVED)) < 0) {
		LOG_ERROR("Access type not available: %s", snd_strerror(err));
		return err;
	}

	/* set the sample format */
	if ((err = snd_pcm_hw_params_set_format(state->pcm, state->hw_params, SND_PCM_FORMAT_S32_LE)) < 0) {
		LOG_ERROR("Sample format not available: %s", snd_strerror(err));
		return err;
	}

	/* set the channel count */
	if ((err = snd_pcm_hw_params_set_channels(state->pcm, state->hw_params, 2)) < 0) {
		LOG_ERROR("Channel count not available: %s", snd_strerror(err));
		return err;
	}

	/* set the stream rate */
	val = set_sample_rate;
	if ((err = snd_pcm_hw_params_set_rate_near(state->pcm, state->hw_params, &val, 0)) < 0) {
		LOG_ERROR("Rate not available: %s", snd_strerror(err));
		return err;
	}

	/* set buffer and period times */
	val = state->period_count;
	if ((err = snd_pcm_hw_params_set_periods_near(state->pcm, state->hw_params, &val, 0)) < 0) {
		LOG_ERROR("Unable to set period size %s", snd_strerror(err));
		return err;
	}

	val = state->buffer_time / state->period_count;
	if ((err = snd_pcm_hw_params_set_period_time_near(state->pcm, state->hw_params, &val, 0)) < 0) {
		LOG_ERROR("Unable to set  buffer time %s", snd_strerror(err));
		return err;
	}

	/* set hardware parameters */
	if ((err = snd_pcm_hw_params(state->pcm, state->hw_params)) < 0) {
		LOG_ERROR("Unable to set hw params: %s", snd_strerror(err));
		return err;
	}

	if ((err = snd_pcm_hw_params_get_period_size(state->hw_params, &size, 0)) < 0) {
		LOG_ERROR("Unable to get period size: %s", snd_strerror(err));
		return err;
	}
	state->period_size = size;

	/* iec958 control for playback device only */
	if (!(state->flags & FLAG_STREAM_PLAYBACK)) {
		goto skip_iec958;	  
	}

	if ((err = snd_hctl_open(&state->hctl, state->device, 0)) < 0) {
		LOG_ERROR("snd_hctl_open failed: %s", snd_strerror(err));
		goto skip_iec958;
	}

	if ((err = snd_hctl_load(state->hctl)) < 0) {
		LOG_ERROR("snd_hctl_load failed: %s", snd_strerror(err));
		goto skip_iec958;
	}

	/* dies with warning on GCC 4.2:
	 * snd_ctl_elem_id_alloca(&id);
	 */
	id = (snd_ctl_elem_id_t *) alloca(snd_ctl_elem_id_sizeof());
	memset(id, 0, snd_ctl_elem_id_sizeof());
	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, "IEC958 Playback Default");

	state->iec958_elem = snd_hctl_find_elem(state->hctl, id);

 skip_iec958:
	if (IS_LOG_PRIORITY(LOG_PRIORITY_DEBUG)) {
		snd_pcm_dump(state->pcm, output);
	}

	state->pcm_sample_rate = set_sample_rate;

	return 0;
}


static int xrun_recovery(struct decode_alsa *state, int err) {
	if (err == -EPIPE) {	/* under-run */
		if ((err = snd_pcm_prepare(state->pcm) < 0)) {
			LOG_ERROR("Can't recover from underrun, prepare failed: %s", snd_strerror(err));
		}
		return 0;
	} else if (err == -ESTRPIPE) {
		while ((err = snd_pcm_resume(state->pcm)) == -EAGAIN) {
			sleep(1);	/* wait until the suspend flag is released */
		}
		if (err < 0) {
			if ((err = snd_pcm_prepare(state->pcm)) < 0) {
				LOG_ERROR("Can't recover from suspend, prepare failed: %s", snd_strerror(err));
			}
		}
		return 0;
	}
	return err;
}


static int pcm_test(struct decode_alsa *state) {
	snd_pcm_t *pcm;
	snd_pcm_hw_params_t *hw_params;
	int err;

	/* Open pcm */
	if ((err = snd_pcm_open(&pcm, state->device, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
		LOG_ERROR("Playback open error: %s", snd_strerror(err));
		return err;
	}

	/* Set hardware parameters */
	snd_pcm_hw_params_alloca(&hw_params);

	/* get maxmimum supported rate */
	if ((err = snd_pcm_hw_params_any(pcm, hw_params)) < 0) {
		LOG_ERROR("hwparam init error: %s", snd_strerror(err));
		goto err;
	}

	if ((err = snd_pcm_hw_params_set_rate_resample(pcm, hw_params, 0)) < 0) {
		LOG_ERROR("Resampling setup failed: %s", snd_strerror(err));
		goto err;
	}

	if ((err = snd_pcm_hw_params_get_rate_max(hw_params, &decode_audio->max_rate, 0)) < 0) {
		goto err;
	}
	LOG_DEBUG("max sample rate %d", decode_audio->max_rate);

	if ((err = snd_pcm_close(pcm)) < 0) {
		LOG_ERROR("snd_pcm_close error: %s", snd_strerror(err));
	}

	return 0;

err:
	if ((err = snd_pcm_close(pcm)) < 0) {
		LOG_ERROR("snd_pcm_close error: %s", snd_strerror(err));
	}

	return -1;
}


static void *audio_thread_execute(void *data) {
	struct decode_alsa *state = (struct decode_alsa *)data;
	snd_pcm_state_t pcm_state;
	snd_pcm_uframes_t size;
	snd_pcm_sframes_t avail;
	snd_pcm_status_t *status;
	int err, count = 0, count_max = 441, first = 1;
	u32_t delay, new_rate = 1;

	LOG_DEBUG("audio_thread_execute");
	
	status = malloc(snd_pcm_hw_params_sizeof());

	pcm_test(state);

	while (1) {
		TIMER_INIT(10.0f); /* 10 ms limit */

		if (new_rate && new_rate != state->pcm_sample_rate) {
			if ((err = pcm_open(state)) < 0) {
				LOG_ERROR("Open failed: %s", snd_strerror(err));
				goto thread_error;
			}
			first = 1;
			count_max = state->pcm_sample_rate / 1000;
		}

		if (count++ > count_max) {
			count = 0;

			debug_pagefaults();

			if (kill(state->parent_pid, 0) < 0) {
				/* parent is dead, exit */
				LOG_ERROR("exit, parent is dead");
				goto thread_error;
			}
		}
		    
		TIMER_CHECK("OPEN");

		pcm_state = snd_pcm_state(state->pcm);
		if (pcm_state == SND_PCM_STATE_XRUN) {
			struct timeval now, diff, tstamp;
			gettimeofday(&now, 0);
			snd_pcm_status_get_trigger_tstamp(status, &tstamp);
			timersub(&now, &tstamp, &diff);
			LOG_WARN("underrun!!! (at least %.3f ms long)", diff.tv_sec * 1000 + diff.tv_usec / 1000.0);

			if ((err = xrun_recovery(state, -EPIPE)) < 0) {
				LOG_ERROR("XRUN recovery failed: %s", snd_strerror(err));
			}
			first = 1;
		}
		else if (pcm_state == SND_PCM_STATE_SUSPENDED) {
			if ((err = xrun_recovery(state, -ESTRPIPE)) < 0) {
				LOG_ERROR("SUSPEND recovery failed: %s", snd_strerror(err));
			}
		}

		avail = snd_pcm_avail_update(state->pcm);
		if (avail < 0) {
			LOG_WARN("xrun (avail_update)");
			if ((err = xrun_recovery(state, avail)) < 0) {
				LOG_ERROR("Avail update failed: %s", snd_strerror(err));
			}
			first = 1;
			continue;
		}

		/* this is needed to ensure the sound works on resume */
		if (( err = snd_pcm_status(state->pcm, status)) < 0) {
			LOG_ERROR("snd_pcm_status err=%d", err);
		}

		/* playback delay */
		delay = snd_pcm_status_get_delay(status);

		TIMER_CHECK("STATE");

		if (avail < state->period_size) {
			if (first) {
				first = 0;
				if ((err = snd_pcm_start(state->pcm)) < 0) {
					LOG_ERROR("Audio start error: %s", snd_strerror(err));
				}
			}
			else {
				if ((err = snd_pcm_wait(state->pcm, 500)) < 0) {
					LOG_WARN("xrun (snd_pcm_wait)");
					if ((err = xrun_recovery(state, avail)) < 0) {
						LOG_ERROR("PCM wait failed: %s", snd_strerror(err));
					}
					first = 1;
				}

			}
			continue;
		}

		TIMER_CHECK("WAIT");

		size = state->period_size;
		while (size > 0) {
			const snd_pcm_channel_area_t *areas;
			snd_pcm_uframes_t frames, offset;
			snd_pcm_sframes_t commitres;
			void *buf;

			frames = size;

			if ((err = snd_pcm_mmap_begin(state->pcm, &areas, &offset, &frames)) < 0) {
				LOG_WARN("xrun (snd_pcm_mmap_begin)");
				if ((err = xrun_recovery(state, err)) < 0) {
					LOG_ERROR("mmap begin failed: %s", snd_strerror(err));
				}
				first = 1;
			}

			TIMER_CHECK("BEGIN");

			buf = ((u8_t *)areas[0].addr) + (areas[0].first + offset * areas[0].step) / 8;


			decode_audio_lock();
			TIMER_CHECK("LOCK");

			decode_audio->delay = delay;

			if (state->flags & FLAG_STREAM_PLAYBACK) {
				playback_callback(state, buf, frames);
			}
			else {
				memset(buf, 0, SAMPLES_TO_BYTES(frames));
			}

			if (state->flags & FLAG_STREAM_NOISE) {
				generate_noise(buf, frames);
			}

			TIMER_CHECK("PLAYBACK");

			if (state->flags & FLAG_STREAM_EFFECTS) {
				decode_mix_effects(buf, frames);
			}

			/* sample rate changed? we do this check while the
			 * fifo is locked, so we don't need to lock it twice
			 * per loop.
			 */
			new_rate = decode_audio->set_sample_rate;

			decode_audio_unlock();
			TIMER_CHECK("EFFECTS");

			commitres = snd_pcm_mmap_commit(state->pcm, offset, frames); 
			if (commitres < 0 || (snd_pcm_uframes_t)commitres != frames) { 
				LOG_WARN("xrun (snd_pcm_mmap_commit) err=%ld", commitres);
				if ((err = xrun_recovery(state, commitres)) < 0) {
					LOG_ERROR("mmap commit failed: %s", snd_strerror(err));
				}
				first = 1;
			}
			size -= frames;
			TIMER_CHECK("COMMIT");
		}
	}

 thread_error:
	free(status);

	LOG_ERROR("Audio thread exited");
	return (void *)-1;
}


static int decode_realtime_process()
{
	struct sched_param sched_param;
	int err;

	/* Set realtime scheduler policy. Use 45 as the PREEMPT_PR patches
	 * use 50 as the default prioity of the kernel tasklets and irq 
	 * handlers.
	 *
	 * For the best performance on a tuned RT kernel, make non-audio
	 * threads have a priority < 45.
	 */
	sched_param.sched_priority = 45;

	if ((err = sched_setscheduler(0, SCHED_FIFO, &sched_param)) == -1) {
		if (errno == EPERM) {
			LOG_INFO("Can't set audio thread priority");
			return -1;
		}
		else {
			LOG_ERROR("sched_setscheduler: %s", strerror(errno));
			return -1;
		}
	}

	return 0;
}

static int decode_lock_memory()
{
	size_t i, page_size;

	/* lock all current and future pages into ram */
	if (mlockall(MCL_CURRENT | MCL_FUTURE)) {
		LOG_WARN("mlockall failed");
		return -1;
	}

	/* Turn off malloc trimming.*/
   	mallopt(M_TRIM_THRESHOLD, -1);
   
   	/* Turn off mmap usage. */
   	mallopt(M_MMAP_MAX, 0);

	page_size = sysconf(_SC_PAGESIZE);

	/* touch each page of buffer */
	for (i=0; i<DECODE_AUDIO_BUFFER_SIZE; i+=page_size) {
		*(decode_fifo_buf + i) = 0;
	}

	debug_pagefaults();
	
	return 0;
}


static int decode_alsa_shared_mem_attach(void)
{
	int shmid;

	/* attach to shared memory */
	shmid = shmget(1234, 0, 0600 | IPC_CREAT);
	// XXXX errors

	decode_audio = shmat(shmid, 0, 0);
	// XXXX errors

	decode_fifo_buf = (((u8_t *)decode_audio) + sizeof(struct decode_audio));
	effect_fifo_buf = ((u8_t *)decode_fifo_buf) + DECODE_FIFO_SIZE;

	return 0;
}


int main(int argv, char **argc)
{
	int err, i;

	/* parse args */
	for (i=1; i<argv; i++) {
		if (strcmp(argc[i], "-v") == 0) {
			is_debug = 1;
		}
		else if (strcmp(argc[i], "-d") == 0) {
			state.device = argc[++i];
		}
		else if (strcmp(argc[i], "-b") == 0) {
			state.buffer_time = strtoul(argc[++i], NULL, 0);
		}
		else if (strcmp(argc[i], "-p") == 0) {
			state.period_count = strtoul(argc[++i], NULL, 0);
		}
		else if (strcmp(argc[i], "-f") == 0) {
			state.flags = strtoul(argc[++i], NULL, 0);
		}
	}

	if (!state.device || !state.buffer_time || !state.period_count || !state.flags) {
		printf("Usage: %s [-v] -d <device> -b <buffer_time> -p <period_count> -f <flags>\n", argc[0]);
		exit(-1);
	}

#ifdef HAVE_SYSLOG
	openlog("squeezeplay", LOG_ODELAY | LOG_CONS, LOG_USER);
#endif

	/* attach to shared memory buffer */
	if (decode_alsa_shared_mem_attach() != 0) {
		LOG_ERROR("Can't attach to shared memory");
		exit(-1);
	}
	decode_lock_memory();

	/* who is our parent */
	state.parent_pid = getppid();

	/* alsa messages */
	if ((err = snd_output_stdio_attach(&output, stdout, 0)) < 0) {
		LOG_ERROR("Output failed: %s", snd_strerror(err));
		exit(-1);
	}

	/* set real-time properties */
	decode_realtime_process();

	/* start thread */
	audio_thread_execute(&state);

	exit(0);
}


#endif // HAVE_LIBASOUND
