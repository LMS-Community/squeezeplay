local ipairs, tostring, tonumber = ipairs, tostring, tonumber

local io                     = require("io")
local oo                     = require("loop.simple")
local string                 = require("string")
local table                  = require("jive.utils.table")
local math		     = require("math")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Font                   = require("jive.ui.Font")
local Label                  = require("jive.ui.Label")
local Menu                   = require("jive.ui.Menu")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Choice                 = require("jive.ui.Choice")
local Window                 = require("jive.ui.Window")
local Button                 = require("jive.ui.Button")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local Tile                   = require("jive.ui.Tile")
local Icon                   = require("jive.ui.Icon")

local appletManager    		 = appletManager

local LAYOUT_NONE            = jive.ui.LAYOUT_NONE
local FRAME_RATE             = jive.ui.FRAME_RATE


module(...)
oo.class(_M, Applet)


function openWindow(self)
	local window = Window("text_list", "Screen Flicker Test")

	window:setSkin({
		footext = {
			font = Font:load("fonts/FreeSans.ttf", 50),
			fg = { 0xE7, 0xE7, 0xE7 },
			padding = 10,
		},
	})

	self.value = 0
	self.ticker = Label("footext", self.value)

	self.icon = Icon("icon_connecting")

	window:addWidget(self.ticker)
	window:addWidget(self.icon)

	window:addAnimation(function()
		self.value = self.value + 1
		self.ticker:setValue(tostring(self.value))
        end, FRAME_RATE/2)
	
	window:setAllowScreensaver(false)

        self:tieAndShowWindow(window)
        return window
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

