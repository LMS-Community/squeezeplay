
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
local pairs, tostring = pairs, tostring

local table           = require("table")

local oo              = require("loop.simple")
local logging         = require("logging")

local Applet          = require("jive.Applet")
local Audio           = require("jive.ui.Audio")
local Checkbox        = require("jive.ui.Checkbox")
local Framework       = require("jive.ui.Framework")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local jul             = require("jive.utils.log")

local log             = jul.logger("applets.setup")


module(...)
oo.class(_M, Applet)


-- logSettings
-- returns a window with Choices to set the level of each log category
-- the log category are discovered
function open(self, menuItem)

	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorWeightAlpha)

	local allButtons = {}

	-- sometimes we need to disable the callback for the off switch
	-- otherwise it turns everything back on again
	local ignore = false

	-- off switch
	local offButton = Checkbox("checkbox", 
				   function(obj, isSelected)
					   Audio:effectsEnable(not isSelected)

					   if ignore then return end
					   for b,s in pairs(allButtons) do
						   s:enable(not isSelected)
						   b:setSelected(not isSelected)
					   end
				   end,
				   not Audio:isEffectsEnabled()
			   )

	menu:addItem({
			     text = self:string("SOUND_NONE"),
			     icon = offButton,
			     weight = 1
		     })

	-- add sounds
	for k,v in pairs(Framework:getSounds()) do
	
		local button = Checkbox(
			"checkbox", 
			function(obj, isSelected)
				v:enable(isSelected)

				if isSelected then
					ignore = true
					offButton:setSelected(false)
					ignore = false
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
			v:isEnabled()
		)

		allButtons[button] = v

		-- insert suitable entry for Choice menu
		menu:addItem({
				     text = self:string("SOUND_" .. k),
				     icon = button,
				     weight = 10
			     })
	end

	window:addWidget(menu)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

