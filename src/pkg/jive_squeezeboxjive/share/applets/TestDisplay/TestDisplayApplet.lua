
local ipairs, tostring    = ipairs, tostring

local oo                  = require("loop.simple")
local log                 = require("jive.utils.log").logger("applets.misc")

local Applet              = require("jive.Applet")
local Window              = require("jive.ui.Window")
local Surface             = require("jive.ui.Surface")
local Icon                = require("jive.ui.Icon")
local Framework           = require("jive.ui.Framework")
local Popup               = require("jive.ui.Popup")
local Textarea            = require("jive.ui.Textarea")
local Font                = require("jive.ui.Font")

local EVENT_KEY_PRESS     = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME       = jive.ui.EVENT_CONSUME

local KEY_GO              = jive.ui.KEY_GO
local KEY_BACK            = jive.ui.KEY_BACK


module(...)
oo.class(_M, Applet)


function popupWindow(self, text)
	local popup = Popup("popup")
	local text = Textarea("textarea", text)
	popup:addWidget(text)
	self:tieWindow(popup)

	popup:showBriefly(2000, function() self.window:hideToTop() end)

	return popup
end


function drawDisplay(self)
	local w, h = Framework:getScreenSize()
	local srf  = Surface:newRGBA(w, h)

	log:warn("state is ", self.state)
	srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)

	if self.state == 1 then
		log:warn("DisplayTest: RED")
		srf:filledRectangle(0, 0, w, h, 0xFF0000FF)

	elseif self.state == 2 then
		log:warn("DisplayTest: GREEN")
		srf:filledRectangle(0, 0, w, h, 0x00FF00FF)

	elseif self.state == 3 then
		log:warn("DisplayTest: BLUE")
		srf:filledRectangle(0, 0, w, h, 0x0000FFFF)

	elseif self.state == 4 then
		log:warn("DisplayTest: WHITE")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)

	elseif self.state == 5 then
		log:warn("DisplayTest: BLACK")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)

	elseif self.state == 6 then
		log:warn("DisplayTest: HORZ_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for y = 0, h, 2 do
			srf:line(0, y, w, y, 0x000000FF)
		end

	elseif self.state == 7 then
		log:warn("DisplayTest: VERT_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for x = 0, w, 2 do
			srf:line(x ,0, x, h, 0x000000FF)
		end

	else
		log:warn("DisplayTest: TEST_COMPLETE")
		self:popupWindow(self:string("TEST_COMPLETE"))
	end
	
	self.state = self.state + 1
	self.icon:setImage(srf)
end


function DisplayTest(self)
	local window = Window("window")
	self.window = window

	self.icon = Icon("icon")
	window:addWidget(self.icon)

	self.state = 1
	self:drawDisplay()
	
	-- any button to exit
	window:addListener(
		EVENT_KEY_PRESS,
		function(event)
		    local key = event:getKeycode()

			log:warn("DisplayTest: key: ".. key)

			if key == KEY_BACK then
				window:hide()
				return EVENT_CONSUME

			elseif key == KEY_GO then
				self:drawDisplay()
				return EVENT_CONSUME

			end
			return EVENT_UNUSED
		end
	)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
