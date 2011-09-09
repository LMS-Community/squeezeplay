/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/mqueue.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"

#ifdef HAVE_NULLAUDIO

#include <time.h>

/* Stream sample rate */
static u32_t stream_sample_rate;


/*
 * This function is called by timer when the stream is active to request
 * audio samples
 */
static Uint32 callback(Uint32 interval) {
	size_t bytes_used, len, skip_bytes = 0, add_bytes = 0;
	int add_silence_ms;
	bool_t reached_start_point;
	u32_t delay;

	if ((decode_audio->state & (DECODE_STATE_AUTOSTART | DECODE_STATE_RUNNING)) == 0) {
//		LOG_DEBUG(log_audio_output, "Not running");
		return interval;
	}

	decode_audio_lock();

	stream_sample_rate = decode_audio->set_sample_rate;
	len = SAMPLES_TO_BYTES(stream_sample_rate * interval / 1000);

	bytes_used = fifo_bytes_used(&decode_audio->fifo);

	/* Should we start the audio now based on having enough decoded data? */
	if (decode_audio->state & DECODE_STATE_AUTOSTART
			&& bytes_used >=  len
			&& bytes_used >= SAMPLES_TO_BYTES((u32_t)((decode_audio->output_threshold * stream_sample_rate) / 10))
		)
	{
		u32_t now = jive_jiffies();

		if (decode_audio->start_at_jiffies > now && now > decode_audio->start_at_jiffies - 5000)
			decode_audio->add_silence_ms = decode_audio->start_at_jiffies - now;

		decode_audio->state &= ~DECODE_STATE_AUTOSTART;
		decode_audio->state |= DECODE_STATE_RUNNING;
	}

	/* audio running? */
	if (!(decode_audio->state & DECODE_STATE_RUNNING)) {
//		LOG_DEBUG(log_audio_output, "Not yet running");
		/* mix in sound effects */
		goto mixin_effects;
	}

//	LOG_DEBUG(log_audio_output, "Running");

	/* sync accurate playpoint */
	decode_audio->sync_elapsed_samples = decode_audio->elapsed_samples;
	delay = 0;

	if (decode_audio->sync_elapsed_samples > delay) {
		decode_audio->sync_elapsed_samples -= delay;
	}
	decode_audio->sync_elapsed_timestamp = jive_jiffies();

	add_silence_ms = decode_audio->add_silence_ms;
	if (add_silence_ms) {
		add_bytes = SAMPLES_TO_BYTES((u32_t)((add_silence_ms * stream_sample_rate) / 1000));
		if (add_bytes > len) add_bytes = len;
		len -= add_bytes;
		add_silence_ms -= (BYTES_TO_SAMPLES(add_bytes) * 1000) / stream_sample_rate;
		if (add_silence_ms < 2)
			add_silence_ms = 0;

		decode_audio->add_silence_ms = add_silence_ms;

		if (!len) {
			goto mixin_effects;
		}
	}

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

		goto mixin_effects;
	}

	if (bytes_used < len) {
		decode_audio->state |= DECODE_STATE_UNDERRUN;
	}
	else {
		decode_audio->state &= ~DECODE_STATE_UNDERRUN;
	}

	if (skip_bytes) {
		size_t wrap;

		LOG_DEBUG(log_audio_output, "Skipping %d bytes", (int) skip_bytes);
		
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
		size_t wrap, bytes_write;

		wrap = fifo_bytes_until_rptr_wrap(&decode_audio->fifo);

		bytes_write = bytes_used;
		if (wrap < bytes_write) {
			bytes_write = wrap;
		}

		fifo_rptr_incby(&decode_audio->fifo, bytes_write);
		decode_audio->elapsed_samples += BYTES_TO_SAMPLES(bytes_write);

		bytes_used -= bytes_write;
	}

	reached_start_point = decode_check_start_point();
	if (reached_start_point && decode_audio->track_sample_rate != stream_sample_rate) {
		decode_audio->set_sample_rate = decode_audio->track_sample_rate;
	}

 mixin_effects:
	/* mix in sound effects */
	/* don't */

	decode_audio_unlock();

	return interval;
}

static void decode_null_start(void) {
	LOG_DEBUG(log_audio_output, "decode_null_start");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = decode_audio->track_sample_rate;
}

static void decode_null_pause(void) {
	ASSERT_AUDIO_LOCKED();
}

static void decode_null_resume(void) {
	ASSERT_AUDIO_LOCKED();
}

static void decode_null_stop(void) {
	LOG_DEBUG(log_audio_output, "decode_null_stop");

	ASSERT_AUDIO_LOCKED();

	stream_sample_rate = decode_audio->set_sample_rate = 44100;
}

static SDL_Thread *callback_thread = NULL;

static int callback_thread_execute(void *unused) {
	struct timespec req, now, then;
	long diffms;
	clock_gettime(CLOCK_REALTIME, &then);

	while (1) {
		then.tv_nsec += 100000000;
		if (then.tv_nsec > 999999999) {
			then.tv_nsec -= 1000000000;
			then.tv_sec += 1;
		}
		clock_gettime(CLOCK_REALTIME, &now);

		diffms = (then.tv_sec - now.tv_sec) * 1000
				+ (then.tv_nsec - now.tv_nsec) / 1000000;

		req.tv_sec = 0;
		req.tv_nsec = diffms * 1000000;
		if (req.tv_nsec > 120000000) {
			req.tv_nsec = 100000000;
		} else if (req.tv_nsec < 0) {
			req.tv_nsec = 10000000;
			then = now;
		}

		if (nanosleep(&req, 0) < 0) {
			continue;
		}

		callback(100);

	}

	return 0;
}

static int decode_null_init(lua_State *L) {
	void *buf;

	/* allocate output memory */
	buf = malloc(DECODE_AUDIO_BUFFER_SIZE);
	if (!buf) {
		LOG_WARN(log_audio_output, "Cannot allocate output buffer");
		return 0;
	}

	decode_init_buffers(buf, false);
	decode_audio->max_rate = 48000;

	stream_sample_rate = decode_audio->set_sample_rate = decode_audio->track_sample_rate = 44100;

	/* XXX set up timer to call callback reqularly */
	/* only need callback to run while actually playing */

	if (!callback_thread) {
		callback_thread = SDL_CreateThread(callback_thread_execute, NULL);
		if (!callback_thread) {
			LOG_WARN(log_audio_output, "Cannot start callback timer");
			return 0;
		}
	}

	return 1;
}


struct decode_audio_func decode_null = {
	decode_null_init,
	decode_null_start,
	decode_null_pause,
	decode_null_resume,
	decode_null_stop,
};

#endif // HAVE_NULLAUDIO
