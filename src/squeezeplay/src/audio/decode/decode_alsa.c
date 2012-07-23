/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
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
#include <sys/wait.h>


#define ALSA_DEFAULT_DEVICE "default"
#define ALSA_DEFAULT_BUFFER_TIME 30000
#define ALSA_DEFAULT_PERIOD_COUNT 3

#define FLAG_STREAM_PLAYBACK 0x01
#define FLAG_STREAM_EFFECTS  0x02
#define FLAG_STREAM_NOISE    0x04


pid_t effect_pid = -1;
pid_t playback_pid = -1;


static void decode_alsa_check_pids(void) {
	if (effect_pid >= 0) {
		if (waitpid(effect_pid, NULL, WNOHANG) == effect_pid) {
			/* child is dead, exit */
			LOG_ERROR(log_audio_output, "exit, effect child is dead");
			exit(-1);
		}
	}
	if (playback_pid >= 0) {
		if (waitpid(playback_pid, NULL, WNOHANG) == playback_pid) {
			/* child is dead, exit */
			LOG_ERROR(log_audio_output, "exit, playback child is dead");
			exit(-1);
		}
	}
}


static void decode_alsa_start(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_start");

	ASSERT_AUDIO_LOCKED();

	decode_audio->set_sample_rate = decode_audio->track_sample_rate;

	decode_alsa_check_pids();
}


static void decode_alsa_resume(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_resume");

	ASSERT_AUDIO_LOCKED();

	decode_alsa_check_pids();
}


static void decode_alsa_pause(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_pause");

	ASSERT_AUDIO_LOCKED();

	decode_alsa_check_pids();
}


static void decode_alsa_stop(void) {
	LOG_DEBUG(log_audio_output, "decode_alsa_stop");

	ASSERT_AUDIO_LOCKED();

	decode_alsa_check_pids();
}


static pid_t decode_alsa_fork(const char *device, const char *capture, unsigned int buffer_time, unsigned int period_count, unsigned int sample_size, u32_t flags)
{
	char *path, b[10], p[10], f[10], s[10];
	char *cmd[20];
	pid_t pid;
	int i, idx = 0, ret;

	path = alloca(PATH_MAX);

	/* jive_alsa [-v] -d <device> -b <buffer_time> -p <period_count> -f <flags> */

	cmd[idx++] = "jive_alsa";

	if (IS_LOG_PRIORITY(log_audio_output, LOG_PRIORITY_DEBUG)) {
		cmd[idx++] = "-v";
	}

	cmd[idx++] = "-d";
	cmd[idx++] = (char *)device;

	if (capture) {
		cmd[idx++] = "-c";
		cmd[idx++] = (char *)capture;
	}

	snprintf(b, sizeof(b), "%d", buffer_time);
	cmd[idx++] = "-b";
	cmd[idx++] = b;

	snprintf(p, sizeof(p), "%d", period_count);
	cmd[idx++] = "-p";
	cmd[idx++] = p;

	snprintf(s, sizeof(s), "%d", sample_size);
	cmd[idx++] = "-s";
	cmd[idx++] = s;

	snprintf(f, sizeof(f), "%d", flags);

	cmd[idx++] = "-f";
	cmd[idx++] = f;

	cmd[idx] = '\0';

	if (IS_LOG_PRIORITY(log_audio_output, LOG_PRIORITY_DEBUG)) {
		path[0] = '\0';
		for (i=0; i<idx; i++) {
			strncat(path, cmd[i], PATH_MAX);
			strncat(path, " ", PATH_MAX);
		}
		LOG_DEBUG(log_audio_output, "fork %s", path);
	}

	/* command path */
	getcwd(path, PATH_MAX);
	strncat(path, "/jive_alsa", PATH_MAX);

	decode_audio_lock();
	decode_audio->running = false;

	/* fork + exec */
	pid = vfork();
	if (pid < 0) {
		LOG_ERROR(log_audio_output, "fork failed %d", errno);
		return -1;
	}
	if (pid == 0) {
		/* child */
		ret = execv(path, cmd);

		LOG_ERROR(log_audio_output, "execv failed %d", errno);
		_exit(-1);
	}

	/* wait for backend process to start */
	while (1) {
		fifo_wait_timeout(&decode_audio->fifo, 500);

		if (decode_audio->running) {
			break;
		}

		if (waitpid(pid, NULL, WNOHANG) == pid) {
			decode_audio_unlock();

			LOG_ERROR(log_audio_output, "%s failed to start", cmd[0]);
			return -1;
		}

	}
	decode_audio_unlock();

	return pid;
}


static int decode_alsa_init(lua_State *L) {
	const char *playback_device;
	const char *capture_device;
	const char *effects_device;
	unsigned int buffer_time;
	unsigned int period_count;
	unsigned int sample_size;
	int shmid;
	void *buf;

	/* allocate memory */

	// XXXX use shared memory
	shmid = shmget(56833, 0, 0600 | IPC_CREAT);
	if (shmid != -1) {
		shmctl(shmid, IPC_RMID, NULL);
	}

	shmid = shmget(56833, DECODE_AUDIO_BUFFER_SIZE, 0600 | IPC_CREAT);
	if (shmid == -1) {
		// XXXX errors
		LOG_ERROR(log_audio_codec, "shmget error %s", strerror(errno));
		return 0;
	}

	buf = shmat(shmid, 0, 0);
	if (buf == (void *)-1) {
		// XXXX errors
		LOG_ERROR(log_audio_codec, "shmgat error %s", strerror(errno));
		return 0;
	}

	decode_init_buffers(buf, true);


	/* start threads */
	lua_getfield(L, 2, "alsaPlaybackDevice");
	playback_device = luaL_optstring(L, -1, ALSA_DEFAULT_DEVICE);

	lua_getfield(L, 2, "alsaCaptureDevice");
	capture_device = luaL_optstring(L, -1, ALSA_DEFAULT_DEVICE);

	lua_getfield(L, 2, "alsaEffectsDevice");
	effects_device = luaL_optstring(L, -1, NULL);

	lua_getfield(L, 2, "alsaSampleSize");
	sample_size = luaL_optinteger(L, -1, 16);


#if 0
	/* test if device is available */
	if (pcm_test(playback_device, &playback_max_rate) < 0) {
		lua_pop(L, 2);
		return 0;
	}

	if (effects_device && pcm_test(effects_device, NULL) < 0) {
		effects_device = NULL;
	}
#endif


	/* effects device */
	if (effects_device) {
		LOG_DEBUG(log_audio_output, "Effects device: %s", effects_device);

		lua_getfield(L, 2, "alsaEffectsBufferTime");
		buffer_time = luaL_optinteger(L, -1, ALSA_DEFAULT_BUFFER_TIME);
		lua_getfield(L, 2, "alsaEffectsPeriodCount");
		period_count = luaL_optinteger(L, -1, ALSA_DEFAULT_PERIOD_COUNT);
		lua_pop(L, 2);

		effect_pid = decode_alsa_fork(effects_device, NULL, buffer_time, period_count, 16, FLAG_STREAM_EFFECTS);
	}


	/* playback device */
	LOG_DEBUG(log_audio_output, "Playback device: %s", playback_device);

	lua_getfield(L, 2, "alsaPlaybackBufferTime");
	buffer_time = luaL_optinteger(L, -1, ALSA_DEFAULT_BUFFER_TIME);
	lua_getfield(L, 2, "alsaPlaybackPeriodCount");
	period_count = luaL_optinteger(L, -1, ALSA_DEFAULT_PERIOD_COUNT);
	lua_pop(L, 2);

	playback_pid = decode_alsa_fork(playback_device, capture_device, buffer_time, period_count, sample_size,
					(effects_device) ? FLAG_STREAM_PLAYBACK : FLAG_STREAM_PLAYBACK | FLAG_STREAM_EFFECTS /*| FLAG_STREAM_NOISE*/);

	lua_pop(L, 2);

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
