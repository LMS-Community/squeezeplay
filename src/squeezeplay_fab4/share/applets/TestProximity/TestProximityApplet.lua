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
local Window                 = require("jive.ui.Window")

local EVENT_SWITCH           = jive.ui.EVENT_SWITCH

-- Not yet defined as a constant in jive.ui.
local SW_TABLET_MODE	     = 1

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local menuItem = nil

module(...)                                                                     
oo.class(_M, Applet)

function openWindow(self)
	local window = Window("window", 'FactoryTest: Proximity')


	mainMenu = SimpleMenu("menu")

	menuItem = {
		text = "Proximity: None Detected"
	}


	mainMenu:addItem(menuItem)
	window:addWidget(mainMenu)

	window:setAllowScreensaver(false)

        Framework:addListener(EVENT_SWITCH,
                function(event)
			local type = event:getType()
			local sw,val = event:getSwitch()

			if( sw == SW_TABLET_MODE ) then 
				if( val == 1 ) then
					menuItem.text = "Proximity: *Detected*"
				else 
					menuItem.text = "Proximity: None Detected";
				end
			end

			mainMenu:updatedItem(menuItem)
                end)

        self:tieAndShowWindow(window)
        return window
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

