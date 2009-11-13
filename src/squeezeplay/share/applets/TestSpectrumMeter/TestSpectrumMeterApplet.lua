
local ipairs, tostring = ipairs, tostring

local oo		= require("loop.simple")

local Applet		= require("jive.Applet")
local Window		= require("jive.ui.Window")
local Framework		= require("jive.ui.Framework")

local SpectrumMeter	= require("jive.audio.SpectrumMeter")


module(..., Framework.constants)
oo.class(_M, Applet)


function SpectrumMeterTest(self)
	local window = Window("text_list")

	self.window = window

	window:setAllowScreensaver(false)

	self.icon = SpectrumMeter("spectrum")
	window:addWidget(self.icon)

	self.icon:addListener(EVENT_MOUSE_DOWN,
		function(event)
			window:playSound("WINDOWHIDE")
			window:hide()
			return EVENT_CONSUME
		end
	)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
