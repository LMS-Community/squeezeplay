/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/mqueue.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBPORTAUDIO

#include "portaudio.h"

/* Portaudio stream */
static PaStreamParameters outputParam;
static PaStream *stream;

/* Stream sample rate */
static u32_t stream_sample_rate;

static void decode_portaudio_openstream(void);


/*
 * This function is called by portaudio when the stream is active to request
 * audio samples
 */
static int callback(const void *inputBuffer,
		    void *outputBuffer,
		    unsigned long framesPerBuffer,
		    const PaStreamCallbackTimeInfo *timeInfo,
		    PaStreamCallbackFlags statusFlags,
		    void *userData) {
	size_t bytes_used, len, skip_bytes = 0, add_bytes = 0;
	int add_silence_ms;
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;
	u32_t delay;
	int ret = paContinue;

	if (statusFlags & (paOutputUnderflow | paOutputOverflow)) {
		LOG_DEBUG(log_audio_output, "pa status %x\n", (unsigned int)statusFlags);
	}

	// XXXX full port from ip3k

	len = SAMPLES_TO_BYTES(framesPerBuffer);

	decode_audio_lock();

	bytes_used = fifo_bytes_used(&decode_audio->fifo);

	/* Should we start the audio now based on having enough decoded data? */
	if (decode_audio->state & DECODE_STATE_AUTOSTART
			&& bytes_used >=  len
			&& bytes_used >= SAMPLES_TO_BYTES((u32_t)((decode_audio->output_threshold * stream_sample_rate) / 10))
		)
	{
		u32_t now = jive_jiffies();

		if (decode_audio->start_at_jiffies > now && now > decode_audio->start_at_jiffies - 5000)
			/* This does not consider any delay in the port-audio output chain */
			decode_audio->add_silence_ms = decode_audio->start_at_jiffies - now;

		decode_audio->state &= ~DECODE_STATE_AUTOSTART;
		decode_audio->state |= DECODE_STATE_RUNNING;
	}

	/* audio running? */
	if (!(decode_audio->state & DECODE_STATE_RUNNING)) {
		memset(outputArray, 0, len);

		/* mix in sound effects */
		goto mixin_effects;
	}

	/* sync accurate playpoint */
	decode_audio->sync_elapsed_samples = decode_audio->elapsed_samples;
	delay = (timeInfo->outputBufferDacTime - Pa_GetStreamTime(stream)) * decode_audio->track_sample_rate;

	if (decode_audio->sync_elapsed_samples > delay) {
		decode_audio->sync_elapsed_samples -= delay;
	}
	decode_audio->sync_elapsed_timestamp = jive_jiffies();

	add_silence_ms = decode_audio->add_silence_ms;
	if (add_silence_ms) {
		add_bytes = SAMPLES_TO_BYTES((u32_t)((add_silence_ms * stream_sample_rate) / 1000));
		if (add_bytes > len) add_bytes = len;
		memset(outputArray, 0, add_bytes);
		outputArray += add_bytes;
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
		memset(outputArray, 0, len);

		goto mixin_effects;
	}

	if (bytes_used < len) {
		decode_audio->state |= DECODE_STATE_UNDERRUN;
		memset(outputArray + bytes_used, 0, len - bytes_used);
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
		size_t wrap, bytes_write, samples_write;
		sample_t *output_ptr, *decode_ptr;
		s32_t lgain, rgain;
		
		lgain = decode_audio->lgain;
		rgain = decode_audio->rgain;

		wrap = fifo_bytes_until_rptr_wrap(&decode_audio->fifo);

		bytes_write = bytes_used;
		if (wrap < bytes_write) {
			bytes_write = wrap;
		}

		samples_write = BYTES_TO_SAMPLES(bytes_write);
		
		/* Handle fading and delayed fading */
		if (decode_audio->samples_to_fade) {
			if (decode_audio->samples_until_fade > samples_write) {
				decode_audio->samples_until_fade -= samples_write;
			}
			else {
				decode_audio->samples_until_fade = 0;
			
				/* initialize transition parameters */
				if (!decode_audio->transition_gain_step) {
					size_t nbytes;
					fft_fixed interval;
				
					interval = determine_transition_interval(decode_audio->transition_sample_rate, (u32_t)(decode_audio->samples_to_fade / decode_audio->transition_sample_rate), &nbytes);
					if (!interval)
						interval = 1;
					
					decode_audio->transition_gain_step = fixed_div(FIXED_ONE, fixed_mul(interval, s32_to_fixed(TRANSITION_STEPS_PER_SECOND)));
					decode_audio->transition_gain = FIXED_ONE;
					decode_audio->transition_sample_step = decode_audio->transition_sample_rate / TRANSITION_STEPS_PER_SECOND;
					decode_audio->transition_samples_in_step = 0;
				
					LOG_DEBUG(log_audio_output, "Starting FADEOUT over %d seconds, transition_gain_step %d, transition_sample_step %d",
						fixed_to_s32(interval), decode_audio->transition_gain_step, decode_audio->transition_sample_step);	
				}
				
				/* Apply transition gain to left/right gain values */
				lgain = fixed_mul(lgain, decode_audio->transition_gain);
				rgain = fixed_mul(rgain, decode_audio->transition_gain);
				
				/* Reduce transition gain when we've processed enough samples */
				decode_audio->transition_samples_in_step += samples_write;
				while (decode_audio->transition_gain && decode_audio->transition_samples_in_step >= decode_audio->transition_sample_step) {
					decode_audio->transition_samples_in_step -= decode_audio->transition_sample_step;
					decode_audio->transition_gain -= decode_audio->transition_gain_step;
				}
			}
		}

		output_ptr = (sample_t *)outputArray;
		decode_ptr = (sample_t *)(decode_fifo_buf + decode_audio->fifo.rptr);
		while (samples_write--) {
			*(output_ptr++) = fixed_mul(lgain, *(decode_ptr++));
			*(output_ptr++) = fixed_mul(rgain, *(decode_ptr++));
		}

		fifo_rptr_incby(&decode_audio->fifo, bytes_write);
		decode_audio->elapsed_samples += BYTES_TO_SAMPLES(bytes_write);

		outputArray += bytes_write;
		bytes_used -= bytes_write;
	}

	reached_start_point = decode_check_start_point();
	if (reached_start_point) {
		decode_audio->samples_to_fade = 0;
		decode_audio->transition_gain_step = 0;
		
		if (decode_audio->track_sample_rate != stream_sample_rate) {
			LOG_DEBUG(log_audio_output, "Sample rate changed from %d to %d\n", stream_sample_rate, decode_audio->track_sample_rate);
			decode_audio->set_sample_rate = decode_audio->track_sample_rate;
			ret = paComplete; // will trigger the finished callback to change the samplerate
		}
	}

 mixin_effects:
	/* mix in sound effects */
	decode_mix_effects(outputBuffer, framesPerBuffer, 24, stream_sample_rate);

	decode_audio_unlock();

	return ret;
}


static void finished_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	decode_audio_lock();
	decode_portaudio_openstream();
	decode_audio_unlock();
}


/*
 * This function is called when the stream needs to be reopened at a
 * different sample rate.
 */
static void finished(void *userData) {
	if (decode_audio->set_sample_rate) {
		/* We can't change the sample rate in this thread, so queue a request for
		 * the decoder thread to service
		 */
		if (mqueue_write_request(&decode_mqueue, finished_handler, 0)) {
			mqueue_write_complete(&decode_mqueue);
		}
		else {
			LOG_DEBUG(log_audio_output, "Full message queue, dropped finished message");
		}
	}
}


static void decode_portaudio_start(void) {
	LOG_DEBUG(log_audio_output, "decode_portaudio_start");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = decode_audio->track_sample_rate;

	decode_portaudio_openstream();
}

static void decode_portaudio_pause(void) {
	ASSERT_AUDIO_LOCKED();
}

static void decode_portaudio_resume(void) {
	ASSERT_AUDIO_LOCKED();
}

static void decode_portaudio_stop(void) {
	LOG_DEBUG(log_audio_output, "decode_portaudio_stop");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = 44100;
	decode_audio->samples_to_fade = 0;
	decode_audio->transition_gain_step = 0;

	decode_portaudio_openstream();
}


static void decode_portaudio_openstream(void) {
	PaError err;
	u32_t set_sample_rate;

	ASSERT_AUDIO_LOCKED();

	set_sample_rate = decode_audio->set_sample_rate;
	decode_audio->set_sample_rate = 0;

	if (!set_sample_rate || set_sample_rate == stream_sample_rate) {
		/* no change */
		return;
	}

	if (stream) {
		if ((err = Pa_CloseStream(stream)) != paNoError) {
			LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
		}
	}

	if ((err = Pa_OpenStream(
			&stream,
			NULL,
			&outputParam,
			set_sample_rate,
			paFramesPerBufferUnspecified,
			paPrimeOutputBuffersUsingStreamCallback,
			callback,
			NULL)) != paNoError) {
		LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
	}

	stream_sample_rate = set_sample_rate;

	/* playout to the end of this stream before changing the sample rate */
	if ((err = Pa_SetStreamFinishedCallback(stream, finished)) != paNoError) {
		LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
	}

	LOG_DEBUG(log_audio_output, "Stream latency %f", Pa_GetStreamInfo(stream)->outputLatency);
	LOG_DEBUG(log_audio_output, "Sample rate %f", Pa_GetStreamInfo(stream)->sampleRate);

	if ((err = Pa_StartStream(stream)) != paNoError) {
		LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
		return;
	}
}


static int decode_portaudio_init(lua_State *L) {
	PaError err;
	int num_devices, i;
	const PaDeviceInfo *device_info;
	const PaHostApiInfo *host_info;
	void *buf;

	if ((err = Pa_Initialize()) != paNoError) {
		goto err0;
	}

	LOG_DEBUG(log_audio_output, "Portaudio version %s", Pa_GetVersionText());

	memset(&outputParam, 0, sizeof(outputParam));
	outputParam.channelCount = 2;
	outputParam.sampleFormat = paInt32;

	num_devices = Pa_GetDeviceCount();
	for (i = 0; i < num_devices; i++) {
		device_info = Pa_GetDeviceInfo(i);
		host_info = Pa_GetHostApiInfo(device_info->hostApi);

		LOG_DEBUG(log_audio_output, "%d: %s (%s)", i, device_info->name, host_info->name);

		outputParam.device = i;

		err = Pa_IsFormatSupported(NULL, &outputParam, 44100);
		if (err == paFormatIsSupported) {
			LOG_DEBUG(log_audio_output, "\tsupported");
			break;
		}
		else {
			LOG_DEBUG(log_audio_output, "\tnot supported");
		}
	}

	if (i >= num_devices) {
		/* no suitable audio device found */
		return 0;
	}

	/* high latency for robust playback */
	outputParam.suggestedLatency = Pa_GetDeviceInfo(outputParam.device)->defaultHighOutputLatency;

	/* allocate output memory */
	buf = malloc(DECODE_AUDIO_BUFFER_SIZE);
	if (!buf) {
		goto err0;
	}

	decode_init_buffers(buf, false);
	decode_audio->max_rate = 48000;

	/* open stream */
	decode_audio_lock();
	decode_portaudio_openstream();
	decode_audio_unlock();

	return 1;

 err0:
	LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
	return 0;
}


struct decode_audio_func decode_portaudio = {
	decode_portaudio_init,
	decode_portaudio_start,
	decode_portaudio_pause,
	decode_portaudio_resume,
	decode_portaudio_stop,
};

#endif // HAVE_PORTAUDIO
