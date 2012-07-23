
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local string              = require("string")
local table               = require("jive.utils.table")
local io                  = require("io")
local oo                  = require("loop.simple")
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


local keyState = {}

local wheelState = 0

local keymap = {
	{ key = KEY_HOME, name = "KEY_HOME", x = 40, y = 27 },
	{ key = KEY_ALARM, name = "KEY_ALARM", x = 85, y = 27 },
	{ key = KEY_ADD, name = "KEY_ADD", x = 129, y = 27 },

	{ key = KEY_REW, name = "KEY_REW", x =  194, y = 27 },
	{ key = KEY_PAUSE, name = "KEY_PAUSE", x = 236, y = 27 },
	{ key = KEY_FWD, name = "KEY_FWD", x = 278, y = 27 },

	{ key = KEY_BACK, name = "KEY_BACK", x = 61, y = 86 },
	{ key = KEY_PLAY, name = "KEY_PLAY", x = 259, y = 86 },

	{ key = KEY_DOWN, name = "KEY_DOWN", x = 115, y = 120 },
	{ key = KEY_GO, name = "KEY_GO", x = 161, y = 120 },
	{ key = KEY_UP, name = "KEY_UP", x = 207, y = 120 },

	{ key = KEY_VOLUME_DOWN, name = "KEY_VOLUME_DOWN", x = 40, y = 182 },
	{ key = KEY_MUTE, name = "KEY_MUTE", x = 60, y = 182 },
	{ key = KEY_VOLUME_UP, name = "KEY_VOLUME_UP", x = 80, y = 182 },

	{ key = KEY_POWER, name = "KEY_POWER", x = 258, y = 187 },

	{ key = KEY_PRESET_1, name = "KEY_PRESET_1", x = 11, y = 66 },
	{ key = KEY_PRESET_2, name = "KEY_PRESET_2", x = 11, y = 111 },
	{ key = KEY_PRESET_3, name = "KEY_PRESET_3", x = 11, y = 157 },

	{ key = KEY_PRESET_4, name = "KEY_PRESET_4", x = 308, y =  66 },
	{ key = KEY_PRESET_5, name = "KEY_PRESET_5", x = 308, y =  111 },
	{ key = KEY_PRESET_6, name = "KEY_PRESET_6", x = 308, y =  157 },
}

local stateToColor = {}
stateToColor[EVENT_KEY_UP]      = 0x00FF00FF
stateToColor[EVENT_KEY_DOWN]    = 0xFF0000FF
stateToColor[EVENT_KEY_PRESS]   = 0x0000FFFF
stateToColor[EVENT_KEY_HOLD]    = 0xFFFFFFFF


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
	popup:addWidget(Textarea("textarea", self:string("TEST_COMPLETE")))

	self:tieWindow(popup)
	popup:showBriefly(2000, function() self.window:hideToTop() end)
end


function drawKeypad(self)
	local currentKeyUp = 0

	self.background:blit(self.surface, 0, 0)

	local started = false

	for i,k in ipairs(keymap) do
		local state = keyState[k.key]
		if state ~= nil then
			started = true
			self.surface:filledCircle(k.x, k.y, 10, stateToColor[state])
		else
			self.surface:circle(k.x, k.y, 10, 0x00FF00FF)
		end
	end

	if started then
		self.window:removeWidget(self.help)
	end

	return EVENT_CONSUME
end


function _scroll(self, dir)
	wheelState = wheelState + dir

	if wheelState > 0 then
		if keyState[KEY_UP] == EVENT_KEY_UP then
			wheelState = 0

		elseif wheelState >= 12 then
			keyState[KEY_UP] = EVENT_KEY_UP

		else
			keyState[KEY_UP] = EVENT_KEY_DOWN
		end
	end

	if wheelState < 0 then
		if keyState[KEY_DOWN] == EVENT_KEY_UP then
			wheelState = 0

		elseif wheelState <= -12 then
			keyState[KEY_DOWN] = EVENT_KEY_UP

		else
			keyState[KEY_DOWN] = EVENT_KEY_DOWN
		end
	end
end


function KeypadTest(self)
	local window = Window("window")
	window:setShowFrameworkWidgets(false)

	self.window = window

	self.background = Surface:loadImage("applets/TestKeypad/Keypad.png")
	local w, h = self.background:getSize()

	self.surface = Surface:newRGB(w, h)

	self.icon = Icon("icon", self.surface)
	window:addWidget(self.icon)

	self.help = Textarea("help", self:string("TEST_KEYPAD_HELP"))
	window:addWidget(self.help)

	self:drawKeypad()

	self.window:focusWidget(nil)
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
							keyState[k.key] = eventtype
						end
					end
				end

				-- special handling for volume knob
				if keyState[KEY_VOLUME_UP] ~= nil then
					keyState[KEY_VOLUME_UP] = EVENT_KEY_UP
				end
				if keyState[KEY_VOLUME_DOWN] ~= nil then
					keyState[KEY_VOLUME_DOWN] = EVENT_KEY_UP
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

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
