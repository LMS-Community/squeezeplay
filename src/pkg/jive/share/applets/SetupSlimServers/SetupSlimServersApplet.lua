
--[[
=head1 NAME

applets.SlimServers.SlimServersApplet - Menus to edit the Slimserver address

=head1 DESCRIPTION

This applet allows users to define IP addresses for their slimserver.  This is useful if
the automatic discovery process does not work - normally because the server and jive are on different subnets meaning
that UDP broadcasts probing for servers do not get through.

Users may add one or more slimserver IP addresses, these will be probed by the server discovery mechanism
implemented in SlimDiscover.  Removing all explicit server IP addresses returns to broadcast discovery.

=head1 FUNCTIONS


=cut
--]]


-- stuff we use
local pairs, setmetatable, tostring, tonumber  = pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local SlimServers   = require("jive.slim.SlimServers")

local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")

local log           = require("jive.utils.log").logger("applets.setup")

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


-- main setting menu
function settingsShow(self, menuItem)

	self.SlimServers = appletManager:getApplet("SlimDiscovery"):getSlimServers()
	
	local window = Window("window", menuItem.text)
	local poll   = self.SlimServers:pollList()
	local items  = {}

	if poll["255.255.255.255"] then
		items[#items + 1] = {
			text = self:string("SLIMSERVER_AUTO_MODE"), 
		}
	end

	for k, _ in pairs(poll) do
		if k ~= "255.255.255.255" then
			items[#items + 1] = {
				text = k,
				callback = function()
					local subwindow = Window("window", k)
					local submenu = SimpleMenu("menu", {
						{
							text = self:string("SLIMSERVER_DELETE"),
							callback = function(event, menuItem)
										   self:_del(k)
										   subwindow:hide()
										   window:hide()
									   end,
						},
						{
							text = self:string("SLIMSERVER_EDIT"),
							callback = function(event, menuItem)
										   self:_ipInput(menuItem, function (addr) self:_add(addr) end, k):show()
										   self:_del(k)
										   subwindow:hide()
										   window:hide()
									   end,
						}
					})
					subwindow:addWidget(submenu)
					subwindow:show()
				end
			}
		end
	end

	items[#items + 1] = {
		text = self:string("SLIMSERVER_ADD_SERVER"), 
		callback = function(event, menuItem)
					   self:_ipInput(menuItem, function (addr) self:_add(addr) end):show()
					   window:hide()
				   end
	}

	local menu = SimpleMenu("menu", items)
	
	window:addWidget(menu)

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	self:tieAndShowWindow(window)
	return window
end


-- remove broadcast address & add new address
function _add(self, address)
	log:debug("SlimServerApplet:_add: ", address)

	local list = self.SlimServers:pollList()

	list["255.255.255.255"] = nil

	list[address] = address

	self.SlimServers:pollList(list)
	self:setSettings({ poll = list })
end


-- remove address and add broadcast if no other addresses
function _del(self, address)
	log:debug("SlimServerApplet:_del: ", address)

	local list = self.SlimServers:pollList()

	list[address] = nil

	if #list == 0 then
		list["255.255.255.255"] = "255.255.255.255"
	end

	self.SlimServers:pollList(list)
	self:setSettings({ poll = list })
end
	

-- ip address input window
function _ipInput(self, menuItem, callback, init)
	local window = Window("window", menuItem.text)

	local v = Textinput.ipAddressValue(init or "0.0.0.0")
	local input = Textinput("textinput", v,
				function(_, value)
					callback(value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", self:string("SLIMSERVER_HELP"))

	window:addWidget(help)
	window:addWidget(input)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

