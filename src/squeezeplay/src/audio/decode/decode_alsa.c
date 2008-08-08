/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include <alsa/asoundlib.h>

#include "audio/fifo.h"
#include "audio/mqueue.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBASOUND

/* Stream sample rate */
static u32_t new_sample_rate;
static u32_t pcm_sample_rate;


/* alsa */
static char *device = "plughw:0,0";

static snd_output_t *output;
static snd_pcm_t *handle;
static snd_pcm_hw_params_t *hwparams;

static snd_pcm_sframes_t period_size;

static SDL_Thread *audio_thread;



/*
 * This function is called by portaudio when the stream is active to request
 * audio samples
 */
static void callback(void *outputBuffer,
		    unsigned long framesPerBuffer) {
	size_t bytes_used, len;
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;

	// XXXX full port from ip3k

	len = SAMPLES_TO_BYTES(framesPerBuffer);

	/* audio running? */
	if (!(current_audio_state & DECODE_STATE_RUNNING)) {
		memset(outputArray, 0, len);

		/* mix in sound effects */
		decode_sample_mix(outputArray, len);

		return;
	}

	bytes_used = fifo_bytes_used(&decode_fifo);	
	if (bytes_used > len) {
		bytes_used = len;
	}

	/* audio underrun? */
	if (bytes_used == 0) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray, 0, len);

		return;
	}

	if (bytes_used < len) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray + bytes_used, 0, len - bytes_used);
	}
	else {
		current_audio_state &= ~DECODE_STATE_UNDERRUN;
	}

	while (bytes_used) {
		size_t wrap, bytes_write;

		wrap = fifo_bytes_until_rptr_wrap(&decode_fifo);

		bytes_write = bytes_used;
		if (wrap < bytes_write) {
			bytes_write = wrap;
		}

		memcpy(outputArray, decode_fifo_buf + decode_fifo.rptr, bytes_write);
		fifo_rptr_incby(&decode_fifo, bytes_write);
		decode_elapsed_samples += BYTES_TO_SAMPLES(bytes_write);

		outputArray += bytes_write;
		bytes_used -= bytes_write;
	}

	reached_start_point = decode_check_start_point();
	if (reached_start_point && current_sample_rate != pcm_sample_rate) {
		new_sample_rate = current_sample_rate;
	}

	return;
}


static int pcm_open() {
	int err, dir;
	snd_pcm_uframes_t size;
	unsigned int buffer_time = 250000; // FIXME low latency
	unsigned int period_time = buffer_time / 4;

	/* Close existing pcm (if any) */
	if (handle) {
		if ((err = snd_pcm_drain(handle)) < 0) {
			DEBUG_ERROR("Drain error: %s", snd_strerror(err));
		}

		if ((err = snd_pcm_close(handle)) < 0) {
			DEBUG_ERROR("Drain error: %s", snd_strerror(err));
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
	if ((err = snd_pcm_hw_params_set_rate_near(handle, hwparams, &new_sample_rate, 0)) < 0) {
		DEBUG_ERROR("Rate not available: %s", snd_strerror(err));
		return err;
	}

	/* set buffer and period times */
	if ((err = snd_pcm_hw_params_set_buffer_time_near(handle, hwparams, &buffer_time, &dir)) < 0) {
		DEBUG_ERROR("Unable to set  buffer time %s", snd_strerror(err));
		return err;
	}

	if ((err = snd_pcm_hw_params_set_period_time_near(handle, hwparams, &period_time, &dir)) < 0) {
		DEBUG_ERROR("Unable to set period time %s", snd_strerror(err));
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

	pcm_sample_rate = new_sample_rate;
	new_sample_rate = 0;

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


static int audio_thread_execute(void *unused) {
	snd_pcm_state_t state;
	const snd_pcm_channel_area_t *areas;
	snd_pcm_uframes_t offset;
	snd_pcm_uframes_t frames, size;
	snd_pcm_sframes_t avail, commitres;
	int err, first = 1;
	void *buf;

	DEBUG_TRACE("audio_thread_execute");

	new_sample_rate = 44100;

	while (1) {
		fifo_lock(&decode_fifo);

		if (new_sample_rate) {
			if ((err = pcm_open()) < 0) {
				DEBUG_ERROR("Open failed: %s", snd_strerror(err));
				return -1;
			}
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

			buf = areas[0].addr + (areas[0].first + offset * areas[0].step) / 8;
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
	fifo_unlock(&decode_fifo);
}


static void decode_alsa_pause(void) {
	DEBUG_TRACE("decode_alsa_pause");

	fifo_lock(&decode_fifo);
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

	if ((err = snd_output_stdio_attach(&output, stdout, 0)) < 0) {
		DEBUG_ERROR("Output failed: %s", snd_strerror(err));
		return 0;
	}

	DEBUG_TRACE("Playback device: %s\n", device);

	if (pcm_open() < 0) {
		return 0;
	}

	/* start audio thread */
	// XXXX fixme thread priority
	audio_thread = SDL_CreateThread(audio_thread_execute, NULL);

	return 1;
}


struct decode_audio decode_alsa = {
	decode_alsa_init,
	decode_alsa_start,
	decode_alsa_pause,
	decode_alsa_resume,
	decode_alsa_stop,
};

#endif // HAVE_LIBASOUND
