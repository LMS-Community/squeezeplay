
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local string              = require("string")
local table               = require("jive.utils.table")
local io                  = require("io")
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

local EVENT_KEY_ALL    = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN   = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP     = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD   = jive.ui.EVENT_KEY_HOLD
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local KEY_FWD          = jive.ui.KEY_FWD
local KEY_REW          = jive.ui.KEY_REW
local KEY_HOME         = jive.ui.KEY_HOME
local KEY_PLAY         = jive.ui.KEY_PLAY
local KEY_ADD          = jive.ui.KEY_ADD
local KEY_BACK         = jive.ui.KEY_BACK
local KEY_PAUSE        = jive.ui.KEY_PAUSE
local KEY_VOLUME_DOWN  = jive.ui.KEY_VOLUME_DOWN
local KEY_VOLUME_UP    = jive.ui.KEY_VOLUME_UP
local KEY_GO           = jive.ui.KEY_GO
local WHEEL_CW         = jive.ui.KEY_DOWN
local WHEEL_CCW        = jive.ui.KEY_UP


local keyState = {}

local wheelState = 0

local keymap = {
	{ key = KEY_FWD,   name = "KEY_FWD",   x = 165, y = 260 },  
	{ key = KEY_REW,   name = "KEY_REW",   x =  68, y = 260 },
	{ key = KEY_HOME,  name = "KEY_HOME",  x = 173, y = 170 },
	{ key = KEY_PLAY,  name = "KEY_PLAY",  x = 173, y =  50 },
	{ key = KEY_ADD,   name = "KEY_ADD",   x =  56, y =  50 },
	{ key = KEY_BACK,  name = "KEY_BACK",  x =  56, y = 170 },
	{ key = KEY_PAUSE, name = "KEY_PAUSE", x = 115, y = 260 },
	{ key = KEY_VOLUME_DOWN, name = "KEY_VOLUME_DOWN", x =  92, y = 215 },
	{ key = KEY_VOLUME_UP,   name = "KEY_VOLUME_UP",   x = 140, y = 215 },
	{ key = KEY_GO,    name = "KEY_GO",    x = 115, y = 110 },
	{ key = WHEEL_CW,  name = "WHEEL_CW",  x = 160, y = 110 },
	{ key = WHEEL_CCW, name = "WHEEL_CCW", x =  75, y = 110 },
}


local stateToColor = {}
stateToColor[EVENT_KEY_UP]      = 0x00FF00FF
stateToColor[EVENT_KEY_DOWN]    = 0xFF0000FF
stateToColor[EVENT_KEY_PRESS]   = 0x0000FFFF
stateToColor[EVENT_KEY_HOLD]    = 0xFFFFFFFF



module(...)
oo.class(_M, Applet)


-- test if all buttons have been pressed and released
function _isCompleted(self, event)
	local completed = true
	for i,k in ipairs(keymap) do
		if keyState[k.key] ~= EVENT_KEY_UP then
			completed = false
			break
		end
	end

	return completed
end


function _completedShow(self)
	local popup = Window("window")
	popup:addWidget(Textarea("textarea", "Test Passed"))

	self:tieWindow(popup)
	popup:showBriefly(2000, function() self.window:hideToTop() end)
end


function drawKeypad(self)
	local w, h = Framework:getScreenSize()
	local srf  = Surface:newRGB(w, h)
	local currentKeyUp = 0

	self.background:blit(srf, 0, 0)
	self.icon:setValue(srf)

	for i,k in ipairs(keymap) do
		local state = keyState[k.key]
		if state ~= nil then
			srf:filledCircle(k.x, k.y, 10, stateToColor[state])
		else
			srf:circle(k.x, k.y, 10, 0x00FF00FF)
		end
	end

	return EVENT_CONSUME
end


function _scroll(self, dir)
	log:warn("dir=", dir, "wheelState=", wheelState)
	
	wheelState = wheelState + dir

	if wheelState > 0 then
		if keyState[WHEEL_CW] == EVENT_KEY_UP then
			wheelState = 0

		elseif wheelState >= 12 then
			keyState[WHEEL_CW] = EVENT_KEY_UP

		else
			keyState[WHEEL_CW] = EVENT_KEY_DOWN
		end
	end

	if wheelState < 0 then
		if keyState[WHEEL_CCW] == EVENT_KEY_UP then
			wheelState = 0

		elseif wheelState <= -12 then
			keyState[WHEEL_CCW] = EVENT_KEY_UP

		else
			keyState[WHEEL_CCW] = EVENT_KEY_DOWN
		end
	end
end


function KeypadTest(self)
	local window = Window("window")
	self.window = window

	self.background = Surface:loadImage("applets/TestKeypad/Keypad.png")

	self.icon = Icon("icon")
	window:addWidget(self.icon)
	window:addWidget(Textarea("help", self:string("TEST_KEYPAD_HELP")))

	self:drawKeypad()

	window:addListener(EVENT_KEY_ALL | EVENT_SCROLL,
		function(event)
			local eventtype = event:getType()

			if eventtype then
				if eventtype == EVENT_SCROLL then
					window:playSound("CLICK")
					self:_scroll(event:getScroll())

				elseif eventtype | EVENT_KEY_ALL then
					window:playSound("SELECT")

					-- update key state
					local keycode = event:getKeycode()

					for i,k in ipairs(keymap) do
						if keycode & k.key == k.key then

							if eventtype == EVENT_KEY_DOWN or keyState[k.key] ~= nil then
								keyState[k.key] = eventtype
							end
						end
					end
				end

				-- redraw keypad
				self:drawKeypad()

				-- is the test completed?
				if _isCompleted(self) then
					self:_completedShow()
				end

				return EVENT_CONSUME
			end
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
