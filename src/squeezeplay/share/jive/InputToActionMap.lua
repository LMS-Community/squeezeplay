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
	["Q"]  = "power",

--END temp shortcuts to test action framework

	["/"]   = "go_search",
	["h"]   = "go_home",
	["J"]   = "go_home",
	["x"]   = "play",
	["p"]   = "play",
	["P"]   = "create_mix",
	[" "]   = "pause",
	["c"]   = "pause",
	["C"]   = "stop",
	["a"]   = "addEnd",
	["A"]   = "addNext",
	["\b"]  = "back", -- BACKSPACE
	["\27"] = "back", -- ESC
	["j"]   = "back",
	["l"]   = "go",
	["S"]   = "take_screenshot",
	
}


keyActionMappings = {}
keyActionMappings.press = {
	[KEY_HOME] = "go_home"
}


keyActionMappings.hold = {
	[KEY_BACK] = "disconnect_player",
	[KEY_LEFT] = "go_home",
	[KEY_REW | KEY_PAUSE] = "take_screenshot"  -- a stab at how to handle multi-press
}

