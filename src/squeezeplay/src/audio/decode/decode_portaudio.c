/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#define RUNTIME_DEBUG 1

#include "common.h"

#include "audio/fifo.h"
#include "audio/mqueue.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBPORTAUDIO

#include "portaudio.h"

/* Portaudio stream */
static PaStreamParameters outputParam;
static PaStream *stream;

/* Stream sample rate */
static bool_t change_sample_rate;
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
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;

	if (statusFlags & (paOutputUnderflow | paOutputOverflow)) {
		DEBUG_TRACE("pa status %x\n", (unsigned int)statusFlags);
	}

	// XXXX full port from ip3k

	len = SAMPLES_TO_BYTES(framesPerBuffer);

	/* audio running? */
	if (!(current_audio_state & DECODE_STATE_RUNNING)) {
		memset(outputArray, 0, len);

		/* mix in sound effects */
		decode_sample_mix(outputArray, len);

		return paContinue;
	}

	fifo_lock(&decode_fifo);

	if (add_silence_bytes) {
		add_bytes = add_silence_bytes;
		if (add_bytes > len) add_bytes = len;
		memset(outputArray, 0, add_bytes);
		outputArray += add_bytes;
		len -= add_bytes;
		add_silence_bytes -= add_bytes;
		if (!len) {
			fifo_unlock(&decode_fifo);
			return paContinue;
		}
	}

	bytes_used = fifo_bytes_used(&decode_fifo);	

	/* only skip if it will not cause an underrun */
	if (bytes_used + skip_ahead_bytes >= len) {
		skip_bytes = skip_ahead_bytes;
		bytes_used -= skip_bytes;
	}

	if (bytes_used > len) {
		bytes_used = len;
	}

	/* audio underrun? */
	if (bytes_used == 0) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray, 0, len);

		fifo_unlock(&decode_fifo);
		return paContinue;
	}

	if (bytes_used < len) {
		current_audio_state |= DECODE_STATE_UNDERRUN;
		memset(outputArray + bytes_used, 0, len - bytes_used);
	}
	else {
		current_audio_state &= ~DECODE_STATE_UNDERRUN;
	}

	if (skip_bytes) {
		size_t wrap;

		DEBUG_TRACE("Skipping %d bytes", (int) skip_bytes);
		
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
	if (reached_start_point && current_sample_rate != stream_sample_rate) {
		change_sample_rate = true;

		fifo_unlock(&decode_fifo);
		return paComplete;
	}

	fifo_unlock(&decode_fifo);
	return paContinue;
}


static void finished_handler(void) {
	mqueue_read_complete(&decode_mqueue);

	decode_portaudio_openstream();
}


/*
 * This function is called when the stream needs to be reopened at a
 * different sample rate.
 */
static void finished(void *userData) {
	if (change_sample_rate) {
		/* We can't change the sample rate in this thread, so queue a request for
		 * the decoder thread to service
		 */
		if (mqueue_write_request(&decode_mqueue, finished_handler, 0)) {
			mqueue_write_complete(&decode_mqueue);
		}
		else {
			DEBUG_TRACE("Full message queue, dropped finished message");
		}
	}
}


static void decode_portaudio_start(void) {
	DEBUG_TRACE("decode_portaudio_start");

	decode_portaudio_openstream();
}

static void decode_portaudio_pause(void) {
}

static void decode_portaudio_resume(void) {
}

static void decode_portaudio_stop(void) {
	DEBUG_TRACE("decode_portaudio_stop");

	current_sample_rate = 44100;
	change_sample_rate = false;

	decode_portaudio_openstream();
}


static void decode_portaudio_openstream(void) {
	PaError err;

	if (stream) {
		if ((err = Pa_CloseStream(stream)) != paNoError) {
			DEBUG_ERROR("PA error %s", Pa_GetErrorText(err));
		}
	}

	if ((err = Pa_OpenStream(
			&stream,
			NULL,
			&outputParam,
			current_sample_rate,
			paFramesPerBufferUnspecified,
			paPrimeOutputBuffersUsingStreamCallback,
			callback,
			NULL)) != paNoError) {
		DEBUG_ERROR("PA error %s", Pa_GetErrorText(err));
	}

	change_sample_rate = false;
	stream_sample_rate = current_sample_rate;

	/* playout to the end of this stream before changing the sample rate */
	if ((err = Pa_SetStreamFinishedCallback(stream, finished)) != paNoError) {
		DEBUG_ERROR("PA error %s", Pa_GetErrorText(err));
	}

	DEBUG_TRACE("Stream latency %f", Pa_GetStreamInfo(stream)->outputLatency);
	DEBUG_TRACE("Sample rate %f", Pa_GetStreamInfo(stream)->sampleRate);

	if ((err = Pa_StartStream(stream)) != paNoError) {
		DEBUG_ERROR("PA error %s", Pa_GetErrorText(err));
		return;
	}
}


static int decode_portaudio_init(void) {
	PaError err;
	int num_devices, i;
	const PaDeviceInfo *device_info;
	const PaHostApiInfo *host_info;

	if ((err = Pa_Initialize()) != paNoError) {
		goto err;
	}

	DEBUG_TRACE("Portaudio version %s", Pa_GetVersionText());

	memset(&outputParam, 0, sizeof(outputParam));
	outputParam.channelCount = 2;
	outputParam.sampleFormat = paInt32;

	num_devices = Pa_GetDeviceCount();
	for (i = 0; i < num_devices; i++) {
		device_info = Pa_GetDeviceInfo(i);
		host_info = Pa_GetHostApiInfo(device_info->hostApi);

		DEBUG_TRACE("%d: %s (%s)", i, device_info->name, host_info->name);

		outputParam.device = i;

		err = Pa_IsFormatSupported(NULL, &outputParam, 44100);
		if (err == paFormatIsSupported) {
			DEBUG_TRACE("\tsupported");
			break;
		}
		else {
			DEBUG_TRACE("\tnot supported");
		}
	}

	if (i >= num_devices) {
		/* no suitable audio device found */
		return 0;
	}

	/* high latency for robust playback */
	outputParam.suggestedLatency = Pa_GetDeviceInfo(outputParam.device)->defaultHighOutputLatency;

	/* open stream */
	decode_portaudio_openstream();

	return 1;

 err:
	DEBUG_ERROR("PA error %s", Pa_GetErrorText(err));
	return 0;
}


struct decode_audio decode_portaudio = {
	decode_portaudio_init,
	decode_portaudio_start,
	decode_portaudio_pause,
	decode_portaudio_resume,
	decode_portaudio_stop,
};

#endif // HAVE_PORTAUDIO
