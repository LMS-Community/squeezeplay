
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

local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")

local log           = require("jive.utils.log").logger("applets.setup")

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


-- main setting menu
function settingsShow(self, menuItem)

	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)


	self.sdApplet = appletManager:getAppletInstance("SlimDiscovery")
	if not self.sdApplet then
		return window:tieAndShowWindow()
	end

	self.serverMenu = menu
	self.serverList = {}

	-- subscribe to the jnt so that we get notifications of servers added/removed
	jnt:subscribe(self)


	-- slimservers on the poll list
	local poll = self.sdApplet:pollList()
	for address,_ in pairs(poll) do
		if address ~= "255.255.255.255" then
			self:_addServerItem(address)
		end
	end


	-- discovered slimservers
	for _,server in self.sdApplet:allServers() do
		local id = server:getIpPort()
		self:_addServerItem(id, server)
	end

	local item = {
		text = self:string("SLIMSERVER_ADD_SERVER"), 
		callback = function(event, menuItem)
				   self:_addServer(menuItem)
			   end,
		weight = 2
	}
	menu:addItem(item)

	item = {
		text = self:string("SLIMSERVER_SQUEEZENETWORK"), 
		callback = function(event, menuItem)
				   self:_connectSqueezeNetwork(menuItem)
			   end,
		weight = 3
	}
	menu:addItem(item)

	item = {
		text = self:string("SLIMSERVER_AUTO_DISCOVERY"),
		icon = Checkbox("checkbox",
				function(object, isSelected)
					if isSelected then
						self:_add("255.255.255.255")
					else
						self:_del("255.255.255.255")
					end
				end,
				poll["255.255.255.255"] ~= nil
			),
		weight = 4 
	}
	menu:addItem(item)

	-- Discover slimservers in this window
	window:addTimer(1000, function() self.sdApplet:discover() end)

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
			   function()
				   jnt:unsubscribe(self)
				   self:storeSettings()
			   end
		   )

	self:tieAndShowWindow(window)
end


function _addServerItem(self, id, server)
	log:debug("_addServerItem ", id, " " ,server)

	-- remove existing entry
	if self.serverList[id] then
		self.serverMenu:removeItem(self.serverList[id])
	end

	-- new entry
	local item = {
		text = server and server:getName() or id,
		callback = function() self:_serverMenu(id, server) end,
		weight = 1
	}
	self.serverMenu:addItem(item)
	self.serverList[id] = item
end


function _delServerItem(self, id, server)
	-- remove entry
	if self.serverList[id] then
		server.serverMenu:removeItem(self.serverList[id])
		self.serverList[id] = nil
	end

	-- new entry if server is on poll list
	local poll = self.sdApplet:pollList()
	if poll[id] then
		self:_addServerItem(id)
	end
end

function _serverMenu(self, id, server)
	local name = server and server:getName() or id

	local window = Window("window", name)
	local menu = SimpleMenu("menu", items)

	if server then
		menu:addItem({
				     text = self:string("SLIMSERVER_ADDRESS"),
				     icon = Label("value", table.concat({ server:getIpPort() }, ":"))
			     })
		menu:addItem({
				     text = self:string("SLIMSERVER_VERSION"),
				     icon = Label("value", server:getVersion() or "")
			     })
	end

	local poll = self.sdApplet:pollList()
	if poll[id] then
		menu:addItem({
				     text = self:string("SLIMSERVER_FORGET", name),
				     callback = function() 
							self:_del(id)
							window:hide()
						end
			     })
	end

	window:addWidget(menu)
	self:tieAndShowWindow(window)
end


function notify_serverNew(self, server)
	log:debug("server new", server)

	local id = server:getIpPort()
	self:_addServerItem(id, server)
end


function notify_serverDelete(self, server)
	log:debug("server delete", server)

	local id = server:getIpPort()
	self:_delServerItem(id, server)
end


-- remove broadcast address & add new address
function _add(self, address)
	log:debug("SlimServerApplet:_add: ", address)

	local list = self.sdApplet:pollList()
	list[address] = address

	self.sdApplet:pollList(list)
	self:getSettings().poll = list
end


-- remove address and add broadcast if no other addresses
function _del(self, address)
	log:debug("SlimServerApplet:_del: ", address)

	local list = self.sdApplet:pollList()
	list[address] = nil

	self.sdApplet:pollList(list)
	self:getSettings().poll = list
end
	

-- ip address input window
function _addServer(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.ipAddressValue("0.0.0.0")
	local input = Textinput("textinput", v,
				function(_, value)
					self:_add(value:getValue())
					self:_addServerItem(value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	window:addWidget(Textarea("help", self:string("SLIMSERVER_HELP")))
	window:addWidget(input)

	self:tieAndShowWindow(window)
end

-- Connect to SqueezeNetwork
function _connectSqueezeNetwork(self, menuItem)
	local popup = Popup("popupIcon")
	popup:addWidget(Label("label", ""))
	popup:addWidget(Label("text", "\nComing Soon..."))

        self:tieAndShowWindow(popup)
        return popup	
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

