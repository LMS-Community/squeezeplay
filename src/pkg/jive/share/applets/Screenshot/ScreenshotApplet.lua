
--[[
=head1 NAME

applets.Screenshot.ScreenshotApplet - Screenshot, press and hole Pause and Rew to take a screenshot.

=head1 DESCRIPTION

This applet saves screenshots as bmp files using a key combination to lock the Jive screen.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
ScreenshotApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo               = require("loop.simple")
local string           = require("string")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")

local log              = require("jive.utils.log").logger("applets")


local EVENT_KEY_HOLD   = jive.ui.EVENT_KEY_HOLD
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local KEY_REW          = jive.ui.KEY_REW
local KEY_PAUSE        = jive.ui.KEY_PAUSE
local JIVE_LAYER_ALL   = jive.ui.JIVE_LAYER_ALL


module(...)
oo.class(_M, Applet)


local function _keyHold(self, event)
	if event:getKeycode() == (KEY_REW | KEY_PAUSE) then

		local file = string.format("jive%04d.bmp", self.number)
		self.number = self.number + 1

		log:warn("Taking screenshot " .. file)

		-- take screenshot
		local sw, sh = Framework:getScreenSize()

		local window = Framework.windowStack[1]
		local bg = Framework.getBackground()

		local srf = Surface:newRGB(sw, sh)
		bg:blit(srf, 0, 0)
		window:draw(srf, JIVE_LAYER_ALL)

		srf:saveBMP(file)

		return EVENT_CONSUME
	end

	return EVENT_UNUSED
end


function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))
	obj.number = 1
	
	Framework:addListener(EVENT_KEY_HOLD,
		function(...)
			return _keyHold(obj, ...)
		end
	)
	
	return obj
end


--[[

=head2 applets.Screenshot.ScreenshotApplet:free()

Overridden to return always false, this ensure the applet is
permanently loaded.

=cut
--]]
function free(self)
	-- we cannot be unloaded
	return false
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

