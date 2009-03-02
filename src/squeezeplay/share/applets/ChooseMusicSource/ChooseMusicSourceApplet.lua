
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

local Framework     = require("jive.ui.Framework")
local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Keyboard      = require("jive.ui.Keyboard")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("applets.setup")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local CONNECT_TIMEOUT = 30


-- service to select server for a player
function selectMusicSource(self, setupNext, titleStyle)
	if setupNext then
		self.setupNext = setupNext
	end
	if titleStyle then
		self.titleStyle = titleStyle
	end
	self:settingsShow()
end


-- main setting menu
function settingsShow(self)

	local window = Window("window", self:string("SLIMSERVER_SERVERS"), self.titleStyle)
	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)
	window:setAllowScreensaver(false)

	local current = appletManager:callService("getCurrentPlayer")

	self.serverMenu = menu
	self.serverList = {}

	-- subscribe to the jnt so that we get notifications of servers added/removed
	jnt:subscribe(self)


	-- Discover players in this window
	appletManager:callService("discoverPlayers")
	window:addTimer(1000, function() appletManager:callService("discoverPlayers") end)


	-- squeezecenter on the poll list
	log:debug("*****Polled Server List:")
	local poll = appletManager:callService("getPollList")
	for address,_ in pairs(poll) do
		log:debug('Found: ', address)
		if address ~= "255.255.255.255" then
			log:debug('Add to menu: ', address)
			self:_addServerItem(nil, address)
		end
	end


	-- discovered squeezecenters
	log:debug('*****Discovered Server List:')
	for _,server in appletManager:callService("iterateSqueezeCenters") do
		log:debug('discovered server: ', server)
		self:_addServerItem(server, _)
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
	appletManager:callService("hideConnectingToPlayer")

end


function free(self)
	jnt:unsubscribe(self)
end


function _addServerItem(self, server, address)
	log:debug("\t_addServerItem ", server, " " , address)

	local id
	if server then
		id = server:getIpPort()
	else
		id = address
	end

	log:debug("\tid for this server set to: ", id)

	local currentPlayer    = appletManager:callService("getCurrentPlayer")

	-- Bug 9900
	-- squeezeplay cannot connect to production SN
	if server and server:getIpPort() == "www.squeezenetwork.com" and 
		currentPlayer and currentPlayer:getModel() == "squeezeplay" then
			return
	end

	-- remove existing entry
	if self.serverList[id] then
		self.serverMenu:removeItem(self.serverList[id])
	end
	if server and self.serverList[server:getIpPort()] then
		self.serverMenu:removeItem(self.serverList[server:getIpPort()])
	end


	-- new entry
	local item

	if server and currentPlayer and currentPlayer:canConnectToServer() then
		log:debug("\tadd menu item with callback")
		local f = function()
                    if server:isPasswordProtected() then
				appletManager:callService("squeezeCenterPassword", server, self.setupNext, self.titleStyle)
			else
                        	self:connectPlayerToServer(currentPlayer, server)
				if self.setupNext then
					self.setupNext()
				end
                    end
                end
                
		item = {
			text = server:getName(),
			sound = "WINDOWSHOW",
			callback = f,
			connectFunc = f,
			weight = 1
		}
	else
		log:debug("\tadd menu item without callback")
		item = {
			text = server and server:getName() or address,
			weight = 1,
			style = 'itemNoArrow'
		}
	end

	-- check current player
	if currentPlayer and currentPlayer:getSlimServer() and server == currentPlayer:getSlimServer() then
		log:debug("\tthis is the connected server, so remove callback for this item")
		item.style = 'itemCheckedNoArrow'
		item.callback = self.setupNext
	end

	self.serverMenu:addItem(item)
	self.serverList[id] = item

	if currentPlayer and currentPlayer:getSlimServer() and server == currentPlayer:getSlimServer() then
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
		local poll = appletManager:callService("getPollList")
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
			item.style = 'itemCheckedNoArrow'
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

	local currentPlayer = appletManager:callService("getCurrentPlayer")
	if player ~= currentPlayer then
		return
	end

	_updateServerList(self, player)
end


function notify_playerDelete(self, player)
	local currentPlayer = appletManager:callService("getCurrentPlayer")
	if player ~= currentPlayer then
		return
	end

	_updateServerList(self, player)
end


function notify_playerCurrent(self, player)
	_updateServerList(self, player)
end


-- connect player to server
function connectPlayerToServer(self, player, server)
	log:warn('connectPlayerToServer()')
	-- if connecting to SqueezeNetwork, first check jive is linked
	if server:getPin() then
		appletManager:callService("enterPin", server, nil,
			       function()
				       self:connectPlayerToServer(player, server)
			       end)
		return
	end


	-- stoppage popup
	local window = Popup("waiting_popup")
	window:addWidget(Icon("icon_connecting"))

	local statusLabel = Label("text", self:string("SLIMSERVER_CONNECTING_TO", server:getName()))
	window:addWidget(statusLabel)

	-- disable input, but still allow disconnect_player
	window:ignoreAllInputExcept({"disconnect_player"})


	local timeout = 1
	window:addTimer(1000,
			function()
				-- scan all servers waiting for the player
				appletManager:callService("discoverPlayers")

				-- we detect when the connect to the new server
				-- with notify_playerNew

				timeout = timeout + 1
				if timeout == CONNECT_TIMEOUT then
					self:_connectPlayerFailed(player, server)
				end
			end)

	self:tieAndShowWindow(window)


	-- we are now ready to connect to SqueezeCenter
	if not server:isSqueezeNetwork() then
		self:_doConnectPlayer(player, server)
		return
	end

	-- make sure the player is linked on SqueezeNetwork, this may return an
	-- error if the player can't be linked, for example it is linked to another
	-- account already.
	local cmd = { 'playerRegister', player:getUuid(), player:getId(), player:getName() }

	local playerRegisterSink = function(chunk, err)
		if chunk.error then
			self:_playerRegisterFailed(chunk.error)
		else
			self:_doConnectPlayer(player, server)
		end
	end

	server:userRequest(playerRegisterSink, nil, cmd)
end


function _doConnectPlayer(self, player, server)
	-- tell the player to move servers
	self.waitForConnect = {
		player = player,
		server = server
	}
	player:connectToServer(server)
end


function _playerRegisterFailed(self, error)
	local window = Window("error", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local textarea = Textarea("text", error)

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
	local window = Window("error", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
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
								   self:connectPlayerToServer(player, server)
								   window:hide()
							   end
					},
				})


	local help = Textarea("helptext", self:string("SQUEEZEBOX_PROBLEM_HELP", player:getName(), server:getName()))

	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


function _getOtherServer(self)
	local list = appletManager:callService("getPollList")
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

	appletManager:callService("setPollList", list)
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

	local keyboard = Keyboard("keyboard", "numeric")
--	window:addWidget(Textarea("helptext", self:string("SLIMSERVER_HELP")))
	window:addWidget(input)
	window:addWidget(keyboard)
	window:focusWidget(input)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

