
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
	local popup = Window("window")
	local text = Textarea("textarea", text)
	popup:addWidget(text)
	self:tieWindow(popup)

	popup:showBriefly(2000, function() self.window:hideToTop() end)

	return popup
end

function drawDisplay(self)
	local y
	local w, h = Framework:getScreenSize()
	local srf  = Surface:newRGBA(w, h)

	srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)


	if self.state == 1 then
		log:info("DisplayTest: White Frame")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)
		srf:line(   4,   4, 236,   4, 0xFFFFFFFF)
		srf:line( 236,   4, 236, 316, 0xFFFFFFFF)
		srf:line( 236, 316,   4, 316, 0xFFFFFFFF)
		srf:line(   4, 316,   4,   4, 0xFFFFFFFF)

	elseif self.state == 2 then
		log:info("DisplayTest: RED")
		srf:filledRectangle(0, 0, w, h, 0xFF0000FF)

	elseif self.state == 3 then
		log:info("DisplayTest: Gradiant RED")

		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = (shade << 24) | 0xFF
			srf:line( 0, y, 240, y, color)
		end
		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = 0xFF000000 | (shade << 16) | (shade << 8) | 0xFF
			srf:line( 0, y+160, 240, y+160, color)
		end

	elseif self.state == 4 then
		log:info("DisplayTest: GREEN")
		srf:filledRectangle(0, 0, w, h, 0x00FF00FF)

	elseif self.state == 5 then
		log:info("DisplayTest: Gradiant GREEN")

		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = (shade << 16) | 0xFF
			srf:line( 0, y, 240, y, color)
		end
		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = (shade << 24) | 0xFF0000 | (shade << 8) | 0xFF
			srf:line( 0, y+160, 240, y+160, color)
		end
	
	elseif self.state == 6 then
		log:info("DisplayTest: BLUE")
		srf:filledRectangle(0, 0, w, h, 0x0000FFFF)
	
	elseif self.state == 7 then
		log:info("DisplayTest: Gradiant BLUE")
		srf:filledRectangle(0, 0, w, h, 0x0000FFFF)

		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = (shade << 8) | 0xFF
			srf:line( 0, y, 240, y, color)
		end
		for y = 0, 160, 1 do
			local shade = (y * 0xFF / 160)
			shade = shade - (shade%1)
			local color = (shade << 24) | (shade << 16) | 0xFFFF
			srf:line( 0, y+160, 240, y+160, color)
		end

	elseif self.state == 8 then
		log:info("DisplayTest: WHITE")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)

	elseif self.state == 9 then
		log:info("DisplayTest: Gradiant WHITE")

		for y = 0, 320, 1 do
			local shade = (y * 0xFF / 320)
			shade = shade - (shade%1)
			local color = (shade << 24) | (shade << 16) | (shade << 8) | 0xFF
			srf:line( 0, y, 240, y, color)
		end

	elseif self.state == 10 then
		log:info("DisplayTest: BLACK")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)

	elseif self.state == 11 then
		log:info("DisplayTest: HORZ_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for y = 0, h, 2 do
			srf:line(0, y, w, y, 0x000000FF)
		end

	elseif self.state == 12 then
		log:info("DisplayTest: VERT_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for x = 0, w, 2 do
			srf:line(x ,0, x, h, 0x000000FF)
		end

	else
		log:info("DisplayTest: TEST_COMPLETE")
		self:popupWindow(self:string("TEST_COMPLETE"))
	end
	
	self.state = self.state + 1
	self.icon:setValue(srf)
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
				window:playSound("WINDOWHIDE")
				window:hide()
				return EVENT_CONSUME

			elseif key == KEY_GO then
				window:playSound("WINDOWSHOW")
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
