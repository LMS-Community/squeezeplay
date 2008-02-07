/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "jive.h"


struct jive_sample {
	Uint32 refcount;
	Uint32 len;
	Uint32 pos;
	Uint32 mixer;
	Uint8 *data;
	bool enabled;
};


// mixer channels
#define MAX_SOUNDS 2
struct jive_sample *mixsnd[MAX_SOUNDS];

int effect_volume = SDL_MIX_MAXVOLUME;


static void free_sound(struct jive_sample *snd) {
	if (--snd->refcount > 0) {
		return;
	}

	free(snd->data);
	free(snd);
}


static int jiveL_sound_gc(lua_State *L) {
	struct jive_sample *snd = *(struct jive_sample **)lua_touserdata(L, 1);
	if (snd) {
		free_sound(snd);
	}
	return 0;
}


static void mixaudio(void *unused, Uint8 *stream, int len) {
	Uint32 size;
	int i;

	for (i = 0; i < MAX_SOUNDS; i++) {
		if (mixsnd[i] == NULL) {
			continue;
		}

		size = mixsnd[i]->len - mixsnd[i]->pos;
		if (size > len) {
			size = len;
		}

		// This mixer function should only be used for two sounds
		SDL_MixAudio(stream, &mixsnd[i]->data[mixsnd[i]->pos], size, effect_volume);
		mixsnd[i]->pos += size;

		if (mixsnd[i]->pos >= mixsnd[i]->len) {
			free_sound(mixsnd[i]);
			mixsnd[i] = NULL;
		}
	}
}


static void open_audio(void) {
	SDL_AudioSpec fmt;

	if (SDL_GetAudioStatus() != SDL_AUDIO_STOPPED) {
		return;
	}

	/* SDL audio 44.1k 16 bit */
	fmt.freq = 44100;
	fmt.format = AUDIO_S16;
	fmt.channels = 2;
	fmt.samples = 512;
	fmt.callback = mixaudio;
	fmt.userdata = NULL;
	
	if (SDL_OpenAudio(&fmt, NULL) < 0) {
		fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
	}
	SDL_PauseAudio(0);
}


static void close_audio(void) {
	if (SDL_GetAudioStatus() == SDL_AUDIO_STOPPED) {
		return;
	}

	SDL_CloseAudio();
}


static struct jive_sample *load_sound(char *filename, Uint32 mixer) {
	struct jive_sample *snd;
	SDL_AudioSpec wave;
	SDL_AudioCVT cvt;
	Uint8 *data;
	Uint32 len;

	if (SDL_LoadWAV(filename, &wave, &data, &len) == NULL) {
		fprintf(stderr, "Couldn't load sound %s: %s\n", filename, SDL_GetError());
		return NULL;
	}

	if (SDL_BuildAudioCVT(&cvt, wave.format, wave.channels, wave.freq,
			      AUDIO_S16, 2, 44100) < 0) {
		fprintf(stderr, "Couldn't build audio converter: %s\n", SDL_GetError());
		SDL_FreeWAV(data);
		return NULL;
	}
	cvt.buf = malloc(len * cvt.len_mult);
	memcpy(cvt.buf, data, len);
	cvt.len = len;
	
	if (SDL_ConvertAudio(&cvt) < 0) {
		fprintf(stderr, "Couldn't convert audio: %s\n", SDL_GetError());
		SDL_FreeWAV(data);
		return NULL;
	}
	SDL_FreeWAV(data);

	snd = malloc(sizeof(struct jive_sample));
	snd->refcount = 1;
	snd->data = cvt.buf;
	snd->len = cvt.len_cvt;
	snd->mixer = mixer;
	snd->enabled = true;

	return snd;
}


static int jiveL_audio_load(lua_State *L) {
	struct jive_sample **snd;
	char fullpath[PATH_MAX];
	
	/* stack is:
	 * 1: audio
	 * 2: filename
	 * 3: mixer
	 */

	/* load sample */
	lua_getfield(L, LUA_REGISTRYINDEX, "jive.samples");
	lua_pushvalue(L, 2); // filename
	lua_gettable(L, -2);

	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);

		if (!jive_find_file(lua_tostring(L, 2), fullpath)) {
			printf("Cannot find sound %s\n", lua_tostring(L, 2));
			return 0;
		}

		snd = (struct jive_sample **)lua_newuserdata(L, sizeof(struct jive_sample *));
		*snd = load_sound(fullpath, luaL_optinteger(L, 3, 0));

		if (*snd == NULL) {
			return 0;
		}

		luaL_getmetatable(L, "jive.sound");
		lua_setmetatable(L, -2);

		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_settable(L, -4);
	}

	return 1;
}


static int jiveL_audio_set_effect_volume(lua_State *L) {
	/* stack is:
	 * 1: sound
	 * 2: enabled
	 */

	effect_volume = lua_tointeger(L, 2);
	if (effect_volume > 0) {
		open_audio();
	}
	else {
		close_audio();
	}

	return 0;
}


static int jiveL_audio_get_effect_volume(lua_State *L) {
	lua_pushinteger(L, effect_volume);
	return 1;
}


static int jiveL_sound_play(lua_State *L) {
	struct jive_sample *snd;

	/* stack is:
	 * 1: sound
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, -1);
	if (!snd->enabled) {
		return 0;
	}

	/* play sample */
	SDL_LockAudio();

	if (mixsnd[snd->mixer] != NULL) {
		/* slot is not free */
		SDL_UnlockAudio();
		return 0;
	}

	mixsnd[snd->mixer] = snd;
	mixsnd[snd->mixer]->refcount++;
	mixsnd[snd->mixer]->pos = 0;
	SDL_UnlockAudio();

	return 0;
}


static int jiveL_sound_enable(lua_State *L) {
	struct jive_sample *snd;

	/* stack is:
	 * 1: sound
	 * 2: enabled
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, 1);
	snd->enabled = lua_toboolean(L, 2);

	return 0;
}


static int jiveL_sound_is_enabled(lua_State *L) {
	struct jive_sample *snd;

	/* stack is:
	 * 1: sound
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, 1);
	lua_pushboolean(L, snd->enabled);

	return 1;
}


int jiveL_free_audio(lua_State *L) {
	close_audio();
	return 0;
}



static const struct luaL_Reg sound_m[] = {
	{ "__gc", jiveL_sound_gc },
	{ "play", jiveL_sound_play },
	{ "enable", jiveL_sound_enable },
	{ "isEnabled", jiveL_sound_is_enabled },
	{ NULL, NULL }
};

static const struct luaL_Reg audio_c[] = {
	{ "loadSound", jiveL_audio_load },
	{ "setEffectVolume", jiveL_audio_set_effect_volume },
	{ "getEffectVolume", jiveL_audio_get_effect_volume },
	{ NULL, NULL }
};


int jiveL_init_audio(lua_State *L) {
	int i;

	JIVEL_STACK_CHECK_BEGIN(L);

	for (i = 0; i < MAX_SOUNDS; i++) {
		mixsnd[i] = NULL;
	}

	open_audio();

	/* sample cache */
	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, "jive.samples");

	/* sound methods */
	luaL_newmetatable(L, "jive.sound");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, NULL, sound_m);

	/* sound class */
	lua_getglobal(L, "jive");
	lua_getfield(L, -1, "ui");
	lua_getfield(L, -1, "Audio");
	luaL_register(L, NULL, audio_c);

	lua_pushinteger(L, SDL_MIX_MAXVOLUME);
	lua_setfield(L, -2, "MAXVOLUME");

	lua_pop(L, 4);

	JIVEL_STACK_CHECK_END(L);

	return 0;
}

