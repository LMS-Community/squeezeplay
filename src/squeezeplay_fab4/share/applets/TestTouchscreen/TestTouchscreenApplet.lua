
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local string              = require("string")
local table               = require("jive.utils.table")
local io                  = require("io")
local math                = require("math")
local oo                  = require("loop.simple")
local log                 = require("jive.utils.log").logger("applets.misc")
local debug               = require("jive.utils.debug")

local Label               = require("jive.ui.Label")
local Applet              = require("jive.Applet")
local Window              = require("jive.ui.Window")
local Surface             = require("jive.ui.Surface")
local Icon                = require("jive.ui.Icon")
local Framework           = require("jive.ui.Framework")
local Popup               = require("jive.ui.Popup")
local Textarea            = require("jive.ui.Textarea")


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	self.spot = {}
end


function _drawTarget(self, spot, offset, r, col)
	local x = spot.x + (offset * r)
	local y = spot.y

	-- target
	self.canvas:circle(x, y, r, col)
	self.canvas:hline(x - r, x + r, y, col)
	self.canvas:vline(x, y - r, y + r, col)
end


function _drawSpot(self, spot)
	if not spot.x then
		return
	end

	local r = 32
	local col = 0xffffffff

	if spot.width == nil then
		col = 0x6f6f6fff
	else
		-- width, pressure
		self.canvas:filledCircle(spot.x, spot.y, (r / 2) + (spot.width / 32) * r, ((spot.pressure << 8) | 0xFF))
	end

	if self.spot.fingers == 2 then
		self:_drawTarget(spot, -1, r, col)
		self:_drawTarget(spot, 1, r, col)
	else
		self:_drawTarget(spot, 0, r, col)
	end
end


function _drawSpots(self)
	-- clear
	self.background:blit(self.canvas, 0, 0)

	self:_drawSpot(self.spot)

	-- update screen
	self.icon:reDraw()
end


function touchscreenTest(self)
	self.window = Window("window_nolayout")

	self.w, self.h = Framework:getScreenSize()

	self.background = Surface:newRGB(self.w, self.h)
	self.background:filledRectangle(0, 0, self.w, self.h, 0x777777)

	self.canvas = Surface:newRGBA(self.w, self.h)
	self.icon = Icon("icon", self.canvas)	

	self.window:addWidget(self.icon)

	self:_drawSpots()

	self.window:addListener(EVENT_KEY_PRESS | EVENT_MOUSE_DRAG | EVENT_MOUSE_DOWN | EVENT_MOUSE_UP,
		function(event)
			local type = event:getType()

			if type == EVENT_KEY_PRESS then
				if event:getKeycode() == KEY_BACK then
					self.window:hide()
					return EVENT_CONSUME
				end
			elseif type == EVENT_MOUSE_UP then
				self.spot.width = nil

				self:_drawSpots()
				return EVENT_CONSUME

			else -- MOUSE_DRAG or MOUSE_DOWN
				self.spot.x, self.spot.y, self.spot.fingers, self.spot.width, self.spot.pressure = event:getMouse()

				self:_drawSpots()
				return EVENT_CONSUME
			end
		end
	)

	self:tieAndShowWindow(self.window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
