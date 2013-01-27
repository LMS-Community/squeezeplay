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

typedef int PaDeviceIndex;
typedef double PaTime;

typedef struct PaStreamParameters
{
    /** A valid device index in the range 0 to (Pa_GetDeviceCount()-1)
     specifying the device to be used or the special constant
     paUseHostApiSpecificDeviceSpecification which indicates that the actual
     device(s) to use are specified in hostApiSpecificStreamInfo.
     This field must not be set to paNoDevice.
    */
    PaDeviceIndex device;
    
    /** The number of channels of sound to be delivered to the
     stream callback or accessed by Pa_ReadStream() or Pa_WriteStream().
     It can range from 1 to the value of maxInputChannels in the
     PaDeviceInfo record for the device specified by the device parameter.
    */
    int channelCount;

    /** The sample format of the buffer provided to the stream callback,
     a_ReadStream() or Pa_WriteStream(). It may be any of the formats described
     by the PaSampleFormat enumeration.
    */
    PaSampleFormat sampleFormat;

    /** The desired latency in seconds. Where practical, implementations should
     configure their latency based on these parameters, otherwise they may
     choose the closest viable latency instead. Unless the suggested latency
     is greater than the absolute upper limit for the device implementations
     should round the suggestedLatency up to the next practical value - ie to
     provide an equal or higher latency than suggestedLatency wherever possible.
     Actual latency values for an open stream may be retrieved using the
     inputLatency and outputLatency fields of the PaStreamInfo structure
     returned by Pa_GetStreamInfo().
     @see default*Latency in PaDeviceInfo, *Latency in PaStreamInfo
    */
    PaTime suggestedLatency;

} PaStreamParameters;

/* Portaudio stream */
static PaStreamParameters outputParam;
static PaStream *stream;

/* Stream sample rate */
static u32_t stream_sample_rate;

static void decode_portaudio_openstream(void);

static int paContinue=0; /* < Signal that the stream should continue invoking the callback and processing audio. */
static int paComplete=1; /* < Signal that the stream should stop invoking the callback and finish once all output samples have played. */

static unsigned long paFramesPerBuffer = 8192L;
static unsigned long paNumberOfBuffers = 3L;

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

static int strnicmp(const char *s1, const char *s2, size_t n)
{
	if (n == 0)
		return 0;
	do {
		if (toupper(*s1) != toupper(*s2++))
			return toupper(*(unsigned const char *)s1) - toupper(*(unsigned const char *)--s2);
		if (*s1++ == 0)
			break;
	} while (--n != 0);

	return 0;
}

/*
 * This function is called by portaudio when the stream is active to request
 * audio samples
 */
static int callback(void *inputBuffer,
		    void *outputBuffer,
		    unsigned long framesPerBuffer,
		    PaTimestamp outTime,
		    void *userData) {
	size_t bytes_used, len, skip_bytes = 0, add_bytes = 0;
	int add_silence_ms;
	bool_t reached_start_point;
	Uint8 *outputArray = (u8_t *)outputBuffer;
	u32_t delay;
	int ret = paContinue;

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

	delay = 0;
	/* delay = (timeInfo->outputBufferDacTime - Pa_GetStreamTime(stream)) * decode_audio->track_sample_rate; */

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
			LOG_WARN(log_audio_output, "Sample rate changed from %d to %d\n", stream_sample_rate, decode_audio->track_sample_rate);
			decode_audio->set_sample_rate = decode_audio->track_sample_rate;
			ret = paComplete; // will trigger the finished callback to change the samplerate
			finished (userData);
		}
	}

 mixin_effects:
	/* mix in sound effects */
	decode_mix_effects(outputBuffer, framesPerBuffer, 24, stream_sample_rate);

	decode_audio_unlock();

	return ret;
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

	LOG_WARN(log_audio_output, "Setting sample rate %lu", set_sample_rate);

	if ((err = Pa_OpenStream(
			&stream,
			paNoDevice,
			0,
			0,
			NULL,
			outputParam.device,
			outputParam.channelCount,
			outputParam.sampleFormat,
			NULL,
			set_sample_rate,
			paFramesPerBuffer,
			paNumberOfBuffers,
			paNoFlag,
			callback,
			NULL)) != paNoError) {
		LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
	}

	stream_sample_rate = set_sample_rate;

	if ((err = Pa_StartStream(stream)) != paNoError) {
		LOG_WARN(log_audio_output, "PA error %s", Pa_GetErrorText(err));
		return;
	}
}


static int decode_portaudio_init(lua_State *L) {
	PaError err;
	PaDeviceIndex num_devices;
	PaDeviceIndex i;
	PaDeviceIndex user_deviceid;
	const PaDeviceInfo *device_info;
	const char *padevname;
	int devnamelen;
	const char *padevid;
	const char *pabuffersize;
	const char *panumbufs;
	const char *pamaxrate;
	u32_t user_pamaxrate;
	void *buf;

	if ((err = Pa_Initialize()) != paNoError) {
		goto err0;
	}

	LOG_WARN(log_audio_output, "Portaudio version v18.1");

	memset(&outputParam, 0, sizeof(outputParam));
	outputParam.channelCount = 2;
	outputParam.sampleFormat = paInt32;
 
	padevname = getenv("USEPADEVICE");
	padevid  = getenv("USEPADEVICEID");

	num_devices = Pa_CountDevices();

	for (i = 0; i < num_devices; i++)
	{
		device_info = Pa_GetDeviceInfo(i);

		LOG_WARN(log_audio_output, "%d: %s", i, device_info->name);

		if ( (padevname != NULL) && (device_info->name != NULL) )
		{
			devnamelen = strlen (padevname);
			if ( strnicmp(device_info->name, padevname, devnamelen) == 0 )
			{
				outputParam.device = i;
				break;
			}
		}

		if ( padevid != NULL )
		{
			user_deviceid = (PaDeviceIndex) strtoul ( padevid, NULL, 0 );
			if ( user_deviceid == i )
			{
				outputParam.device = i;
				break;
			}
		}
	}

	/* No match found, use default device */
	if ( (i >= num_devices) || ( outputParam.device >= num_devices ) )
	{
		outputParam.device = Pa_GetDefaultOutputDeviceID();

		/* no suitable audio device found */
		if ( outputParam.device == paNoDevice )
		{
			LOG_WARN(log_audio_output,"No default audio device found-playback disabled");
			return 0;
		}
	}

	pabuffersize = getenv("USEPAFRAMESPERBUFFER");

	if ( pabuffersize != NULL )
	{
		paFramesPerBuffer = strtoul(pabuffersize, NULL, 0);
		if ( ( paFramesPerBuffer < 1024L ) || ( paFramesPerBuffer > 262144L ) )
			paFramesPerBuffer = 1024L;
	}

	panumbufs = getenv("USEPANUMBEROFBUFFERS");

	if ( panumbufs != NULL )
	{
		paNumberOfBuffers = strtoul(panumbufs, NULL, 0);
		if ( ( paNumberOfBuffers < 2L ) || ( paNumberOfBuffers > 32L ) )
			paNumberOfBuffers = 2L;
	}

	LOG_WARN(log_audio_output, "Using (%lu) buffers of (%lu) frames per buffer",
			paNumberOfBuffers, paFramesPerBuffer);

	pamaxrate = getenv("USEPAMAXSAMPLERATE");

	if ( pamaxrate != NULL )
	{
		user_pamaxrate = (u32_t) strtoul(pamaxrate, NULL, 0);
		if ( ( user_pamaxrate < 32000L ) || ( user_pamaxrate > 384000L ) )
			user_pamaxrate = 48000;
	}
	else
	{
		user_pamaxrate = 48000;
	}

	LOG_WARN(log_audio_output, "Setting maximum samplerate to (%lu)", user_pamaxrate );

	/* allocate output memory */
	buf = malloc(DECODE_AUDIO_BUFFER_SIZE);
	if (!buf) {
		goto err0;
	}

	decode_init_buffers(buf, false);
	decode_audio->max_rate = user_pamaxrate;

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
