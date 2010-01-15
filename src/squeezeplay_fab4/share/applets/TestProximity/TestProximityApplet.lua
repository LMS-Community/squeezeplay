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
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Window                 = require("jive.ui.Window")

-- Not yet defined as a constant in jive.ui.
local SW_TABLET_MODE	     = 1

local SYSPATH = "/sys/bus/i2c/devices/0-0047/"

-- Main Menu
local mainMenu = nil
local menuItemDetected = nil
local menuItemDensity = nil
local menuItemControl = nil
local menuItemDutyCycle = nil

-- store current values for config menus
local curControl = 3
local curDutyCycle = 4

module(..., Framework.constants)
oo.class(_M, Applet)

function _updateLabel(self, menuItem, prefix, value)
	menuItem.text = prefix .. value
	mainMenu:updatedItem(menuItem)
end

function _update(self)

	log:error("_update")

	-- proximity_density
	local f = io.open(SYSPATH .. "proximity_density")
	local density = f:read("*all")
	f:close()
	self:_updateLabel(menuItemDensity, "Density: ", density)

	-- control
	f = io.open(SYSPATH .. "proximity_control")
	local control = f:read("*all")
	f:close()
	curControl = tonumber(control)
	self:_updateLabel(menuItemControl, "Control: ", curControl)

	-- duty control
	f = io.open(SYSPATH .. "proximity_duty_cycle")
	local duty = f:read("*all")
	f:close()
	curDutyCycle = tonumber(duty)
	self:_updateLabel(menuItemDutyCycle, "Duty Cycle: ", curDutyCycle)
end

function _changeControl(self, newValue)
	-- Send The Command
	local f = io.open(SYSPATH .. "proximity_control", "w")
	f:write(tostring(newValue))
	f:close()
end

function _changeDutyCycle(self, newValue)
	-- Send The Command
	local f = io.open(SYSPATH .. "proximity_duty_cycle", "w")
	f:write(tostring(newValue))
	f:close()
end

function menuSetControl(self)
	local window = Window("text_list", "Change Control...")
	local group = RadioGroup()

	local menu = SimpleMenu("menu") 

	for i = 0,3,1 do

		menuItem = {
                        text = tostring(i),
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeControl(i)					          
                                end,                                                
                        curControl == i)
                }

		menu:addItem(menuItem)
 	end

	window:addWidget(menu)	
        self:tieAndShowWindow(window)
end

function menuSetDutyCycle(self)
	local window = Window("text_list", "Change Duty Cycle...")
	local group = RadioGroup()

        local menu = SimpleMenu("menu") 

	for i = 0,7,1 do

		menuItem = {
                        text = tostring(i),
			style = 'item_choice',
                        check = RadioButton("radio", group, function(event, menuItem)
					self:_changeDutyCycle(i)					          
                                end,                                                
                        curDutyCycle == i)
                }		
	
		menu:addItem(menuItem)
	end

	window:addWidget(menu)	
        self:tieAndShowWindow(window)
end

function openWindow(self)
	local window = Window("text_list", 'FactoryTest: Proximity')


	mainMenu = SimpleMenu("menu")

	menuItemDetected = {
		text = "Proximity: None Detected"
	}

	menuItemDensity = {
		text = "Density: n/a"
	}

	menuItemControl = {
		text = "Control: n/a",
		callback = function(event, index) 
			self:menuSetControl()
			end
	}

	menuItemDutyCycle =  {
		text = "Duty Cycle: n/a",
		callback = function(event, index) 
			self:menuSetDutyCycle()
			end
	}

	mainMenu:addItem(menuItemDetected)
	mainMenu:addItem(menuItemDensity)
	mainMenu:addItem(menuItemControl)
	mainMenu:addItem(menuItemDutyCycle)
	window:addWidget(mainMenu)

	window:setAllowScreensaver(false)

        Framework:addListener(EVENT_SWITCH,
                function(event)
			local type = event:getType()
			local sw,val = event:getSwitch()

			if( sw == SW_TABLET_MODE ) then 
				if( val == 1 ) then
					menuItemDetected.text = "Proximity: *Detected*"
				else 
					menuItemDetected.text = "Proximity: None Detected";
				end
			end

			mainMenu:updatedItem(menuItem)
                end)

	window:addAnimation(
		function()
                        self:_update()
                end,
		1
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

