/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#include "common.h"
#include "ui/jive.h"
#include "audio/fixed_math.h"
#include "audio/decode/decode_priv.h"


struct jive_sample {
	unsigned int refcount;
	Uint8 *data;
	size_t frames;
	int channels;
	size_t pos;
	int mixer;
	bool enabled;
};


/* mixer channels */
u8_t *effect_fifo_buf[MAX_EFFECT_SAMPLES];

#define MAXVOLUME 100
static int effect_volume = MAXVOLUME;
static int effect_attn = MAXVOLUME;


static void sample_free(struct jive_sample *sample) {
	if (--sample->refcount > 0) {
		return;
	}

	if (sample->data) {
		free(sample->data);
	}
	free(sample);
}


static int decode_sample_obj_gc(lua_State *L) {
	struct jive_sample *sample = *(struct jive_sample **)lua_touserdata(L, 1);

	if (sample) {
		sample_free(sample);
	}

	return 0;
}


static int decode_sample_obj_play(lua_State *L) {
	struct jive_sample *snd;
	struct fifo *ch_fifo;
	size_t size, n;
	int ch;

	/* stack is:
	 * 1: sound
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, -1);
	if (!snd->enabled || !decode_audio) {
		return 0;
	}

	// XXXX don't lock channels?

	ch = snd->mixer;
	ch_fifo = &decode_audio->effect_fifo[ch];

	decode_audio_lock();
	fifo_lock(ch_fifo);

	if (!fifo_empty(ch_fifo)) {
		/* effect already playing in this channel */
		fifo_unlock(ch_fifo);
		decode_audio_unlock();
		return 0;
	}

	size = MIN(snd->frames * sizeof(effect_t), EFFECT_FIFO_SIZE);
	while (size) {
		n = fifo_bytes_until_wptr_wrap(ch_fifo);
		if (n > size) {
			n = size;
		}

		memcpy(effect_fifo_buf[ch] + ch_fifo->wptr, snd->data, n);
		fifo_wptr_incby(ch_fifo, n);
		size -= n;
	}

	fifo_unlock(ch_fifo);
	decode_audio_unlock();

	return 0;
}


static int decode_sample_obj_enable(lua_State *L) {
	struct jive_sample *snd;

	/* stack is:
	 * 1: sound
	 * 2: enabled
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, 1);
	snd->enabled = lua_toboolean(L, 2);

	return 0;
}


static int decode_sample_obj_is_enabled(lua_State *L) {
	struct jive_sample *snd;

	/* stack is:
	 * 1: sound
	 */

	snd = *(struct jive_sample **)lua_touserdata(L, 1);
	lua_pushboolean(L, snd->enabled);

	return 1;
}


static struct jive_sample *load_sound(char *filename, int mixer) {
	struct jive_sample *snd;
	SDL_AudioSpec wave;
	SDL_AudioCVT cvt;
	Uint8 *data;
	Uint32 len;

	// FIXME rewrite to not use SDL
	if (SDL_LoadWAV(filename, &wave, &data, &len) == NULL) {
		LOG_WARN(log_audio_decode, "Couldn't load sound %s: %s\n", filename, SDL_GetError());
		return NULL;
	}

	/* Convert to signed 16 bit mono */
	if (SDL_BuildAudioCVT(&cvt, wave.format, wave.channels, wave.freq,
			      AUDIO_S16SYS, 1, 44100) < 0) {
		LOG_WARN(log_audio_decode, "Couldn't build audio converter: %s\n", SDL_GetError());
		SDL_FreeWAV(data);
		return NULL;
	}
	cvt.buf = malloc(len * cvt.len_mult);
	memcpy(cvt.buf, data, len);
	cvt.len = len;
	
	if (SDL_ConvertAudio(&cvt) < 0) {
		LOG_WARN(log_audio_decode, "Couldn't convert audio: %s\n", SDL_GetError());
		SDL_FreeWAV(data);
		free(cvt.buf);
		return NULL;
	}
	SDL_FreeWAV(data);

	snd = malloc(sizeof(struct jive_sample));
	snd->refcount = 1;
	snd->data = cvt.buf;
	snd->frames = cvt.len_cvt / sizeof(effect_t);
	snd->channels = 1;
	snd->pos = 0;
	snd->mixer = mixer;
	snd->enabled = true;

	return snd;
}


static int decode_sample_load(lua_State *L) {
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

		if (!squeezeplay_find_file(lua_tostring(L, 2), fullpath)) {
			LOG_WARN(log_audio_decode, "Cannot find sound %s\n", lua_tostring(L, 2));
			return 0;
		}

		snd = (struct jive_sample **)lua_newuserdata(L, sizeof(struct jive_sample *));
		*snd = load_sound(fullpath, luaL_optinteger(L, 3, 0));

		if (*snd == NULL) {
			return 0;
		}

		luaL_getmetatable(L, "squeezeplay.sample.obj");
		lua_setmetatable(L, -2);

		lua_pushvalue(L, 2);
		lua_pushvalue(L, -2);
		lua_settable(L, -4);
	}

	return 1;
}


static int decode_sample_set_effect_volume(lua_State *L) {
	/* stack is:
	 * 1: sound
	 * 2: enabled
	 */

	effect_volume = lua_tointeger(L, 2);

	if (effect_volume < 0) {
		effect_volume = 0;
	}
	if (effect_volume > MAXVOLUME) {
		effect_volume = MAXVOLUME;
	}

	decode_audio_lock();

	decode_audio->effect_gain = 
		fixed_mul(fixed_div(s32_to_fixed(effect_volume),
				    s32_to_fixed(MAXVOLUME)),
			  fixed_div(s32_to_fixed(effect_attn),
				    s32_to_fixed(MAXVOLUME))
			  );

	decode_audio_unlock();

	return 0;
}


static int decode_sample_get_effect_volume(lua_State *L) {
	lua_pushinteger(L, effect_volume);
	return 1;
}


static int decode_sample_set_effect_attenuation(lua_State *L) {
	/* stack is:
	 * 1: sound
	 * 2: attenuation
	 */

	effect_attn = lua_tointeger(L, 2);

	if (effect_attn < 0) {
		effect_attn = 0;
	}
	if (effect_attn > MAXVOLUME) {
		effect_attn = MAXVOLUME;
	}

	decode_audio_lock();

	decode_audio->effect_gain =
		fixed_mul(fixed_div(s32_to_fixed(effect_volume),
				    s32_to_fixed(MAXVOLUME)),
			  fixed_div(s32_to_fixed(effect_attn),
				    s32_to_fixed(MAXVOLUME))
			  );

	decode_audio_unlock();

	return 0;
}


static const struct luaL_Reg sample_m[] = {
	{ "__gc", decode_sample_obj_gc },
	{ "play", decode_sample_obj_play },
	{ "enable", decode_sample_obj_enable },
	{ "isEnabled", decode_sample_obj_is_enabled },
	{ NULL, NULL }
};

static const struct luaL_Reg sample_f[] = {
	{ "loadSample", decode_sample_load },
	{ "setEffectVolume", decode_sample_set_effect_volume },
	{ "getEffectVolume", decode_sample_get_effect_volume },
	{ "setEffectAttenuation", decode_sample_set_effect_attenuation },
	{ NULL, NULL }
};


int decode_sample_init(lua_State *L) {
	JIVEL_STACK_CHECK_BEGIN(L);

	/* sample cache */
	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, "jive.samples");

	/* sound methods */
	luaL_newmetatable(L, "squeezeplay.sample.obj");

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, NULL, sample_m);

	/* sound class */
	luaL_register(L, "squeezeplay.sample", sample_f);

	lua_pushinteger(L, MAXVOLUME);
	lua_setfield(L, -2, "MAXVOLUME");

	lua_pop(L, 2);

	JIVEL_STACK_CHECK_END(L);

	return 0;
}
