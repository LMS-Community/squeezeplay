
--[[
=head1 NAME

applets.Developer.DeveloperApplet - Display/Hide developer menu Applet

=head1 DESCRIPTION

This applet is to allow a developer to display/hide the developer menu from the settings menu

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>.

=cut
--]]


-- stuff we use
local tostring, tonumber, pairs, ipairs, table = tostring, tonumber, pairs, ipairs, table
local oo                     = require("loop.simple")
local string                = require("jive.utils.string")
local Applet                 = require("jive.Applet")
local Window                 = require("jive.ui.Window")
local Framework              = require('jive.ui.Framework')

local SimpleMenu             = require("jive.ui.SimpleMenu")

local debug                  = require("jive.utils.debug")
local jiveMain               = jiveMain
local appletManager          = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)

function developerModeSwitch(self, item)
	log:debug("Entering developerContextMenu")
	if item.node ~= 'settings' then
		log:debug("item node is not settings, ignore it")
		return EVENT_CONSUME
	end
	if self:getSettings()['developerMode'] == false then
		log:debug("developer mode was set to false, load developer menu")
		self:loadDeveloperMenu()
		self:getSettings()['developerMode'] = true
		self:storeSettings()
	else
		log:debug("developer mode is true, developer mode already loaded")
	end
	return EVENT_CONSUME
end

function loadDeveloperMenu(self)
	local item = jiveMain:getMenuItem('developerSettings')
	log:debug("item received as ", item);
	if item then
		local newItem = jiveMain:addItemToNode(item, 'settings')
		jiveMain:itemToBottom(newItem, 'settings')
	end
	log:info("developer menu LOADED")
end

function settingsShow(self, menuItem)
	local window = Window("text_list", menuItem.text, 'settingstitle')

	log:debug("create menuItem...")
	local menu = SimpleMenu("menu", {
					{
						text = self:string("EXIT_CANCEL"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("EXIT_CONTINUE"),
						sound = "WINDOWSHOW",
						callback = function()
								self:_exitDeveloper()
								window:hide()
								appletManager:callService("goHome")
							end
					},
				})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function _exitDeveloper(self)
	log:debug("Entered _exitDeveloper function")
	local item = jiveMain:getMenuItem('developerSettings')
	log:debug("item received as ", item);
	item.node = 'hidden'
	jiveMain:addItem(item)
	jiveMain:removeItemFromNode(item, 'settings')
	self:getSettings()['developerMode'] = false
	self:storeSettings()
	log:info("developer menu item removed")
end

--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
