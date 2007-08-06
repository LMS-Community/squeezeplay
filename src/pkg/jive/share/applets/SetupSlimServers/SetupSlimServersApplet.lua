
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

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


-- main setting menu
function menu(self, menuItem)

	self.SlimServers = appletManager:getApplet("SlimDiscovery"):getSlimServers()
	
	local window = Window("window", menuItem.text)
	local poll   = self.SlimServers:pollList()
	local items  = {}

	if poll["255.255.255.255"] then
		items[#items + 1] = {
			text = self:string("AUTO_MODE"), 
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
							text = self:string("DELETE"),
							callback = function(event, menuItem)
										   self:_del(k)
										   subwindow:hide()
										   window:hide()
									   end,
						},
						{
							text = self:string("EDIT"),
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
		text = self:string("ADD_SERVER"), 
		callback = function(event, menuItem)
					   self:_ipInput(menuItem, function (addr) self:_add(addr) end):show()
					   window:hide()
				   end
	}

	local menu = SimpleMenu("menu", items)
	
	window:addWidget(menu)

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

	-- create an object to hold the ip address. the methods are used
	-- by the text input widget.
	local v = {}
	setmetatable(v, {
				 __tostring =
				     function(value)
						 return table.concat(value, ".")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
							 local i = 1
						     for dd in string.gmatch(str, "([0-9]+)") do
								 if (i <= 4) then
									 value[i] = string.format("%03d", tonumber(dd))
								 end
								 i = i + 1
							 end
					     end,

				     getValue =
					     function(value)
							 return tonumber(value[1]) .. "." .. tonumber(value[2]) .. "." .. tonumber(value[3]) .. "." .. tonumber(value[4])
					     end,

				     getChars = 
					     function(value, cursor)
							 if cursor == 4 or cursor == 8 or cursor == 12 then
								 return "."
							 elseif cursor == 1 or cursor == 5 or cursor == 9 or cursor == 13 then
								 return "012"
							 else
								 return "0123456789"
							 end
					     end,

				     isEntered =
					     function(value, cursor)
						     return cursor == 16
					     end
			     }
		     })

	-- set the initial value
	v:setValue(init or "0.0.0.0")

	local window = Window("window", menuItem.text)

	local input = Textinput("textinput", v,
				function(_, value)
					callback(value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", self:string("HELP"))

	window:addWidget(help)
	window:addWidget(input)

	return window
end


function displayName(self)
	return self:string("SERVERS")
end


function free(self)
	self:storeSettings()
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

