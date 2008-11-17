/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/mqueue.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBASOUND

#include <pthread.h>
#include <alsa/asoundlib.h>

/* Stream sample rate */
static u32_t new_sample_rate;
static u32_t pcm_sample_rate;


/* alsa */
static char *device = "default";
//static char *device = "plughw:0,0";

static snd_output_t *output;
static snd_pcm_t *handle = NULL;
static snd_pcm_hw_params_t *hwparams;

static snd_pcm_sframes_t period_size;
static fft_fixed lgain, rgain;

static pthread_t audio_thread;


static void decode_alsa_gain(s32_t lgain, s32_t rgain);


/*
 * This function is called by portaudio when the stream is active to request
 * audio samples
 * Called with fifo-lock held.
 */
static void callback(void *outputBuffer,
		    unsigned long framesPerBuffer) {
	size_t bytes_used, len, skip_bytes = 0, add_bytes = 0;
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;

	// XXXX full port from ip3k

	len = SAMPLES_TO_BYTES(framesPerBuffer);

	/* audio running? */
	if (!(current_audio_state & DECODE_STATE_RUNNING)) {
		memset(outputArray, 0, len);

		goto mixin_effects;
	}
	
	if (add_silence_ms) {
		add_bytes = SAMPLES_TO_BYTES((u32_t)((add_silence_ms * current_sample_rate) / 1000));
		if (add_bytes > len) {
			add_bytes = len;
		}
		memset(outputArray, 0, add_bytes);
		outputArray += add_bytes;
		len -= add_bytes;
		add_silence_ms -= (BYTES_TO_SAMPLES(add_bytes) * 1000) / current_sample_rate;
		if (add_silence_ms < 2) {
			add_silence_ms = 0;
		}
		if (!len) {
			goto mixin_effects;
		}
	}

	bytes_used = fifo_bytes_used(&decode_fifo);
	
	/* only skip if it will not cause an underrun */
	if (bytes_used >= len && skip_ahead_bytes > 0) {
		skip_bytes = bytes_used - len;
		if (skip_bytes > skip_ahead_bytes) {
			skip_bytes = skip_ahead_bytes;			
		}
	}

	if (bytes_used > len) {
		bytes_used = len;
	}

	/* audio underrun? */
	if (bytes_used == 0) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray, 0, len);
		DEBUG_ERROR("Audio underrun: used 0 bytes");

		goto mixin_effects;
	}

	if (bytes_used < len) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray + bytes_used, 0, len - bytes_used);
		DEBUG_ERROR("Audio underrun: used %d bytes , requested %d bytes", (int)bytes_used, (int)len);
	}
	else {
		current_audio_state &= ~DECODE_STATE_UNDERRUN;
	}
	
	if (skip_bytes) {
		size_t wrap;

		DEBUG_TRACE("Skipping %d bytes", (int)skip_bytes);
		
		wrap = fifo_bytes_until_rptr_wrap(&decode_fifo);

		if (wrap < skip_bytes) {
			fifo_rptr_incby(&decode_fifo, wrap);
			skip_bytes -= wrap;
			skip_ahead_bytes -= wrap;
			decode_elapsed_samples += BYTES_TO_SAMPLES(wrap);
		}

		fifo_rptr_incby(&decode_fifo, skip_bytes);
		skip_ahead_bytes -= skip_bytes;
		decode_elapsed_samples += BYTES_TO_SAMPLES(skip_bytes);
	}

	while (bytes_used) {
		size_t wrap, bytes_write, samples_write;
		sample_t *output_ptr, *decode_ptr;

		wrap = fifo_bytes_until_rptr_wrap(&decode_fifo);

		bytes_write = bytes_used;
		if (wrap < bytes_write) {
			bytes_write = wrap;
		}

		samples_write = BYTES_TO_SAMPLES(bytes_write);

		output_ptr = (sample_t *)(void *)outputArray;
		decode_ptr = (sample_t *)(void *)(decode_fifo_buf + decode_fifo.rptr);
		while (samples_write--) {
			*(output_ptr++) = fixed_mul(lgain, *(decode_ptr++));
			*(output_ptr++) = fixed_mul(rgain, *(decode_ptr++));
		}

		fifo_rptr_incby(&decode_fifo, bytes_write);
		decode_elapsed_samples += BYTES_TO_SAMPLES(bytes_write);

		outputArray += bytes_write;
		bytes_used -= bytes_write;
	}

	reached_start_point = decode_check_start_point();
	if (reached_start_point && current_sample_rate != pcm_sample_rate) {
		new_sample_rate = current_sample_rate;
	}

 mixin_effects:
	/* mix in sound effects */
	decode_sample_mix(outputBuffer, SAMPLES_TO_BYTES(framesPerBuffer));

	return;
}


static int pcm_open(u32_t sample_rate) {
	int err, dir;
	snd_pcm_uframes_t size;
#define BUFFER_SIZE 8192 /*(8291 / 4)*/
#define PERIOD_SIZE (BUFFER_SIZE / 4) /*(BUFFER_SIZE / 8)*/

	if (handle && sample_rate == pcm_sample_rate) {
		return 0;
	}

	/* Close existing pcm (if any) */
	if (handle) {
		if ((err = snd_pcm_drain(handle)) < 0) {
			DEBUG_ERROR("snd_pcm_drain error: %s", snd_strerror(err));
		}

		if ((err = snd_pcm_close(handle)) < 0) {
			DEBUG_ERROR("snd_pcm_close error: %s", snd_strerror(err));
		}

		handle = NULL;
	}

	/* Open pcm */
	if ((err = snd_pcm_open(&handle, device, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
		DEBUG_ERROR("Playback open error: %s", snd_strerror(err));
		return err;
	}

	/* Set hardware parameters */
	if ((err = snd_pcm_hw_params_malloc(&hwparams)) < 0) {
		DEBUG_ERROR("hwparam malloc error: %s", snd_strerror(err));
		return err;
	}

	if ((err = snd_pcm_hw_params_any(handle, hwparams)) < 0) {
		DEBUG_ERROR("hwparam init error: %s", snd_strerror(err));
		return err;
	}

	/* set hardware resampling */
	if ((err = snd_pcm_hw_params_set_rate_resample(handle, hwparams, 1)) < 0) {
		DEBUG_ERROR("Resampling setup failed: %s\n", snd_strerror(err));
		return err;
	}

	/* set mmap interleaved access format */
	if ((err = snd_pcm_hw_params_set_access(handle, hwparams, SND_PCM_ACCESS_MMAP_INTERLEAVED)) < 0) {
		DEBUG_ERROR("Access type not available: %s", snd_strerror(err));
		return err;
	}

	/* set the sample format */
	if ((err = snd_pcm_hw_params_set_format(handle, hwparams, SND_PCM_FORMAT_S32_LE)) < 0) {
		DEBUG_ERROR("Sample format not available: %s", snd_strerror(err));
		return err;
	}

	/* set the channel count */
	if ((err = snd_pcm_hw_params_set_channels(handle, hwparams, 2)) < 0) {
		DEBUG_ERROR("Channel count not available: %s", snd_strerror(err));
		return err;
	}

	/* set the stream rate */
	if ((err = snd_pcm_hw_params_set_rate_near(handle, hwparams, &sample_rate, 0)) < 0) {
		DEBUG_ERROR("Rate not available: %s", snd_strerror(err));
		return err;
	}

	/* set buffer and period times */
	size = BUFFER_SIZE;
	if ((err = snd_pcm_hw_params_set_buffer_size_near(handle, hwparams, &size)) < 0) {
		DEBUG_ERROR("Unable to set  buffer size %s", snd_strerror(err));
		return err;
	}

	size = PERIOD_SIZE;
	if ((err = snd_pcm_hw_params_set_period_size_near(handle, hwparams, &size, &dir)) < 0) {
		DEBUG_ERROR("Unable to set period size %s", snd_strerror(err));
		return err;
	}

	if ((err = snd_pcm_hw_params_get_period_size(hwparams, &size, &dir)) < 0) {
		DEBUG_ERROR("Unable to get period size: %s", snd_strerror(err));
		return err;
	}
	period_size = size;

	/* set hardware parameters */
	if ((err = snd_pcm_hw_params(handle, hwparams)) < 0) {
		DEBUG_ERROR("Unable to set hw params: %s", snd_strerror(err));
		return err;
	}

#ifdef RUNTIME_DEBUG
	snd_pcm_dump(handle, output);
#endif

	pcm_sample_rate = sample_rate;

	return 0;
}


static int xrun_recovery(snd_pcm_t *handle, int err) {
	if (err == -EPIPE) {	/* under-run */
		if ((err = snd_pcm_prepare(handle) < 0)) {
			DEBUG_ERROR("Can't recovery from underrun, prepare failed: %s\n", snd_strerror(err));
		}
		return 0;
	} else if (err == -ESTRPIPE) {
		while ((err = snd_pcm_resume(handle)) == -EAGAIN) {
			sleep(1);	/* wait until the suspend flag is released */
		}
		if (err < 0) {
			if ((err = snd_pcm_prepare(handle)) < 0) {
				DEBUG_ERROR("Can't recovery from suspend, prepare failed: %s\n", snd_strerror(err));
			}
		}
		return 0;
	}
	return err;
}


static void *audio_thread_execute(void *unused) {
	snd_pcm_state_t state;
	const snd_pcm_channel_area_t *areas;
	snd_pcm_uframes_t offset;
	snd_pcm_uframes_t frames, size;
	snd_pcm_sframes_t avail, commitres;
	int err, first = 1;
	void *buf;

	DEBUG_TRACE("audio_thread_execute");

	while (1) {
		fifo_lock(&decode_fifo);

		if (new_sample_rate) {
			if ((err = pcm_open(new_sample_rate)) < 0) {
				DEBUG_ERROR("Open failed: %s", snd_strerror(err));
				return (void *)-1;
			}

			new_sample_rate = 0;
			first = 1;
		}

		fifo_unlock(&decode_fifo);

		state = snd_pcm_state(handle);
		if (state == SND_PCM_STATE_XRUN) {
			if ((err = xrun_recovery(handle, -EPIPE)) < 0) {
				DEBUG_ERROR("XRUN recovery failed: %s", snd_strerror(err));
			}
			first = 1;
		}
		else if (state == SND_PCM_STATE_SUSPENDED) {
			if ((err = xrun_recovery(handle, -ESTRPIPE)) < 0) {
				DEBUG_ERROR("SUSPEND recovery failed: %s", snd_strerror(err));
			}
		}

		avail = snd_pcm_avail_update(handle);
		if (avail < 0) {
			if ((err = xrun_recovery(handle, avail)) < 0) {
				DEBUG_ERROR("Avail update failed: %s", snd_strerror(err));
			}
			first = 1;
			continue;
		}

		if (avail < period_size) {
			if (first) {
				first = 0;
				if ((err = snd_pcm_start(handle)) < 0) {
					DEBUG_ERROR("Audio start error: %s", snd_strerror(err));
				}
			}
			else {
				if ((err = snd_pcm_wait(handle, -1)) < 0) {
					if ((err = xrun_recovery(handle, avail)) < 0) {
						DEBUG_ERROR("PCM wait failed: %s", snd_strerror(err));
					}
					first = 1;
				}

			}
			continue;
		}

		size = period_size;
		while (size > 0) {
			frames = size;

			if ((err = snd_pcm_mmap_begin(handle, &areas, &offset, &frames)) < 0) {
				if ((err = xrun_recovery(handle, avail)) < 0) {
					DEBUG_ERROR("mmap begin failed: %s", snd_strerror(err));
				}
				first = 1;
			}

			fifo_lock(&decode_fifo);

			buf = ((u8_t *)areas[0].addr) + (areas[0].first + offset * areas[0].step) / 8;
			callback(buf, frames);

			fifo_unlock(&decode_fifo);

			commitres = snd_pcm_mmap_commit(handle, offset, frames); 
			if (commitres < 0 || (snd_pcm_uframes_t)commitres != frames) { 
				if ((err = xrun_recovery(handle, avail)) < 0) {
					DEBUG_ERROR("mmap commit failed: %s", snd_strerror(err));
				}
				first = 1;
			}
			size -= frames;
		}
	}
}


static void decode_alsa_start(void) {
	DEBUG_TRACE("decode_alsa_start");

	fifo_lock(&decode_fifo);
	if (pcm_sample_rate != current_sample_rate) {
		new_sample_rate = current_sample_rate;
	}
	fifo_unlock(&decode_fifo);
}


static void decode_alsa_resume(void) {
	DEBUG_TRACE("decode_alsa_resume");

	fifo_lock(&decode_fifo);
	if (pcm_sample_rate != current_sample_rate) {
		new_sample_rate = current_sample_rate;
	}
	// snd_pcm_pause(handle, 1);
	fifo_unlock(&decode_fifo);
}


static void decode_alsa_pause(void) {
	DEBUG_TRACE("decode_alsa_pause");

	fifo_lock(&decode_fifo);
//	snd_pcm_pause(handle, 0);
	if (pcm_sample_rate != 44100) {
		new_sample_rate = 44100;
	}
	fifo_unlock(&decode_fifo);
}


static void decode_alsa_stop(void) {
	DEBUG_TRACE("decode_alsa_stop");

	fifo_lock(&decode_fifo);
	if (pcm_sample_rate != 44100) {
		new_sample_rate = 44100;
	}
	fifo_unlock(&decode_fifo);
}


static int decode_alsa_init(void) {
	int err;
	pthread_attr_t thread_attr;
	struct sched_param thread_param;
	size_t stacksize;

	if ((err = snd_output_stdio_attach(&output, stdout, 0)) < 0) {
		DEBUG_ERROR("Output failed: %s", snd_strerror(err));
		return 0;
	}

	DEBUG_TRACE("Playback device: %s\n", device);

	if (pcm_open(44100) < 0) {
		return 0;
	}

	/* start audio thread */
	if ((err = pthread_attr_init(&thread_attr)) != 0) {
		DEBUG_ERROR("pthread_attr_init: %s", strerror(err));
		return 0;
	}

	if ((err = pthread_attr_setdetachstate(&thread_attr, PTHREAD_CREATE_DETACHED)) != 0) {
		DEBUG_ERROR("pthread_attr_setdetachstate: %s", strerror(err));
		return 0;
	}

	stacksize = 32 * 1024; /* 32k stack, we don't do much here */
	if ((err = pthread_attr_setstacksize(&thread_attr, stacksize)) != 0) {
		DEBUG_ERROR("pthread_attr_setstacksize: %s", strerror(err));
	}

	if ((err = pthread_create(&audio_thread, &thread_attr, audio_thread_execute, NULL)) != 0) {
		DEBUG_ERROR("pthread_create: %s", strerror(err));
		return 0;
	}

	/* set realtime scheduler policy, with a high priority */
	thread_param.sched_priority = sched_get_priority_max(SCHED_FIFO);

	err = pthread_setschedparam(audio_thread, SCHED_FIFO, &thread_param);
	if (err) {
		if (err == EPERM) {
			DEBUG_ERROR("Can't set audio thread priority\n");
		}
		else {
			DEBUG_ERROR("pthread_create: %s", strerror(err));
			return 0;
		}
	}

	return 1;
}

static u32_t decode_alsa_delay(void)
{
    snd_pcm_status_t* status;
    
    /* dies with warning on GCC 4.2:
     * snd_pcm_status_alloca(&status);
     */
    status = (snd_pcm_status_t *) alloca(snd_pcm_hw_params_sizeof());
    memset(status, 0, snd_pcm_hw_params_sizeof());

    snd_pcm_status(handle, status);

    return (u32_t)snd_pcm_status_get_delay(status);
}


static void decode_alsa_gain(s32_t left_gain, s32_t right_gain)
{
	lgain = left_gain;
	rgain = right_gain;
}


struct decode_audio decode_alsa = {
	decode_alsa_init,
	decode_alsa_start,
	decode_alsa_pause,
	decode_alsa_resume,
	decode_alsa_stop,
	decode_alsa_delay,
	decode_alsa_gain,
};

#endif // HAVE_LIBASOUND
