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
local Window                 = require("jive.ui.Window")
local Button                 = require("jive.ui.Button")
local Tile                   = require("jive.ui.Tile")

local LAYOUT_NONE            = jive.ui.LAYOUT_NONE
local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local BIG_FONT = Font:load("fonts/FreeSans.ttf", 24)
local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }

local SYSPATH = "/sys/bus/i2c/devices/0-0039/"

local tChannel0 = {
	min = -1,
	max = -1,
	cur = -1,
	label = nil,
	valid = false,
}

local tChannel1 = {
	min = -1,
	max = -1,
	cur = -1,
	label = nil,
	valid = false,
}
local tLux = {
	min = -1,
	max = -1,
	cur = -1,
	label = nil,
	valid = false,
}

-- Integration Stuff

local integrationButton = nil
local integrationLabel = nil

local IntegrationTimes = {
	"Integ: 13.7ms", "Integ: 100ms", "Integ: 402ms"
}
local curIntegrationTime = 2

-- Gain Stuff
local gainButton = nil
local gainLabel  = nil

local curGain = false

module(...)
oo.class(_M, Applet)

function _updateLabel(self, channel, newValue)

	-- Make sure we have a number
	local number = tonumber(newValue)
	if(number == nil) then 
		return
	end

	if channel.valid == false then
		channel.min = number
		channel.max = number
		channel.cur = number
		channel.valid = true
	else
		if( channel.min > number ) then
			channel.min = number
		end
		if( channel.max < number ) then
			channel.max = number
		end
		channel.cur = tonumber(newValue)
	end

	channel.label:setValue(channel.cur .. "(min:" .. channel.min .. " / max:" .. channel.max .. ")")
end

function _update(self)

	-- Open SysFS 
	local f = io.open(SYSPATH .. "adc")
	local adc = f:read("*all")
	f:close()

	f = io.open(SYSPATH .. "lux")
	local lux = f:read("*all");
	f:close()

	-- Parse ADC Values
	local s, e = string.find(adc, ",")
	local valueChannel0 = string.sub(adc, 0, s-1)
	local valueChannel1 = string.sub(adc, s+1, string.len(adc)-1) 

	-- Parse Lux
	local valueLux = string.sub(lux, 0, string.len(lux)-1)

	self:_updateLabel(tChannel0, valueChannel0)
	self:_updateLabel(tChannel1, valueChannel1)
	self:_updateLabel(tLux, valueLux)
end

function _changeIntegrationTime(self)

	curIntegrationTime = curIntegrationTime + 1
	if curIntegrationTime > 2 then
		curIntegrationTime = 0
	end

	integrationLabel:setValue(IntegrationTimes[curIntegrationTime+1])

	-- Send The Command
	local f = io.open(SYSPATH .. "integration", "w")
	f:write(tostring(curIntegrationTime))
	f:close()

end

function _changeGain(self)

	local f = io.open(SYSPATH .. "gain", "w")

	if curGain == true then
		curGain = false
		f:write("0")

		gainLabel:setValue("Gain: Off")
	else
		curGain = true
		f:write("1")

		gainLabel:setValue("Gain: On")
	end

	f:close()


end

function openWindow(self)
	local window = Window("ambientWindow", 'FactoryTest: Ambient Light Sensor')

	local imgpath = "applets/Fab4Skin/images/"

        window:setSkin({
		ambientWindow = {
	                Channel0Text = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 10,
				y = 100
	        	},
	                Channel1Text = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 10,
				y = 130
	        	},
	                LuxText = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 10,
				y = 160
	        	},
	                Channel0Value = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 200,
				y = 100
			},
	                Channel1Value = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 200,
				y = 130
			},
	                LuxValue = {
				fg = TEXT_COLOR,
				position = LAYOUT_NONE,
				font = BIG_FONT,
				x = 200,
				y = 160
			},
		}
        })

	log:warn("WTF")

	local c0text = Label("Channel0Text", "Channel0:")
	window:addWidget(c0text)
	
	local c1text = Label("Channel1Text", "Channel1:")
	window:addWidget(c1text)

	local luxtext = Label("LuxText", "Lux:")
	window:addWidget(luxtext)

	tChannel0.label = Label("Channel0Value", "n/a")
	tChannel1.label = Label("Channel1Value", "n/a")
	tLux.label      = Label("LuxValue", "n/a")

	integrationLabel = Label('softButton1', 'Integ: 402ms')
	integrationButton = Button(integrationLabel, function() self:_changeIntegrationTime() end )	

	gainLabel = Label('softButton2', 'Gain: Off')
	gainButton = Button(gainLabel, function() self:_changeGain() end )

	window:addWidget(tChannel0.label)
	window:addWidget(tChannel1.label)
	window:addWidget(tLux.label)
	window:addWidget(integrationButton)
	window:addWidget(gainButton)

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

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

