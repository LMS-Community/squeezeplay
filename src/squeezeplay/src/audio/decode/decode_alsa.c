/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/

#include "common.h"

#include "audio/fifo.h"
#include "audio/fixed_math.h"
#include "audio/mqueue.h"
#include "audio/streambuf.h"
#include "audio/decode/decode.h"
#include "audio/decode/decode_priv.h"


#ifdef HAVE_LIBASOUND

#include <pthread.h>
#include <alsa/asoundlib.h>


/* debug switches */
#define TEST_LATENCY 0
#define TEST_OUTPUT_NOISE 0

#define ALSA_DEFAULT_DEVICE "default"
#define ALSA_DEFAULT_BUFFER_TIME 30000
#define ALSA_DEFAULT_PERIOD_COUNT 3






static void decode_alsa_start(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_start");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = decode_audio->track_sample_rate;
}


static void decode_alsa_resume(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_resume");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = decode_audio->track_sample_rate;
}


static void decode_alsa_pause(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_pause");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = 44100;
}


static void decode_alsa_stop(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_stop");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = 44100;
}


static int decode_alsa_init(lua_State *L) {
#if 0
	int err;
	const char *playback_device;
	const char *effects_device;
	unsigned int buffer_time;
	unsigned int period_count;


	if ((err = snd_output_stdio_attach(&output, stdout, 0)) < 0) {
		LOG_ERROR(log_audio_output, "Output failed: %s", snd_strerror(err));
		return 0;
	}

	lua_getfield(L, 2, "alsaPlaybackDevice");
	playback_device = luaL_optstring(L, -1, ALSA_DEFAULT_DEVICE);

	lua_getfield(L, 2, "alsaEffectsDevice");
	effects_device = luaL_optstring(L, -1, NULL);


	/* test if device is available */
	if (pcm_test(playback_device, &playback_max_rate) < 0) {
		lua_pop(L, 2);
		return 0;
	}

	if (effects_device && pcm_test(effects_device, NULL) < 0) {
		effects_device = NULL;
	}

	LOG_DEBUG(log_audio_output, "Playback device: %s", playback_device);

	lua_getfield(L, 2, "alsaPlaybackBufferTime");
	buffer_time = luaL_optinteger(L, -1, ALSA_DEFAULT_BUFFER_TIME);
	lua_getfield(L, 2, "alsaPlaybackPeriodCount");
	period_count = luaL_optinteger(L, -1, ALSA_DEFAULT_PERIOD_COUNT);
	lua_pop(L, 2);

	playback_state =
		decode_alsa_thread_init(playback_device,
					buffer_time,
					period_count,
					(effects_device) ? FLAG_STREAM_PLAYBACK : FLAG_STREAM_PLAYBACK | FLAG_STREAM_EFFECTS
					);

	if (effects_device) {
		LOG_DEBUG(log_audio_output, "Effects device: %s", effects_device);

		lua_getfield(L, 2, "alsaEffectsBufferTime");
		buffer_time = luaL_optinteger(L, -1, ALSA_DEFAULT_BUFFER_TIME);
		lua_getfield(L, 2, "alsaEffectsPeriodCount");
		period_count = luaL_optinteger(L, -1, ALSA_DEFAULT_PERIOD_COUNT);
		lua_pop(L, 2);

		effects_state = 
			decode_alsa_thread_init(effects_device,
						buffer_time,
						period_count,
						FLAG_STREAM_EFFECTS
						);
	}

	lua_pop(L, 2);
#endif

	int shmid;
	size_t shmsize;



	// XXXX use shared memory

	shmid = shmget(1234, 0, 0600 | IPC_CREAT);
	if (shmid != -1) {
		shmctl(shmid, IPC_RMID, NULL);
	}

	shmsize = DECODE_FIFO_SIZE + sizeof(struct decode_audio);
	shmid = shmget(1234, shmsize, 0600 | IPC_CREAT);
	if (shmid == -1) {
		// XXXX errors
		LOG_ERROR(log_audio_codec, "shmget error %s", strerror(errno));
		return 0;
	}

	decode_audio = shmat(shmid, 0, 0);
	if ((int)decode_audio == -1) {
		// XXXX errors
		LOG_ERROR(log_audio_codec, "shmgat error %s", strerror(errno));
		return 0;
	}

	decode_audio->set_sample_rate = 44100;
	fifo_init(&decode_audio->fifo, DECODE_FIFO_SIZE, true);


	decode_fifo_buf = (((u8_t *)decode_audio) + sizeof(struct decode_audio));




	return 1;
}


struct decode_audio_func decode_alsa = {
	decode_alsa_init,
	decode_alsa_start,
	decode_alsa_pause,
	decode_alsa_resume,
	decode_alsa_stop,
};

#endif // HAVE_LIBASOUND
