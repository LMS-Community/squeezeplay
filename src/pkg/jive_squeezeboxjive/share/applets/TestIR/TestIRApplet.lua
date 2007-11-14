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

local log                    = require("jive.utils.log").logger("applets.misc")

local EVENT_SCROLL           = jive.ui.EVENT_SCROLL
local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local KEY_ADD                = jive.ui.KEY_ADD
local KEY_PLAY               = jive.ui.KEY_PLAY
local KEY_REW                = jive.ui.KEY_REW
local KEY_PAUSE              = jive.ui.KEY_PAUSE
local KEY_FWD                = jive.ui.KEY_FWD
local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP
local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN
local KEY_GO                 = jive.ui.KEY_GO
local KEY_BACK               = jive.ui.KEY_BACK

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

module(...)
oo.class(_M, Applet)


function drawKeypad(self)
	local w, h = Framework:getScreenSize()
	local srf  = Surface:newRGB(w, h)

	self.background:blit(srf, 0, 0)
	self.icon:setValue(srf)

	-- Remove last indicator	
	for i,k in ipairs(keymap) do
		if wheel_index_last == i then
			if k.dy == 0 then
				srf:circle(k.x, k.y, k.dx, 0x000000FF) 
			else
				srf:rectangle(k.x, k.y, k.dx, k.dy, 0x000000FF)
			end
		end
	end
	-- Add new indicator
	for i,k in ipairs(keymap) do
		if wheel_index == i then
			if k.dy == 0 then 
				srf:circle(k.x, k.y, k.dx, 0x00FF00FF)
			else
				srf:rectangle(k.x, k.y, k.dx, k.dy, 0x00FF00FF)
			end
		end
	end
end


function IRTest(self)
	local window = Window("window")
	self.window = window

	self.background = Surface:loadImage("applets/TestIR/TestIR.png")

	self.icon = Icon("icon")
	window:addWidget(self.icon)

	self:drawKeypad()

	window:addListener(EVENT_KEY_DOWN, 
		function(evt)
			keyEvent(self, evt)
		end
	)
	window:addListener(EVENT_SCROLL,
		function(evt)
			scrollEvent(self, evt)
			self:drawKeypad()
		end
	)

	self:tieAndShowWindow(window)
	return window
end


function keyEvent(self, evt)
	local key = evt:getKeycode()

	if key == KEY_BACK then
		window:playSound("SELECT")
		self.window:hide()
		return
	end

	window:playSound("CLICK")
	if key == KEY_GO then
		for i,k in ipairs(keymap) do
			if wheel_index == i then
				os.execute( bin_path .. " " .. k.ir)
			end
		end
	elseif key == KEY_ADD then
		os.execute( bin_path .. " 0x7689609F")
	elseif key == KEY_PLAY then
		os.execute( bin_path .. " 0x768910EF")
	elseif key == KEY_REW then
		os.execute( bin_path .. " 0x7689C03F")
	elseif key == KEY_PAUSE then
		os.execute( bin_path .. " 0x768920DF")
	elseif key == KEY_FWD then
		os.execute( bin_path .. " 0x7689A05F")
	elseif key == KEY_VOLUME_UP then
		os.execute( bin_path .. " 0x7689807F")
	elseif key == KEY_VOLUME_DOWN then
		os.execute( bin_path .. " 0x768900FF")
	else
end


function scrollEvent(self, evt)
	local scroll = evt:getScroll()
	
	wheel_index_last = wheel_index
	if scroll == 1 then
		wheel_index = wheel_index + 1
		if wheel_index > #keymap then
			wheel_index = 1
		end
	elseif scroll == -1 then
		wheel_index = wheel_index - 1
		if wheel_index < 1 then
			wheel_index = #keymap 
		end
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
