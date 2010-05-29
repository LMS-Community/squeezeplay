/*
** Copyright 2007-2008 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/


/* decoder & audio-output states */
#define DECODE_STATE_RUNNING 		(1 << 0)
#define DECODE_STATE_UNDERRUN		(1 << 1)
#define DECODE_STATE_ERROR		(1 << 2)
#define DECODE_STATE_NOT_SUPPORTED	(1 << 3)
#define DECODE_STATE_LOOPBACK 		(1 << 4)
#define DECODE_STATE_STOPPING 		(1 << 5)
#define DECODE_STATE_AUTOSTART 		(1 << 6)

/* Transitions */
#define TRANSITION_NONE               0x0
#define TRANSITION_CROSSFADE          0x1
#define TRANSITION_FADE_IN            0x2
#define TRANSITION_FADE_OUT           0x4

/* Polarity inversion */
#define POLARITY_INVERSION_LEFT	      0x1
#define POLARITY_INVERSION_RIGHT      0x2

/* Output channel flags */
#define OUTPUT_CHANNEL_LEFT           0x4
#define OUTPUT_CHANNEL_RIGHT          0x8

#define TESTTONES_OFF					0
#define TESTTONES_MULTITONE				1
#define TESTTONES_LEFT_CHANNEL				2
#define TESTTONES_SINE40_44100  			10
#define TESTTONES_SINE40_48000  			11
#define TESTTONES_SINE40_88200  			12
#define TESTTONES_SINE40_96000  			13
#define TESTTONES_SINE40_192000 			14


/* Minimum bytes in streambuf before we start decoding */
#define DECODE_MINIMUM_BYTES_FLAC			25000
#define DECODE_MINIMUM_BYTES_OTHER			512


extern int luaopen_decode(lua_State *L);
