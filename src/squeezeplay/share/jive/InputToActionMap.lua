-- input to action mappings

local Framework        = require("jive.ui.Framework")
module(..., Framework.constants)


charActionMappings = {}
charActionMappings.press = {
--BEGIN temp shortcuts to test action framework
	["["]  = "go_now_playing",
	["]"]  = "go_playlist",
	["{"]  = "go_current_track_details",
	["`"]  = "go_playlists",
	[";"]  = "go_music_library",
	[":"]  = "go_favorites",
	["'"]  = "go_brightness",
	[","]  = "shuffle_toggle",
	["."]  = "repeat_toggle",
	["|"]  = "sleep",
	["Q"]  = "power",

--END temp shortcuts to test action framework

	["/"]   = "go_search",
	["h"]   = "go_home",
	["J"]   = "go_home_or_now_playing",
	["D"]   = "soft_reset",
	["x"]   = "play",
	["p"]   = "play",
	["P"]   = "create_mix",
	[" "]   = "pause",
	["c"]   = "pause",
	["C"]   = "stop",
	["a"]   = "add",
	["A"]   = "add_next",
	["\b"]  = "back", -- BACKSPACE
	["\27"] = "back", -- ESC
	["j"]   = "back",
	["l"]   = "go",
	["S"]   = "take_screenshot",
	["z"]  = "jump_rew",
	["<"]  = "jump_rew",
	["Z"]  = "scanner_rew",
	["b"]  = "jump_fwd",
	[">"]  = "jump_fwd",
	["B"]  = "scanner_fwd",
	["+"]  = "volume_up",
	["="]  = "volume_up",
	["-"]  = "volume_down",
	["0"]  = "play_favorite_0",
	["1"]  = "play_favorite_1",
	["2"]  = "play_favorite_2",
	["3"]  = "play_favorite_3",
	["4"]  = "play_favorite_4",
	["5"]  = "play_favorite_5",
	["6"]  = "play_favorite_6",
	["7"]  = "play_favorite_7",
	["8"]  = "play_favorite_8",
	["9"]  = "play_favorite_9",
	["?"]  = "help",
	["t"]  = "context_menu",

	--development tools -- Later when modifier keys are supported, these could be obscured from everyday users
	["R"]  = "reload_skin",
	["}"]  = "debug_skin",
	["~"]  = "debug_touch",

}


keyActionMappings = {}
keyActionMappings.press = {
	[KEY_HOME] = "go_home_or_now_playing",
	[KEY_PLAY] = "play",
	[KEY_ADD] = "add",
	[KEY_BACK] = "back",
	[KEY_LEFT] = "back",
	[KEY_GO] = "go",
	[KEY_RIGHT] = "go",
	[KEY_PAUSE] = "pause",
	[KEY_PAGE_UP] = "page_up",
	[KEY_PAGE_DOWN] = "page_down",
	[KEY_FWD] = "jump_fwd",
	[KEY_REW] = "jump_rew",
	[KEY_VOLUME_UP] = "volume_up",
	[KEY_VOLUME_DOWN] = "volume_down",
	[KEY_PRINT] = "take_screenshot",
}

--Hmm, this won't work yet since we still look for KEY_PRESS in a lot of places, and would get double responses
--keyActionMappings = {}
--keyActionMappings.down = {
--	[KEY_LEFT] = "back",
--	[KEY_BACK] = "back",
--}

gestureActionMappings = {
	[GESTURE_L_R] = "go_home", --will be reset by ShortcutsMeta defaults
	[GESTURE_R_L] = "go_now_playing", --will be reset by ShortcutsMeta defaults
}

keyActionMappings.hold = {
	[KEY_HOME] = "shutdown",
	[KEY_PLAY] = "create_mix",
	[KEY_ADD]  = "add_next",
	[KEY_BACK] = "go_home",
	[KEY_LEFT] = "go_home",
	[KEY_GO] = "context_menu", --has no default assignment yet
	[KEY_RIGHT] = "context_menu",
	[KEY_PAUSE] = "stop",
	[KEY_FWD] = "scanner_fwd",
	[KEY_REW] = "scanner_rew",
	[KEY_VOLUME_UP] = "volume_up",
	[KEY_VOLUME_DOWN] = "volume_down",
	[KEY_REW | KEY_PAUSE] = "take_screenshot",  -- a stab at how to handle multi-press
}

irActionMappings = {}
irActionMappings.press = {
	["sleep"]  = "sleep",
	["power"]  = "power",
	["home"]   = "go_home_or_now_playing",
	["search"]   = "go_search",
	["now_playing"]  = "go_now_playing",
	["size"]  = "go_playlist",
	["browse"]  = "go_music_library",
	["favorites"]  = "go_favorites",
	["brightness"]  = "go_brightness",
	["shuffle"]  = "shuffle_toggle",
	["repeat"]  = "repeat_toggle",

	["arrow_up"]  = "up",
	["arrow_down"]  = "down",
	["arrow_left"]  = "back",
	["arrow_right"]  = "go",
	["play"]  = "play",
	["pause"]  = "pause",
	["add"]  = "add",
	["fwd"]  = "jump_fwd",
	["rew"]  = "jump_rew",
	["volup"]  = "volume_up",
	["voldown"]  = "volume_down",

}

irActionMappings.hold = {
	["sleep"]  = "sleep",
	["power"]  = "power",
	["home"]   = "go_home",
	["search"]   = "go_search",
	["now_playing"]  = "go_now_playing",
	["size"]  = "go_playlist",
	["browse"]  = "go_music_library",
	["favorites"]  = "go_favorites",
	["brightness"]  = "go_brightness",
	["shuffle"]  = "shuffle_toggle",
	["repeat"]  = "repeat_toggle",

	["arrow_left"]  = "go_home",
	["arrow_right"]  = "go_hold",
	["play"]  = "create_mix",
	["pause"]  = "stop",
	["add"]  = "add_next",
	["fwd"]  = "scanner_fwd",
	["rew"]  = "scanner_rew",
	["volup"]  = "volume_up",
	["voldown"]  = "volume_down",
	["0"]  = "play_favorite_0",
	["1"]  = "play_favorite_1",
	["2"]  = "play_favorite_2",
	["3"]  = "play_favorite_3",
	["4"]  = "play_favorite_4",
	["5"]  = "play_favorite_5",
	["6"]  = "play_favorite_6",
	["7"]  = "play_favorite_7",
	["8"]  = "play_favorite_8",
	["9"]  = "play_favorite_9",

}

irActionMappings.hold = {
	["sleep"]  = "sleep",
	["power"]  = "power",
	["home"]   = "go_home",
	["search"]   = "go_search",
	["now_playing"]  = "go_now_playing",
	["size"]  = "go_playlist",
	["browse"]  = "go_music_library",
	["favorites"]  = "go_favorites",
	["brightness"]  = "go_brightness",
	["shuffle"]  = "shuffle_toggle",
	["repeat"]  = "repeat_toggle",

	["arrow_left"]  = "go_home",
	["arrow_right"]  = "go_hold",
	["play"]  = "create_mix",
	["pause"]  = "stop",
	["add"]  = "add_next",
	["fwd"]  = "scanner_fwd",
	["rew"]  = "scanner_rew",
	["volup"]  = "volume_up",
	["voldown"]  = "volume_down",
	["0"]  = "play_favorite_0",
	["1"]  = "play_favorite_1",
	["2"]  = "play_favorite_2",
	["3"]  = "play_favorite_3",
	["4"]  = "play_favorite_4",
	["5"]  = "play_favorite_5",
	["6"]  = "play_favorite_6",
	["7"]  = "play_favorite_7",
	["8"]  = "play_favorite_8",
	["9"]  = "play_favorite_9",

}


actionActionMappings = {
	["title_left_press"]  = "back", --will be reset by ShortcutsMeta defaults
	["title_left_hold"]  = "go_home", --will be reset by ShortcutsMeta defaults
	["title_right_press"]  = "go_now_playing", --will be reset by ShortcutsMeta defaults
	["title_right_hold"]  = "go_playlist", --will be reset by ShortcutsMeta defaults
}

-- enter actions here that are triggered in the app but not by any hard input mechanism. Entering them here will get them registered so they can be used
unassignedActionMappings = {
	"finish_operation",
	"more_help",
	"cursor_left",
	"cursor_right",
	"clear",
	"go_rhapsody",
	"nothing",
}
