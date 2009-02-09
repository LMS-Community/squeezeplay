
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
local lfs              = require("lfs")

local Applet           = require("jive.Applet")
local System           = require("jive.System")
local Framework        = require("jive.ui.Framework")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
local log              = require("jive.utils.log").logger("applets.misc")


local JIVE_LAYER_ALL   = jive.ui.JIVE_LAYER_ALL


module(..., Framework.constants)
oo.class(_M, Applet)


local function _takeScreenshotAction(self)
	Framework:playSound("CLICK")

	-- write to /media/*/log/squeezeplayXXXX.bmp or userpath
	local path = System.getUserDir()
	if lfs.attributes("/media", "mode") ~= nil then
		for dir in lfs.dir("/media") do
			local tmp = "/media/" .. dir 
			if lfs.attributes(tmp, "mode") == "directory" then
				path = tmp
				break
			end
		end
	end

	local file = path .. string.format("/squeezeplay%04d.bmp", self.number)
	self.number = self.number + 1
	
	log:warn("Taking screenshot " .. file)

	-- take screenshot
	local sw, sh = Framework:getScreenSize()

	local window = Framework.windowStack[1]
	local bg = Framework.getBackground()

	local srf = Surface:newRGB(sw, sh)
	bg:blit(srf, 0, 0, sw, sh)
	window:draw(srf, JIVE_LAYER_ALL)

	srf:saveBMP(file)

	return EVENT_CONSUME
end


function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))
	obj.number = 1
	
	Framework:addActionListener("take_screenshot", obj, _takeScreenshotAction)
	
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

