--[[

Shortcuts applet

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")
local Framework     = require("jive.ui.Framework")
local debug               = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain


module(..., Framework.constants)
oo.class(_M, AppletMeta)

local _supportedMachines = {
	["baby"] = 1,
	["fab4"] = 1,
	["squeezeplay"] = 1,
}

function jiveVersion(meta)
	return 1, 1
end

function defaultSettings(meta)
	return {
		actionActionMappings = {
			["title_left_press"]  = "back",
			["title_left_hold"]  = "go_home",
			["title_right_press"]  = "go_now_playing",
			["title_right_hold"]  = "go_playlist",
			["home_title_left_press"]  = "power",
			["home_title_left_hold"]  = "power",
		},
		gestureActionMappings = {
			[GESTURE_L_R] = "go_home",
			[GESTURE_R_L] = "go_now_playing_or_playlist",
		},
		keyActionMappings = {
			press = {
				[KEY_ALARM] = "go_alarms",
				[KEY_ADD] = "add",
				[KEY_MUTE] = "mute",
				[KEY_PRESET_1] = "play_preset_1",
				[KEY_PRESET_2] = "play_preset_2",
				[KEY_PRESET_3] = "play_preset_3",
				[KEY_PRESET_4] = "play_preset_4",
				[KEY_PRESET_5] = "play_preset_5",
				[KEY_PRESET_6] = "play_preset_6",
			},
			hold = {
				[KEY_GO] = "add",
				[KEY_ALARM] = "go_alarms",
				[KEY_ADD]  = "add_end",
				[KEY_HOME] = "go_home",
				[KEY_MUTE] = "mute",
				[KEY_PLAY] = "create_mix",
				[KEY_PRESET_1] = "set_preset_1",
				[KEY_PRESET_2] = "set_preset_2",
				[KEY_PRESET_3] = "set_preset_3",
				[KEY_PRESET_4] = "set_preset_4",
				[KEY_PRESET_5] = "set_preset_5",
				[KEY_PRESET_6] = "set_preset_6",
			},
		},
		irActionMappings = {
			press = {
				["add"]  = "add",
				["sleep"]  = "sleep",
			},
			hold = {
				["arrow_right"]  = "add",
				["play"]  = "create_mix",
				["pause"]  = "stop",
				["add"]  = "add_end",
				["sleep"]  = "sleep",
				["home"]   = "go_home",
				["0"]  = "disabled",
				["1"]  = "disabled",
				["2"]  = "disabled",
				["3"]  = "disabled",
				["4"]  = "disabled",
				["5"]  = "disabled",
				["6"]  = "disabled",
				["7"]  = "disabled",
				["8"]  = "disabled",
				["9"]  = "disabled",
			} 
		},

	}
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('shortcuts', 'advancedSettingsBetaFeatures', "SHORTCUTS_TITLE", function(applet, ...) applet:menu(...) end, 80))

	Framework:applyInputToActionOverrides(meta:getSettings())
	Framework._inputToActionOverrideDefaults = defaultSettings(self)
end



--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]
