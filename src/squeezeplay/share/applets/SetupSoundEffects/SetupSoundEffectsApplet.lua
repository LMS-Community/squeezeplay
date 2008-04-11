
--[[
=head1 NAME

applets.SetupSoundEffects.SetupSoundEffectsApplet - An applet to control Jive sound effects.

=head1 DESCRIPTION

This applets lets the user setup what sound effects are played.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SetupSoundEffectsApplet overrides the following methods:

=cut
--]]


-- stuff we use
local ipairs, pairs, tostring = ipairs, pairs, tostring

local table           = require("table")

local oo              = require("loop.simple")

local Applet          = require("jive.Applet")
local Audio           = require("jive.ui.Audio")
local Checkbox        = require("jive.ui.Checkbox")
local Framework       = require("jive.ui.Framework")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Icon            = require("jive.ui.Icon")
local Group           = require("jive.ui.Group")
local Slider          = require("jive.ui.Slider")
local Textarea        = require("jive.ui.Textarea")
local jul             = require("jive.utils.log")

local log             = jul.logger("applets.setup")

local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP
local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN


module(...)
oo.class(_M, Applet)


local effects = {
	SOUND_NAVIGATION = {
		"WINDOWSHOW",
		"WINDOWHIDE",
		"BUMP",
		"JUMP",
		"SELECT"
	},
	SOUND_SCROLL = {
		"CLICK"
	},
	SOUND_PLAYBACK = {
		"PLAYBACK"
	},
	SOUND_CHARGING = {
		"DOCKING"
	},
	SOUND_NONE = {
		"STARTUP",
		"SHUTDOWN"
	},
}


-- logSettings
-- returns a window with Choices to set the level of each log category
-- the log category are discovered
function settingsShow(self, menuItem)

	local settings = self:getSettings()

	local window = Window("window", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorWeightAlpha)

	local allButtons = {}

	-- off switch
	local offButton = Checkbox("checkbox", 
				   function(obj, isSelected)
					   local notSelected = not isSelected

					   for b,v in pairs(allButtons) do
						   b:setSelected(notSelected)
						   for i,snd in ipairs(v) do
							   settings[snd] = notSelected
							   Framework:enableSound(snd, notSelected)
						   end
					   end
				   end,
				   false
			   )

	menu:addItem({
			     text = self:string("SOUND_NONE"),
			     icon = offButton,
			     weight = 1
		     })


	-- add sounds
	local effectsEnabled = false
	for k,v in pairs(effects) do
		local soundEnabled = Framework:isSoundEnabled(v[1])
		effectsEnabled = effectsEnabled or soundEnabled

		local button = Checkbox(
			"checkbox", 
			function(obj, isSelected)
				for i,snd in ipairs(v) do
					settings[snd] = isSelected
					Framework:enableSound(snd, isSelected)
				end

				if isSelected then
					offButton:setSelected(false)
				end

				-- turn on off switch?
				local s = false
				for b,_ in pairs(allButtons) do
					s = s or b:isSelected()
				end
				
				if s == false then
					offButton:setSelected(true)
				end
			end,
			soundEnabled
			
		)

		allButtons[button] = v

		if k ~= "SOUND_NONE" then
			-- insert suitable entry for Choice menu
			menu:addItem({
					     text = self:string(k),
					     icon = button,
					     weight = 10
				     })
		end
	end

	offButton:setSelected(not effectsEnabled)

	-- volume
	menu:addItem({
			     text = self:string("SOUND_VOLUME"),
			     sound = "WINDOWSHOW",
			     weight = 20,
			     callback = function()
						self:volumeShow()
					end
		     })


	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


local VOLUME_STEPS = 20
local VOLUME_STEP = Audio.MAXVOLUME / VOLUME_STEPS


function _setVolume(self, value)
	local settings = self:getSettings()

	Audio:setEffectVolume(value * VOLUME_STEP)

	self.slider:setValue(value)
	self.slider:playSound("CLICK")

	settings["_VOLUME"] = value * VOLUME_STEP
end


function volumeShow(self)
	local window = Window("window", self:string("SOUND_EFFECTS_VOLUME"), "settingstitle")

	self.slider = Slider("volume", 0, VOLUME_STEPS, Audio:getEffectVolume() / VOLUME_STEP,
			     function(slider, value)
				     self:_setVolume(value)
			     end)

	self.slider:addListener(EVENT_KEY_PRESS,
				function(event)
					local code = event:getKeycode()
					if code == KEY_VOLUME_UP then
						self:_setVolume(self.slider:getValue() + 1)
						return EVENT_CONSUME
					elseif code == KEY_VOLUME_DOWN then
						self:_setVolume(self.slider:getValue() - 1)
						return EVENT_CONSUME
					end
					return EVENT_UNUSED
				end)

	window:addWidget(Textarea("help", self:string("SOUND_VOLUME_HELP")))
	window:addWidget(Group("volumeGroup", {
				     Icon("volumeMin"),
				     self.slider,
				     Icon("volumeMax")
			     }))

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

