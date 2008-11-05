
--[[
=head1 NAME

applets.SelectPlayer.SelectPlayerApplet - Applet to select currently active player

=head1 DESCRIPTION

Gets list of all available players and displays for selection. Selection should cause main menu to update (i.e., so things like "now playing" are for the selected player)

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local assert, pairs, ipairs, tostring = assert, pairs, ipairs, tostring

local oo                 = require("loop.simple")
local os                 = require("os")
local string             = require("string")

local Applet             = require("jive.Applet")
local SimpleMenu         = require("jive.ui.SimpleMenu")
local RadioGroup         = require("jive.ui.RadioGroup")
local RadioButton        = require("jive.ui.RadioButton")
local Window             = require("jive.ui.Window")
local Group              = require("jive.ui.Group")
local Icon               = require("jive.ui.Icon")
local Label              = require("jive.ui.Label")
local Framework          = require("jive.ui.Framework")
local Surface            = require("jive.ui.Surface")

local hasWireless, Wireless  = pcall(require, "jive.net.Wireless")

local log                = require("jive.utils.log").logger("applets.setup")
local debug              = require("jive.utils.debug")

local SetupSqueezeboxApplet = require("applets.SetupSqueezebox.SetupSqueezeboxApplet")

local jnt                = jnt
local jiveMain           = jiveMain
local appletManager      = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


local PLAYER_WEIGHT = 1
local SERVER_WEIGHT = 10
local ACTIVATE_WEIGHT = 20

function init(self, ...)
	self.playerItem = {}
	self.serverItem = {}
	self.scanResults = {}

	if hasWireless then
		self.wireless = Wireless(jnt, "eth0")
	end

	jnt:subscribe(self)
	self:manageSelectPlayerMenu()
end


function notify_playerDelete(self, player)
	local mac = player:getId()

	manageSelectPlayerMenu(self)

	if self.playerMenu then
		if self.playerItem[mac] then
			self.playerMenu:removeItem(self.playerItem[mac])
			self.playerItem[mac] = nil
		end

		if player:getSlimServer() then
			self:_updateServerItem(player:getSlimServer())
		end
	end
end


function notify_playerNew(self, player)
	-- get number of players. if number of players is > 1, add menu item
	local mac = player:getId()

	manageSelectPlayerMenu(self)

	if self.playerMenu then
		self:_addPlayerItem(player)

		if player:getSlimServer() then
			self:_updateServerItem(player:getSlimServer())
		end
	end
end


function notify_playerCurrent(self, player)
	self.selectedPlayer = player
	self:manageSelectPlayerMenu()
end


function notify_serverConnected(self, server)
	if not self.playerMenu then
		return
	end

	self:_updateServerItem(server)

	for id, player in server:allPlayers() do
		self:_refreshPlayerItem(player)
	end
	
	self:manageSelectPlayerMenu()

end


function notify_serverDisconnected(self, server)
	if not self.playerMenu then
		return
	end

	self:_updateServerItem(server)

	for id, player in server:allPlayers() do
		self:_refreshPlayerItem(player)
	end

	self:manageSelectPlayerMenu()
end


function manageSelectPlayerMenu(self)
	local _numberOfPlayers = appletManager:callService("countPlayers") or 0
	local currentPlayer    = appletManager:callService("getCurrentPlayer") or nil

	-- if _numberOfPlayers is > 1 and selectPlayerMenuItem doesn't exist, create it
	if _numberOfPlayers > 1 or not currentPlayer then
		if not self.selectPlayerMenuItem then
			local menuItem = {
				id = 'selectPlayer',
				node = 'home',
				text = self:string("SELECT_PLAYER"),
				sound = "WINDOWSHOW",
				callback = function() self:setupShowSelectPlayer() end,
				weight = 80
			}
			jiveMain:addItem(menuItem)
			self.selectPlayerMenuItem = menuItem
		end

	-- if numberOfPlayers < 2 and we're connected to a player and selectPlayerMenuItem exists, get rid of it
	elseif _numberOfPlayers < 2 and currentPlayer and self.selectPlayerMenuItem then
		jiveMain:removeItemById('selectPlayer')
		self.selectPlayerMenuItem = nil
	end
end


function _addPlayerItem(self, player)
	local mac = player:getId()
	local playerName = player:getName()
	local playerWeight = PLAYER_WEIGHT

	-- create a lookup table of valid models, 
	-- so Choose Player does not attempt to render a style that doesn't exist
	local validModel = {
		softsqueeze = true,
		transporter = true,
		squeezebox2 = true,
		squeezebox  = true,
		slimp3      = true,
		receiver    = true,
		boom        = true,
		controller  = true,
	}

	local playerModel = player:getModel()

	if not validModel[playerModel] then
		-- use a generic style when model lists as not valid
		playerModel = 'softsqueeze'
	end

	-- if waiting for a SN pin modify name
	if player:getPin() then
		if not self.setupMode then
			-- Only include Activate SN during setup
			return
		end

		playerName = self:string("SQUEEZEBOX_ACTIVATE", player:getName())
		playerWeight = ACTIVATE_WEIGHT
	end

	local item = {
		id = mac,
		style = playerModel,
		text = "\n" .. playerName,
		sound = "WINDOWSHOW",
		callback = function()
			if self:selectPlayer(player) then
				self.setupNext()
			end
		end,
		focusGained = function(event)
			self:_showWallpaper(mac)
		end,
		weight = playerWeight
	}

	if player == self.selectedPlayer and player:isConnected() then
		item.style = playerModel .. "checked"
	end

	self.playerMenu:addItem(item)
	self.playerItem[mac] = item
	
	if self.selectedPlayer == player then
		self.playerMenu:setSelectedItem(item)
	end
end


function _refreshPlayerItem(self, player)
	local mac = player:getId()

	if player:isAvailable() then
		local item = self.playerItem[mac]
		if not item then
			-- add player
			self:_addPlayerItem(player)

		else
			-- update player state
			if player == self.selectedPlayer then
				item.style = "checked"
			end
		end

	else
		-- not connected
		if self.playerItem[mac] then
			self.playerMenu:removeItem(self.playerItem[mac])
			self.playerItem[mac] = nil
		end
	end
end


-- Add password protected servers
function _updateServerItem(self, server)
	local id = server:getName()

	if not server:isPasswordProtected() then
		if self.serverItem[id] then
			self.playerMenu:removeItem(self.serverItem[id])
			self.serverItem[id] = nil
		end
		return
	end

	local item = {
		id = id,
		text = server:getName(),
		sound = "WINDOWSHOW",
		callback = function()
			appletManager:callService("squeezeCenterPassword", server)
		end,
		weight = SERVER_WEIGHT,
	}

	self.playerMenu:addItem(item)
	self.serverItem[id] = item
end


function _showWallpaper(self, playerId)
	log:debug("previewing background wallpaper for ", playerId)
	appletManager:callService("showBackground", nil, playerId)
end


function setupShowSelectPlayer(self, setupNext, windowStyle)

	if not windowStyle then
		windowStyle = 'settingstitle'
	end
	-- get list of slimservers
	local window = Window("window", self:string("SELECT_PLAYER"), windowStyle)
	window:setAllowScreensaver(false)

        local menu = SimpleMenu("albummenu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	self.playerMenu = menu
	self.setupMode = setupNext ~= nil
	self.setupNext = setupNext or 
		function()
			window:hide(Window.transitionPushLeft)
		end

	self.selectedPlayer = appletManager:callService("getCurrentPlayer")
	for mac, player in appletManager:callService("iteratePlayers") do
		_addPlayerItem(self, player)
	end

	-- Display password protected servers
	for id, server in appletManager:callService("iterateSqueezeCenters") do
		_updateServerItem(self, server)
	end

	-- Bug 6130 add a Set up Squeezebox option, only in Setup not Settings
	if setupNext then
		self.playerMenu:addItem({
			text = self:string("SQUEEZEBOX_SETUP"),
			sound = "WINDOWSHOW",
			callback = function()
				appletManager:callService("setupSqueezeboxSettingsShow")
			end,
			weight = 10,
		})
	end

	window:addWidget(menu)

	window:addTimer(5000, function() self:_scan() end)


	window:addListener(EVENT_WINDOW_ACTIVE,
			   function()
				   self:_scan()
			   end)

	self:tieAndShowWindow(window)
	return window
end


function _scan(self)
	-- SqueezeCenter and player discovery
	appletManager:callService("discoverPlayers")
end


function selectPlayer(self, player)
	-- if connecting to SqueezeNetwork, first check we are linked
	if player:getPin() then
		-- as we are not linked this is a dummy player, after we need linked we
		-- need to return to the choose player screen 
		appletManager:callService("enterPin", nil, player)

		return false
	end

	-- set the current player
	self.selectedPlayer = player
	appletManager:callService("setCurrentPlayer", player)

	-- network configuration needed?
	if player:needsNetworkConfig() then
		appletManager:callService("startSqueezeboxSetup", 
			player:getId(),
			player:getSSID(),
			function()
				jiveMain:closeToHome()
			end
		)
		return false
	end

	-- udap setup needed?
	if player:needsMusicSource() then
		appletManager:callService("selectMusicSource")
		return false
	end

	return true
end


function free(self)

	-- load the correct wallpaper on exit
	if self.selectedPlayer and self.selectedPlayer:getId() then
		self:_showWallpaper(self.selectedPlayer:getId())
	else
		self:_showWallpaper('wallpaper')
	end
	
	-- Never free this applet
	return false
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

