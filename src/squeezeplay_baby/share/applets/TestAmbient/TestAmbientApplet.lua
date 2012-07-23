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

local appletManager    		 = appletManager

local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local SYSPATH = '/sys/bus/i2c/devices/1-0010/ambient'

local ambientLight = {
	cur = -1,
	item = nil,
	text = "Ambient Light: ",
}

local mainMenu = nil

module(..., Framework.constants)
oo.class(_M, Applet)

function _updateLabel(self, channel, newValue)

	-- Make sure we have a number
	local number = tonumber(newValue)
log:warn(number)
	if(number == nil) then 
		return
	end
	channel.cur = newValue

	channel.item.text = channel.text .. channel.cur 
log:warn(channel.item.text)
	mainMenu:updatedItem(channel.item)
end

function _update(self)

	-- Get Ambient Light Reading
	local f = io.open(SYSPATH)
	local ambientLightVal = f:read("*all")
log:warn(ambientLightVal)
	f:close()

	self:_updateLabel(ambientLight, ambientLightVal)
end

function openWindow(self)
	local window = Window("text_list", 'FactoryTest: Ambient Light Sensor')


	mainMenu = SimpleMenu("menu")

	ambientLight.item = {
		text = 'Ambient Light',
		style = 'item_no_arrow',
	}
	mainMenu:addItem(ambientLight.item)

	window:addWidget(mainMenu)

	window:addAnimation(
		function()
                        self:_update()
                end,
		1
        )
	
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

