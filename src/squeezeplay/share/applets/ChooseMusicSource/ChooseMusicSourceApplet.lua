
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
local pairs, setmetatable, tostring, tonumber, ipairs  = pairs, setmetatable, tostring, tonumber, ipairs

local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")

local Framework     = require("jive.ui.Framework")
local Event         = require("jive.ui.Event")
local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local Button        = require("jive.ui.Button")
local Group         = require("jive.ui.Group")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Keyboard      = require("jive.ui.Keyboard")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")

local debug         = require("jive.utils.debug")
local iconbar       = iconbar

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local CONNECT_TIMEOUT = 15


--temp during dev
function settingsShow(self)
	selectMusicSource(self)
end

-- service to select server for a player. Note a current player must exist before calling this method
function selectMusicSource(self, playerConnectedCallback, titleStyle, includedServers, specificServer, serverForRetry, ignoreServerConnected)

	if includedServers then
		self.includedServers = includedServers
	end

	if playerConnectedCallback then
		self.playerConnectedCallback = playerConnectedCallback
	else
		self.playerConnectedCallback = 	function()
							appletManager:callService("goHome")
						end
	end

	if titleStyle then
		self.titleStyle = titleStyle
	end

	jnt:subscribe(self)

	self.serverList = {}
	self.ignoreServerConnected = ignoreServerConnected

	if specificServer then
		log:debug("selecting specific server ", specificServer)

		self:selectServer(specificServer, nil, serverForRetry)
		return
	end


	self:_showMusicSourceList()
end


function _showMusicSourceList(self)

	local window = Window("text_list", self:string("SLIMSERVER_SERVERS"), self.titleStyle)
	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)
	window:setAllowScreensaver(false)

	menu:addActionListener("back", self,  function ()
							self:_cancelSelectServer()
							window:hide()

							return EVENT_CONSUME
						end)

	local current = appletManager:callService("getCurrentPlayer")

	self.serverMenu = menu
	self.serverList = {}

	-- subscribe to the jnt so that we get notifications of servers added/removed
	jnt:subscribe(self)


	-- Discover players in this window
	appletManager:callService("discoverPlayers")
	window:addTimer(1000, function() appletManager:callService("discoverPlayers") end)


	-- squeezecenter on the poll list
	log:debug("Polled Servers:")
	local poll = appletManager:callService("getPollList")
	for address,_ in pairs(poll) do
		log:debug("\t", address)
		if address ~= "255.255.255.255" then
			self:_addServerItem(nil, address)
		end
	end


	-- discovered squeezecenters
	log:debug("Discovered Servers:")
	for _,server in appletManager:callService("iterateSqueezeCenters") do
		log:debug("\t", server)
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

	window._isChooseMusicSourceWindow = true

	self:tieAndShowWindow(window)

end


function free(self)

	if self.playerConnectedCallback then
		log:warn("Unexpected free when playerConnectedCallback still exists (could happen on regular back)")
	end
	log:debug("Unsubscribing jnt")
	jnt:unsubscribe(self)

	return true
end


function _addServerItem(self, server, address)
	log:debug("\t_addServerItem ", server, " " , address)

	if not self.serverMenu then
		--happens on selectMusicSource with specificServer
		log:info("Ignoring addServer Item when no serverMenu")
		return
	end
	--not sure this is used anymore, consider removing
	if self.includedServers then
		local found = false
		-- filter server list only showing those found in includedServers
		for _, includedServer in ipairs(self.includedServers) do
			if includedServer == server then
				log:debug("found server: ", server)
				found = true
				break
			end
		end
		if not found then
			log:debug("server not found: ", server)
			return
		end
	end

	if server and server:isSqueezeNetwork() then
		log:debug("Exclude SN")
		return
	end

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
	--todo: this SN bit needs to be reviewed
	if server and server:getIpPort() == "www.squeezenetwork.com" and 
		currentPlayer and currentPlayer:getModel() == "squeezeplay" then
			return
	end

	-- remove existing entry
	if self.serverList[id] then
		self.serverMenu:removeItem(self.serverList[id])
	end

	if server then
		if self.serverList[server:getIpPort()] then
			self.serverMenu:removeItem(self.serverList[server:getIpPort()])
		end

		-- new entry
		local item = {
			text = server:getName(),
			sound = "WINDOWSHOW",
			callback = function()
				self:selectServer(server)
                	end,
			weight = 1,
		}

		self.serverMenu:addItem(item)
		self.serverList[id] = item

		if currentPlayer and currentPlayer:getSlimServer() == server then
			item.style = 'item_checked'
			self.serverMenu:setSelectedItem(item)
		end
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

function notify_serverConnected(self, server)
	if not self.waitForConnect or self.waitForConnect.server ~= server then
		return
	end
	log:info("notify_serverConnected")

	iconbar:setServerError("OK")

	-- hide connection error window (useful when server was down and comes back up)
	-- but we need a check here for other case (can't find it now...) where we need to wait until player current 
	if self.connectingPopup and not self.ignoreServerConnected then
		self:_cancelSelectServer()
	end
end

function _updateServerList(self, player)
	local server = player and player:getSlimServer() and player:getSlimServer():getIpPort()

	for id, item in pairs(self.serverList) do
		if server == id then
			item.style = 'item_checked'
		else
			item.style = nil
		end
		self.serverMenu:updatedItem(item)
	end
end


function notify_playerNew(self, player)
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

	if not player then
		log:warn("Unexpected nil player when waiting for new player or server")
		--todo might this happen if player loses connection during this connection attempt
		-- if so what to do here? Maybe inform user of player disconnection and start over?
		 self:_cancelSelectServer()

	end
end



-- server selected in menu
function selectServer(self, server, passwordEntered, serverForRetry)
	-- ask for password if the server uses http auth
	if not passwordEntered and server:isPasswordProtected() then
		appletManager:callService("squeezeCenterPassword", server,
			function()
				self:selectServer(server, true)
			end, self.titleStyle)
		return
	end

	if server:getVersion() and not server:isCompatible() then
		--we only know if compatible if serverstatus has come back, other version will be nil, and we shouldn't assume not compatible
		_serverVersionError(self, server)
		return
	end


	local currentPlayer = appletManager:callService("getCurrentPlayer")

	if not currentPlayer then
		log:warn("Unexpected nil player when waiting for new player or server")
		--todo might this happen if player loses connection during this connection attempt
		-- if so what to do here? Maybe inform user of player disconnection and start over?
		 self:_cancelSelectServer()
	end


	-- is the player already connected to the server?
	if currentPlayer:getSlimServer() == server and currentPlayer:isConnected() and not self.ignoreServerConnected then

		if self.playerConnectedCallback then
			local callback = self.playerConnectedCallback
			self.playerConnectedCallback = nil
			callback(server)
		end
		return
	end
	if not currentPlayer:getSlimServer() or currentPlayer:getSlimServer() == server then
       	        self:connectPlayerToServer(currentPlayer, server)
	else
		self:_confirmServerSwitch(currentPlayer, server, serverForRetry)
	end

end

--todo: this should hide if connection returns
function _confirmServerSwitch(self, currentPlayer, server, serverForRetry)
	local window = Window("help_list", self:string("SWITCH_SERVER_TITLE"), "setuptitle")

	local textarea = Textarea("help_text", self:string("SWITCH_SERVER_TEXT"))

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = (self:string("SWITCH_BUTTON", server.name)),
		sound = "WINDOWSHOW",
		callback = function()
				self:connectPlayerToServer(currentPlayer, server)
				window:hide(Window.transitionNone)
			   end,
	})
	if serverForRetry then
		menu:addItem({
			text = (self:string("CHOOSE_RETRY", serverForRetry.name)),
			sound = "WINDOWHIDE",
			callback = function()
					log:debug("serverForRetry:", serverForRetry)
					self:connectPlayerToServer(currentPlayer, serverForRetry)
					window:hide(Window.transitionNone)
				   end,
		})
	end
	local cancelAction = function()
		self.playerConnectedCallback = nil
		window:hide()

		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)

	menu:setHeaderWidget(textarea)
	window:addWidget(menu)

	window._isChooseMusicSourceWindow = true

	self:tieAndShowWindow(window)
end


-- hideConnectingToPlayer
-- hide the full screen popup that appears until server and menus are loaded
function hideConnectingToServer(self)
	log:info("Hiding popup, exists?: " , self.connectingPopup)

	if self.connectingPopup then
		log:info("connectingToServer popup hide")

		--perform callback if we've successfully switched to desired player/server
		if self.waitForConnect then
			log:info("waiting for ", self.waitForConnect.player, " on ", self.waitForConnect.server)

			if self.waitForConnect.server == self.waitForConnect.player:getSlimServer() then

				if self.playerConnectedCallback then
					local callback = self.playerConnectedCallback
					self.playerConnectedCallback = nil
					callback(self.waitForConnect.player:getSlimServer())
					self.ignoreServerConnected = nil
				end
			else
				log:warn("server mismatch for player: ", self.waitForConnect.player, "  Expected: ", self.waitForConnect.server,
				" got: ", self.waitForConnect.player:getSlimServer())
			end
			self.waitForConnect = nil
		end

		self.connectingPopup:hide()
		self.connectingPopup = nil

	end

	--pop any applet windows that are on top (so when current server comes back on line, choose music source exits)
	while Framework.windowStack[1] and Framework.windowStack[1]._isChooseMusicSourceWindow do
		log:debug("Hiding ChooseMusicSource window")

		Framework.windowStack[1]:hide()
	end
end


--service method
function showConnectToServer(self, playerConnectedCallback, server)
	log:debug("showConnectToServer", server)

	self.playerConnectedCallback = playerConnectedCallback
	self:_showConnectToServer(appletManager:callService("getCurrentPlayer"), server)
end

function _showConnectToServer(self, player, server)
	if not self.connectingPopup then
		self.connectingPopup = Popup("waiting_popup")
		local window = self.connectingPopup
		window:addWidget(Icon("icon_connecting"))
		window:setAutoHide(false)

		local statusLabel = Label("text", self:string("SLIMSERVER_CONNECTING_TO", server:getName()))
		window:addWidget(statusLabel)

		local timeout = 1

		local cancelAction = function()
			self.connectingPopup:hide()
			self.connectingPopup = nil
			--sometimes timeout not back to 1 next time around, so reset it
			timeout = 1
			self:_connectPlayerFailed(player, server)

		end

		-- disable input
		window:ignoreAllInputExcept({"back"})
		window:addActionListener("back", self, cancelAction)

		window:addTimer(1000,
				function()
					-- scan all servers waiting for the player
					appletManager:callService("discoverPlayers")

					-- we detect when the connect to the new server
					-- with notify_playerNew

					timeout = timeout + 1
					if timeout > CONNECT_TIMEOUT then
						log:warn("Timeout passed, current count: ", timeout)
						cancelAction()
					end
				end)

		window._isChooseMusicSourceWindow = true

		self:tieAndShowWindow(window)
	end
end


-- connect player to server
function connectPlayerToServer(self, player, server)
	log:info('connectPlayerToServer() ', player, " ", server)
	-- if connecting to SqueezeNetwork, first check jive is linked
	if server:getPin() then
		appletManager:callService("enterPin", server, nil,
			       function()
				       self:connectPlayerToServer(player, server)
			       end)
		return
	end


	self:_showConnectToServer(player, server)

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


	window._isChooseMusicSourceWindow = true
	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


function _cancelSelectServer(self)
	log:info("Cancelling Server Selection")

	self.ignoreServerConnected = true
	self.waitForConnect = nil
	self.playerConnectedCallback = nil
	self:hideConnectingToServer()

end


-- failed to connect player to server
function _connectPlayerFailed(self, player, server)
	local window = Window("error", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local cancelAction = function()
		self:_cancelSelectServer()
		window:hide()

		return EVENT_CONSUME
	end

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("SQUEEZEBOX_TRY_AGAIN"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:connectPlayerToServer(player, server)
								   window:hide()
							   end
					},
					{
						text = self:string("CHOOSE_OTHER_LIBRARY"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_showMusicSourceList()	
							   end
					},
				})

	menu:addActionListener("back", self, cancelAction)

	local help = Textarea("help_text", self:string("SQUEEZEBOX_PROBLEM_HELP", player:getName(), server:getName()))

	menu:setHeaderWidget(help)
	window:addWidget(menu)
	window._isChooseMusicSourceWindow = true

	self:tieAndShowWindow(window)
end


-- failed to connect player to server
function _serverVersionError(self, server)
	local window = Window("error", self:string("SQUEEZECENTER_VERSION"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local help = Textarea("help_text", self:string("SQUEEZECENTER_VERSION_HELP", server:getName(), server:getVersion()))

	window:addWidget(help)

	-- timer to check if server has been upgraded
	window:addTimer(1000, function()
		if server:isCompatible() then
			self:selectServer(server)
			window:hide(Window.transitionPushLeft)
		end
	end)

	window._isChooseMusicSourceWindow = true

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
	local window = Window("text_list", menuItem.text)

	local v = Textinput.ipAddressValue(self:_getOtherServer())
	local input = Textinput("textinput", v,
				function(_, value)
					self:_add(value:getValue())
					self:_addServerItem(nil, value:getValue())

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end
	)

	local keyboard = Keyboard("keyboard", "ip", input)
	local backspace = Keyboard.backspace()
        local group = Group('keyboard_textinput', { textinput = input, backspace = backspace } )

        window:addWidget(group)
	window:addWidget(keyboard)
	window:focusWidget(group)

	window._isChooseMusicSourceWindow = true

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

