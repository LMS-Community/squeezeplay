
local ipairs, tostring    = ipairs, tostring

local oo                  = require("loop.simple")

local Applet              = require("jive.Applet")
local Window              = require("jive.ui.Window")
local Surface             = require("jive.ui.Surface")
local Icon                = require("jive.ui.Icon")
local Framework           = require("jive.ui.Framework")
local Popup               = require("jive.ui.Popup")
local Textarea            = require("jive.ui.Textarea")
local Font                = require("jive.ui.Font")
local Timer               = require("jive.ui.Timer")
local math                = require("math")


module(..., Framework.constants)
oo.class(_M, Applet)


function popupWindow(self, text)
	local popup = Window("text_list")
	local text = Textarea("text", text)
	popup:addWidget(text)
	self:tieWindow(popup)

	popup:showBriefly(2000, function() self.window:hideToTop() end)

	return popup
end

function drawDisplay(self)
	local w, h = Framework:getScreenSize()
	local srf  = Surface:newRGBA(w, h)

	srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)

	if self.state == 1 then
		log:info("DisplayTest: White Frame")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)
		srf:line(   0,   0, w-1,   0, 0xFFFFFFFF)
		srf:line( w-1,   0, w-1, h-1, 0xFFFFFFFF)
		srf:line( w-1, h-1,   0, h-1, 0xFFFFFFFF)
		srf:line(   0, h-1,   0,   0, 0xFFFFFFFF)

	elseif self.state == 2 then
		log:info("DisplayTest: RED")
		srf:filledRectangle(0, 0, w, h, 0xFF0000FF)

	elseif self.state == 3 then
		log:info("DisplayTest: GREEN")
		srf:filledRectangle(0, 0, w, h, 0x00FF00FF)

	elseif self.state == 4 then
		log:info("DisplayTest: BLUE")
		srf:filledRectangle(0, 0, w, h, 0x0000FFFF)

	elseif self.state == 5 then
		log:info("DisplayTest: WHITE")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)

	elseif self.state == 6 then
		log:info("DisplayTest: HORZ_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for y = 0, h, 2 do
			srf:line(0, y, w, y, 0x000000FF)
		end
		
	elseif self.state == 7 then
		log:info("DisplayTest: VERT_STRIPES")
		srf:filledRectangle(0, 0, w, h, 0xFFFFFFFF)
		for x = 0, w, 2 do
			srf:line(x ,0, x, h, 0x000000FF)
		end

	elseif self.state == 8 then
		log:info("DisplayTest: BLACK")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)

	elseif self.state == 9 then
		log:info("DisplayTest: COLOR_GRADIENT")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)
		srf = Surface:loadImage("applets/TestDisplay/ColorWheel.jpg")
		local wi,hi = srf:getSize()
		srf = srf:zoom( w / wi, h / hi, 1)

	elseif self.state == 10 then
		log:info("DisplayTest: COLOR_GRADIENT")
		srf:filledRectangle(0, 0, w, h, 0x000000FF)
		srf = Surface:loadImage("applets/TestDisplay/Face.jpg")
		local wi,hi = srf:getSize()
		srf = srf:zoom( w / wi, h / hi, 1)
		
	else
		log:info("DisplayTest: TEST_COMPLETE")
		self:popupWindow(self:string("TEST_COMPLETE"))
	end
	
	self.state = self.state + 1
	self.icon:setValue(srf)
end

function DisplayTest(self)

	local window = Window("text_list")
	window:setShowFrameworkWidgets(false)

	self.window = window

	self.icon = Icon("icon")
	window:addWidget(self.icon)

	self.state = 1
	self:drawDisplay()
	
	local _drawDisplayAction = function (self)
		window:playSound("WINDOWSHOW")
		self:drawDisplay()
		return EVENT_CONSUME
	end

	window:addActionListener("go", self, _drawDisplayAction)

	window:addListener(EVENT_KEY_PRESS | EVENT_MOUSE_DOWN,
		function(event)
			local type = event:getType()

			if type == EVENT_KEY_PRESS then
				if event:getKeycode() == KEY_BACK then
					window:playSound("WINDOWHIDE")
					window:hide()
					return EVENT_CONSUME
				end

			elseif type == EVENT_MOUSE_DOWN then
				window:playSound("WINDOWSHOW")
				self:drawDisplay()
				return EVENT_CONSUME
			end
		end

	)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
