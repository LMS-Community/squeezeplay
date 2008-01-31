
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

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("applets.setup")

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


local CONNECT_TIMEOUT = 30


-- main setting menu
function settingsShow(self)

	local window = Window("window", self:string("SLIMSERVER_SERVERS"))
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


	-- Discover slimservers in this window
	self.sdApplet:discover()
	window:addTimer(1000, function() self.sdApplet:discover() end)


	-- slimservers on the poll list
	local poll = self.sdApplet:pollList()
	for address,_ in pairs(poll) do
		if address ~= "255.255.255.255" then
			self:_addServerItem(nil, address)
		end
	end


	-- discovered slimservers
	for _,server in self.sdApplet:allServers() do
		self:_addServerItem(server)
	end

	local item = {
		text = self:string("SLIMSERVER_ADD_SERVER"), 
		sound = "WINDOWSHOW",
		callback = function(event, menuItem)
				   self:_addServer(menuItem)
			   end,
		weight = 2
	}
	menu:addItem(item)

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
			   function()
				   self:storeSettings()
			   end
		   )

	self:tieAndShowWindow(window)
end


function free(self)
	jnt:unsubscribe(self)
end


function _addServerItem(self, server, address)
	log:debug("_addServerItem ", server, " " , port)

	local id = server or address

	-- remove existing entry
	if self.serverList[id] then
		self.serverMenu:removeItem(self.serverList[id])
	end
	if server and self.serverList[server:getIpPort()] then
		self.serverMenu:removeItem(self.serverList[server:getIpPort()])
	end

	local currentPlayer = self.sdApplet:getCurrentPlayer()

	-- new entry
	local item
	if server and currentPlayer and currentPlayer:canConnectToServer() then
		local f = function()
				  self:connectPlayer(currentPlayer, server)
			  end

		item = {
			text = server:getName(),
			sound = "WINDOWSHOW",
			callback = f,
			connectFunc = f,
			weight = 1
		}
	else
		item = {
			text = server and server:getName() or address,
			weight = 1,
			style = 'itemNoAction'
		}
	end

	-- check current player
	if currentPlayer and server == currentPlayer:getSlimServer() then
		item.style = 'checkedNoAction'
		item.callback = nil
	end

	self.serverMenu:addItem(item)
	self.serverList[id] = item

	if currentPlayer and server == currentPlayer:getSlimServer() then
		self.serverMenu:setSelectedItem(item)
	end
end


function _delServerItem(self, server, address)
	-- remove entry
	local id = server or address
	if self.serverList[id] then
		self.serverMenu:removeItem(self.serverList[id])
		self.serverList[id] = nil
	end

	-- new entry if server is on poll list
	if server then
		local poll = self.sdApplet:pollList()
		local address = server:getIpPort()
		if poll[address] then
			self:_addServerItem(nil, address)
		end
	end
end


function notify_serverNew(self, server)
	self:_addServerItem(server)
end


function notify_serverDelete(self, server)
	self:_delServerItem(server)
end


function _updateServerList(self, player)
	local server = player and player:getSlimServer()

	for id, item in pairs(self.serverList) do
		if server == id then
			item.style = 'checkedNoAction'
			item.callback = nil
		else
			item.style = nil

			if player and player:canConnectToServer() then
				item.callback = item.connectFunc
			end
		end
		self.serverMenu:updatedItem(item)
	end
end


function notify_playerNew(self, player)
	log:warn("waitForConnect=", self.waitForConnect)
	if self.waitForConnect then
		log:warn("  server=", self.waitForConnect.server)
		log:warn("  player=", self.waitForConnect.player)
	end

	if self.waitForConnect and self.waitForConnect.player == player
		and self.waitForConnect.server == player:getSlimServer() then

		self.waitForConnect = nil
		jiveMain:closeToHome()
	end

	local currentPlayer = self.sdApplet:getCurrentPlayer()
	if player ~= currentPlayer then
		return
	end

	_updateServerList(self, player)
end


function notify_playerDelete(self, player)
	local currentPlayer = self.sdApplet:getCurrentPlayer()
	if player ~= currentPlayer then
		return
	end

	_updateServerList(self, player)
end


function notify_playerCurrent(self, player)
	_updateServerList(self, player)
end


-- connect player to server
function connectPlayer(self, player, server)
	-- if connecting to SqueezeNetwork, first check jive is linked
	if server:getPin() then
		local snpin = appletManager:loadApplet("SqueezeNetworkPIN")
		snpin:enterPin(server, nil,
			       function()
				       self:connectPlayer(player, server)
			       end)

		return
	end

	-- we are now ready to connect to SqueezeCenter
	if not server:isSqueezeNetwork() then
		self:_doConnectPlayer(player, server)
	end

	-- make sure the player is linked on SqueezeNetwork, this may return an
	-- error if the player can't be linked, for example it is linked to another
	-- account already.
	local cmd = { 'playerRegister', player:getUuid(), player:getId() }

	local playerRegisterSink = function(chunk, err)
		if chunk.error then
			self:_playerRegisterFailed(chunk.error)
		else
			self:_doConnectPlayer(player, server)
		end
	end

	server:request(playerRegisterSink, nil, cmd)
end


function _doConnectPlayer(self, player, server)

	-- tell the player to move servers
	self.waitForConnect = {
		player = player,
		server = server
	}
	player:connectToServer(server)

	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnecting"))

	local statusLabel = Label("text", self:string("SLIMSERVER_CONNECTING_TO", server:getName()))
	window:addWidget(statusLabel)

	-- disable key presses
	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   return EVENT_CONSUME
			   end)

	local timeout = 1
	window:addTimer(1000,
			function()
				-- scan all servers waiting for the player
				self.sdApplet:discover()

				-- we detect when the connect to the new server
				-- with notify_playerNew

				timeout = timeout + 1
				if timeout == CONNECT_TIMEOUT then
					self:_connectPlayerFailed(player, server)
				end
			end)

	self:tieAndShowWindow(window)
end


function _playerRegisterFailed(self, error)
	local window = Window("wireless", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local textarea = Textarea("textarea", error)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("SQUEEZEBOX_GO_BACK"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end

					},
				})


	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


-- failed to connect player to server
function _connectPlayerFailed(self, player, server)
	local window = Window("wireless", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("SQUEEZEBOX_GO_BACK"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("SQUEEZEBOX_TRY_AGAIN"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:connectPlayer(player, server)
								   window:hide()
							   end
					},
				})


	local help = Textarea("help", self:string("SQUEEZEBOX_PROBLEM_HELP", player:getName(), server:getName()))

	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


function _getOtherServer(self)
	local list = self.sdApplet:pollList()
	for i,v in pairs(list) do
		if i ~= "255.255.255.255" then
			return i
		end
	end

	return nil
end


-- remove broadcast address & add new address
function _add(self, address)
	log:debug("SlimServerApplet:_add: ", address)

	-- only keep other server and the broadcast address
	local oldAddress = self:_getOtherServer()
	self:_delServerItem(nil, oldAddress)

	local list = {
		["255.255.255.255"] = "255.255.255.255",
		[address] = address
	}

	self.sdApplet:pollList(list)
	self:getSettings().poll = list
end


-- ip address input window
function _addServer(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.ipAddressValue(self:_getOtherServer() or "0.0.0.0")
	local input = Textinput("textinput", v,
				function(_, value)
					self:_add(value:getValue())
					self:_addServerItem(nil, value:getValue())

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	window:addWidget(Textarea("help", self:string("SLIMSERVER_HELP")))
	window:addWidget(input)

	self:tieAndShowWindow(window)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

