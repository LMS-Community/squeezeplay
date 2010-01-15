local ipairs = ipairs

-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")
local Surface                = require("jive.ui.Surface")
local Framework              = require("jive.ui.Framework")

local bin_path	= "/usr/bin/testir"

local wheel_index_last = 1
local wheel_index = 1

local keymap = {
	{ key=KEY_SLEEP,      x=29,  y=34,  dx=18,  dy=0,   ir="0x7689b847" },
	{ key=KEY_POWER,      x=207, y=27,  dx=22,  dy=0,   ir="0x768940BF" },
	{ key=KEY_UP,         x=119, y=34,  dx=18,  dy=0,   ir="0x7689e01f" },
	{ key=KEY_LEFT,       x=84,  y=60,  dx=18,  dy=0,   ir="0x7689906f" },
	{ key=KEY_RIGHT,      x=156, y=60,  dx=18,  dy=0,   ir="0x7689d02f" },
	{ key=KEY_DOWN,       x=119, y=85,  dx=18,  dy=0,   ir="0x7689b04f" },
	{ key=KEY_1,          x=30,  y=136, dx=18,  dy=0,   ir="0x7689f00f" },
	{ key=KEY_2,          x=76,  y=136, dx=18,  dy=0,   ir="0x768908f7" },
	{ key=KEY_3,          x=120, y=136, dx=18,  dy=0,   ir="0x76898877" },
	{ key=KEY_4,          x=167, y=136, dx=18,  dy=0,   ir="0x768948b7" },
	{ key=KEY_5,          x=214, y=136, dx=18,  dy=0,   ir="0x7689c837" },
	{ key=KEY_6,          x=30,  y=191, dx=18,  dy=0,   ir="0x768928d7" },
	{ key=KEY_7,          x=74,  y=191, dx=18,  dy=0,   ir="0x7689a857" },
	{ key=KEY_8,          x=120, y=191, dx=18,  dy=0,   ir="0x76896897" },
	{ key=KEY_9,          x=164, y=191, dx=18,  dy=0,   ir="0x7689e817" },
	{ key=KEY_0,          x=212, y=191, dx=18,  dy=0,   ir="0x76899867" },
	{ key=KEY_SEARCH,     x=18,  y=231, dx=53,  dy=255, ir="0x768958a7" },
	{ key=KEY_BROWSE,     x=73,  y=231, dx=109, dy=255, ir="0x7689708f" },
	{ key=KEY_SHUFFLE,    x=127, y=231, dx=165, dy=255, ir="0x7689d827" },
	{ key=KEY_REPEAT,     x=187, y=231, dx=223, dy=255, ir="0x768938c7" },
	{ key=KEY_FAVORITES,  x=20,  y=289, dx=55,  dy=314, ir="0x768918e7" },
	{ key=KEY_NOWPLAYING, x=73,  y=289, dx=109, dy=314, ir="0x76897887" },
	{ key=KEY_SIZE,       x=131, y=289, dx=170, dy=314, ir="0x7689f807" },
	{ key=KEY_BRIGHTNESS, x=185, y=289, dx=222, dy=314, ir="0x768904fb" },
}

module(..., Framework.constants)
oo.class(_M, Applet)


function drawKeypad(self)
	self.background:blit(self.srf, 0, 0)
	self.icon:setValue(self.srf)

	-- Remove last indicator	
	for i,k in ipairs(keymap) do
		if wheel_index_last == i then
			if k.dy == 0 then
				self.srf:circle(k.x, k.y, k.dx, 0x000000FF) 
			else
				self.srf:rectangle(k.x, k.y, k.dx, k.dy, 0x000000FF)
			end
		end
	end
	-- Add new indicator
	for i,k in ipairs(keymap) do
		if wheel_index == i then
			if k.dy == 0 then 
				self.srf:circle(k.x, k.y, k.dx, 0x00FF00FF)
			else
				self.srf:rectangle(k.x, k.y, k.dx, k.dy, 0x00FF00FF)
			end
		end
	end
end


function IRTest(self)
	local w, h = Framework:getScreenSize()
	local window = Window("text_list")
	self.window = window

	self.srf  = Surface:newRGB(w, h)

	self.background = Surface:loadImage("applets/TestIR/TestIR.png")

	self.icon = Icon("icon")
	window:addWidget(self.icon)

	window:setShowFrameworkWidgets(false)

	self:drawKeypad()

	window:addListener(EVENT_KEY_PRESS, 
		function(evt)
			if evt:getKeycode() == KEY_BACK then
				window:playSound("WINDOWHIDE")
				self.window:hide()
				return EVENT_CONSUME
			end
			return EVENT_UNUSED
		end
	)
	window:addListener(EVENT_KEY_DOWN, 
		function(evt)
			return keyEvent(self, evt, window)
		end
	)
	window:addListener(EVENT_SCROLL,
		function(evt)
			scrollEvent(self, evt, window)
			self:drawKeypad()
			return EVENT_CONSUME
		end
	)

	self:tieAndShowWindow(window)
	return window
end


function keyEvent(self, evt, window)
	local key = evt:getKeycode()

	local code = false

	if key == KEY_GO then
		for i,k in ipairs(keymap) do
			if wheel_index == i then
				code = k.ir
			end
		end
	elseif key == KEY_ADD then
		code = "0x7689609F"
	elseif key == KEY_PLAY then
		code = "0x768910EF"
	elseif key == KEY_REW then
		code = "0x7689C03F"
	elseif key == KEY_PAUSE then
		code = "0x768920DF"
	elseif key == KEY_FWD then
		code = "0x7689A05F"
	elseif key == KEY_VOLUME_UP then
		code = "0x7689807F"
	elseif key == KEY_VOLUME_DOWN then
		code = "0x768900FF"
	end

	if code then
		self.window:playSound("CLICK")

		os.execute( bin_path .. " " .. code)
		return EVENT_CONSUME
	else
		return EVENT_UNUSED
	end
end


function scrollEvent(self, evt, window)
	local scroll = evt:getScroll()
	
	wheel_index_last = wheel_index
	if scroll >= 1 then
		window:playSound("CLICK")

		wheel_index = wheel_index + 1
		if wheel_index > #keymap then
			wheel_index = 1
		end
	elseif scroll <= -1 then
		window:playSound("CLICK")

		wheel_index = wheel_index - 1
		if wheel_index < 1 then
			wheel_index = #keymap 
		end
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
