-- input to action mappings

local Framework        = require("jive.ui.Framework")
module(..., Framework.constants)


charActionMappings = {}
charActionMappings.press = {
--BEGIN temp shortcuts to test action framework
	["["]  = "go_now_playing",
	["]"]  = "go_playlist",
	["{"]  = "go_current_track_details",
	["}"]  = "go_playlists",
	[";"]  = "go_music_library",
	[":"]  = "go_favorites",
	["'"]  = "go_rhapsody",
	[","]  = "shuffle_toggle",
	["."]  = "repeat_toggle",
	["|"]  = "sleep",
	["Q"]  = "power",

--END temp shortcuts to test action framework

	["/"]   = "go_search",
	["h"]   = "go_home",
	["J"]   = "go_home_or_now_playing",
	["D"]   = "disconnect_player",
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
	["}"]  = "debug_skin",

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
}

--Hmm, this won't work yet since we still look for KEY_PRESS in a lot of places, and would get double responses
--keyActionMappings = {}
--keyActionMappings.down = {
--	[KEY_LEFT] = "back",
--	[KEY_BACK] = "back",
--}


keyActionMappings.hold = {
	[KEY_HOME] = "shutdown",
	[KEY_PLAY] = "create_mix",
	[KEY_ADD]  = "add_next",
	[KEY_BACK] = "disconnect_player",
	[KEY_LEFT] = "disconnect_player",
	[KEY_GO] = "go_hold", --has no default assignment yet
	[KEY_RIGHT] = "go_hold",
	[KEY_PAUSE] = "stop",
	[KEY_FWD] = "scanner_fwd",
	[KEY_REW] = "scanner_rew",
	[KEY_VOLUME_UP] = "volume_up",
	[KEY_VOLUME_DOWN] = "volume_down",
	[KEY_REW | KEY_PAUSE] = "take_screenshot",  -- a stab at how to handle multi-press
}

