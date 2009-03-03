
--[[
=head1 NAME

applets.LogSettings.LogSettingsApplet - An applet to control Jive log verbosity.

=head1 DESCRIPTION

This applets collects the log categories defined in the running Jive program
and displays each along with their respective verbosity level. Changing the
level is taken into account immediately.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
LogSettingsApplet overrides the following methods:

=cut
--]]


-- stuff we use
local pairs = pairs

local table           = require("table")

local oo              = require("loop.simple")
local logging         = require("logging")

local Applet          = require("jive.Applet")
local Choice          = require("jive.ui.Choice")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local jul             = require("jive.utils.log")

local log             = jul.logger("applets.browser")


module(..., Framework.constants)
oo.class(_M, Applet)


-- _gatherLogCategories
-- workhouse that discovers the log categories and for each, creates a suitable
-- table entry to please SimpleMenu
local function _gatherLogCategories()
	
	local res = {}
	
	-- for all items in the (sub)-table
	for k,v in pairs(jul.getCategories()) do
	
		-- create a Choice
		local choice = Choice(
			"choice", 
			{ "Debug", "Info", "Warn", "Error" }, 
			function(obj, selectedIndex)
				log:info("Setting log category ", k, " to ", logging.LEVEL_A[selectedIndex])
				v:setLevel(logging.LEVEL_A[selectedIndex])
			end,
			logging.LEVEL_H[v:getLevel()]
		)
		
		-- insert suitable entry for Choice menu
		table.insert(res, 
			{
				text = k,
				style = 'item_choice',
				icon = choice,
			}
		)
	end
	
	return res
end


-- logSettings
-- returns a window with Choices to set the level of each log category
-- the log category are discovered
function logSettings(self, menuItem)

	local logCategories = _gatherLogCategories()
	local window = Window("text_list", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu", logCategories)
	menu:setComparator(menu.itemComparatorAlpha)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

