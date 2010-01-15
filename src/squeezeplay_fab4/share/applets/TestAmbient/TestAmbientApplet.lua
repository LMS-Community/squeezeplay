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

local SYSPATH = "/sys/bus/i2c/devices/0-0039/"

local tChannel0 = {
	min = -1,
	max = -1,
	cur = -1,
	item = nil,
	valid = false,
	text = "Channel 0: ",
}

local tChannel1 = {
	min = -1,
	max = -1,
	cur = -1,
	item = nil,
	valid = false,
	text = "Channel 1: ",
}
local tLux = {
	min = -1,
	max = -1,
	cur = -1,
	item = nil,
	valid = false,
	text = "Lux: ",
}

local tBright = {
	min = -1,
	max = -1,
	cur = -1,
	item = nil,
	valid = false,
	text = "Brightness: ",
}

local mainMenu = nil

-- Integration Stuff
local IntegrationTimes = {
	"13.7ms", "100ms", "402ms"
}

local integrationItem = nil
local curIntegrationTime = 2

-- Gain Stuff
local gainItem  = nil
local curGain = false

-- Factor Stuff
local factorItem = nil
local curFactor = 1

module(..., Framework.constants)
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

	channel.item.text = channel.text .. channel.cur .. "(min:" .. channel.min .. " / max:" .. channel.max .. ")"
	mainMenu:updatedItem(channel.item)
end

function _getBrightness(self)
        -- store existing brightness levels in self
        return appletManager:callService("getBrightness")
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
	
	-- 
	local brightness = self:_getBrightness()

	self:_updateLabel(tChannel0, valueChannel0)
	self:_updateLabel(tChannel1, valueChannel1)
	self:_updateLabel(tLux, valueLux)
	self:_updateLabel(tBright, brightness)
end

function _changeIntegrationTime(self, newValue)

	curIntegrationTime = newValue	

	-- Send The Command
	local f = io.open(SYSPATH .. "integration", "w")
	f:write(tostring(curIntegrationTime))
	f:close()

	-- Update Main Menu Entry
	if integrationItem != nil then
		integrationItem.text = "Change Integration Time (" .. IntegrationTimes[curIntegrationTime+1] .. ")"
	end
end

function _changeGain(self, newValue)

	local f = io.open(SYSPATH .. "gain", "w")
	local text = nil

	curGain = newValue;

	if curGain == true then
		f:write("1")
		text = "Change Gain (Currently On)"
	else
		f:write("0")
		text = "Change Gain (Currently Off)"
	end

	f:close()

	-- Update Main Menu Entry
	if gainItem != nil then 
		gainItem.text = text
	end
end

function _changeFactor(self, newValue) 

	curFactor = newValue;

	local f = io.open(SYSPATH .. "factor", "w")
	f:write(tostring(curFactor))
	f:close()

	if factorItem != nil then
		factorItem.text = "Change Factor (" .. tostring(curFactor) .. ")"
	end
end

function menuSetGain(self)
	local window = Window("text_list", "Set Gain...")
	local group = RadioGroup()

        local menu = SimpleMenu("menu", {          
                {                                  
                        text = "Gain On",
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeGain(true)              
                                end,                                                
                        curGain == true)
                },                                                                  
                {                                          
                        text = "Gain Off",
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
                                        self:_changeGain(false)                      
                                end,                                                
                        curGain == false)
                },                                                                  
        }) 

	window:addWidget(menu)
        self:tieAndShowWindow(window)
end

function menuSetIntegration(self)
	local window = Window("text_list", "Change Integration Time...")
	local group = RadioGroup()

        local menu = SimpleMenu("menu", {          
                {
                        text = "Integration Time: " .. IntegrationTimes[1],
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeIntegrationTime(0)
                                end,                                                
                        curIntegrationTime == 0)
                },                                                             
                {
                        text = "Integration Time: " .. IntegrationTimes[2],
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeIntegrationTime(1)					          
                                end,                                                
                        curIntegrationTime == 1)
                },
		{
                        text = "Integration Time: " .. IntegrationTimes[3],
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeIntegrationTime(2)					          
                                end,                                                
                        curIntegrationTime == 2)
                },
        }) 

	window:addWidget(menu)	
        self:tieAndShowWindow(window)
end

function menuSetFactor(self)
	local window = Window("window", "Change Factor...")
	local group = RadioGroup()

	local menu = SimpleMenu("menu")
	
	menuItem = {
		text = "1",
		style = 'item_choice',
		check = RadioButton("radio", group, function(event, menuItem)
				self:_changeFactor(1)
			end,
			curFactor == 1)
	}
	menu:addItem(menuItem)

	for i = 2,50,2 do

		menuItem = {
                        text = tostring(i),
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeFactor(i)					          
                                end,                                                
                        curFactor == i)
                }

		menu:addItem(menuItem)
 	end

	window:addWidget(menu)
	self:tieAndShowWindow(window)
end

function openWindow(self)
	local window = Window("text_list", 'FactoryTest: Ambient Light Sensor')

	-- Initialize Gain and Integration Time to Default Values of this Applet
	self:_changeGain(curGain)
	self:_changeIntegrationTime(curIntegrationTime)

	mainMenu = SimpleMenu("menu")

	tChannel0.item = {
		text = "Channel 0",
		style = 'item_no_arrow',
	}

	tChannel1.item = {
		text = "Channel 1",
		style = 'item_no_arrow',
	}

	tLux.item = {
		text = "Lux",
		style = 'item_no_arrow',
	}
	
	tBright.item = {
		text = "Brightness",
		style = 'item_no_arrow',
	}

	gainItem = {
		text = "Change Gain (Currently Off)",
		callback = function(event, index) 
			self:menuSetGain()
			end
	}

	integrationItem = {
		text = "Change Integration Time (402ms)",
		callback = function(event, index) 
			self:menuSetIntegration()
			end
	}

	factorItem = {
		text = "Change Factor (1)",
		callback = function(event, index) 
			self:menuSetFactor()
			end
	}
	
	mainMenu:addItem(tChannel0.item)
	mainMenu:addItem(tChannel1.item)
	mainMenu:addItem(tLux.item)
	mainMenu:addItem(tBright.item)
	mainMenu:addItem(gainItem)
	mainMenu:addItem(integrationItem)
	mainMenu:addItem(factorItem)

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

