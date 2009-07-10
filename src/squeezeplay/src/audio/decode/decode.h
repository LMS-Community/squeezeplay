/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


/* decoder state */
#define DECODE_STATE_RUNNING 		(1 << 0)
#define DECODE_STATE_UNDERRUN		(1 << 1)
#define DECODE_STATE_ERROR		(1 << 2)
#define DECODE_STATE_NOT_SUPPORTED	(1 << 3)
#define DECODE_STATE_EFFECT		(1 << 4)

/* Transitions */
#define TRANSITION_NONE               0x0
#define TRANSITION_CROSSFADE          0x1
#define TRANSITION_FADE_IN            0x2
#define TRANSITION_FADE_OUT           0x4

/* Polarity inversion */
#define POLARITY_INVERSION_LEFT	      0x1
#define POLARITY_INVERSION_RIGHT      0x2


#define TESTTONES_OFF					0
#define TESTTONES_MULTITONE				1
#define TESTTONES_LEFT_CHANNEL				2
#define TESTTONES_SINE40_44100  			10
#define TESTTONES_SINE40_48000  			11
#define TESTTONES_SINE40_88200  			12
#define TESTTONES_SINE40_96000  			13
#define TESTTONES_SINE40_192000 			14


extern int luaopen_decode(lua_State *L);
