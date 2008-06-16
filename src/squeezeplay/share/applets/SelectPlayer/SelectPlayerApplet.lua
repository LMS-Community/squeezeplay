
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

local hasWireless, Wireless  = pcall(require, "jive.net.Wireless")

local log                = require("jive.utils.log").logger("applets.setup")
local debug              = require("jive.utils.debug")

local SetupSqueezeboxApplet = require("applets.SetupSqueezebox.SetupSqueezeboxApplet")

local jnt                = jnt
local jiveMain           = jiveMain
local appletManager      = appletManager

-- load SetupWallpaper for use in previewing Wallpapers
local SetupWallpaper = appletManager:loadApplet("SetupWallpaper")

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
	local mac = player.id

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
	local mac = player.id

	manageSelectPlayerMenu(self)

	if self.playerMenu then
		self:_addPlayerItem(player)

		if player:getSlimServer() then
			self:_updateServerItem(player:getSlimServer())
		end
	end
end


function notify_playerCurrent(self, player)
	if self.playerMenu then
		self.selectedPlayer = player
		self:manageSelectPlayerMenu()
	end
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

	-- if _numberOfPlayers is > 1 and selectPlayerMenuItem doesn't exist, create it

	if _numberOfPlayers > 1 or not self.selectedPlayer then
		if not self.selectPlayerMenuItem then
			local menuItem = {
				id = 'selectPlayer',
				node = 'home',
				text = self:string("SELECT_PLAYER"),
				sound = "WINDOWSHOW",
				callback = function() self:setupShow() end,
				weight = 80
			}
			jiveMain:addItem(menuItem)
			self.selectPlayerMenuItem = menuItem
		end

	-- if numberOfPlayers < 2 and selectPlayerMenuItem exists, get rid of it
	elseif _numberOfPlayers < 2 and self.selectPlayerMenuItem then
		jiveMain:removeItemById('selectPlayer')
		self.selectPlayerMenuItem = nil
	end
end


function _addPlayerItem(self, player)
	local mac = player:getId()
	local playerName = player:getName()
	local playerWeight = PLAYER_WEIGHT

	-- if waiting for a SN pin modify name
	if player:getPin() then
		if not self.setupMode then
			-- Only include Activate SN during setup
			return
		end

		playerName = self:string("SQUEEZEBOX_ACTIVATE", player.name)
		playerWeight = ACTIVATE_WEIGHT
	end

	local item = {
		id = mac,
		text = playerName,
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

	if player == self.selectedPlayer then
		item.style = "checked"
	end

	self.playerMenu:addItem(item)
	self.playerItem[mac] = item
	
	if self.selectedPlayer == player then
		self.playerMenu:setSelectedItem(item)
	end
end


function _refreshPlayerItem(self, player)
	local mac = player.id

	-- XXXX
	if player:isAvailable() then
		local item = self.playerItem[mac]
		if not item then
			-- add player
			self:_addPlayerItem(player)

		else
			-- update player state
			if player == self.selectedPlayer then
				item.style = "checked"
			else
				item.style = nil
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
			local auth = appletManager:loadApplet("HttpAuth")
			auth:squeezeCenterPassword(server)
		end,
		weight = SERVER_WEIGHT,
	}

	self.playerMenu:addItem(item)
	self.serverItem[id] = item
end


function _showWallpaper(self, playerId)
	log:info("previewing background wallpaper for ", playerId)
	SetupWallpaper:showBackground(nil, playerId)
end


function setupShow(self, setupNext)
	-- get list of slimservers
	local window = Window("window", self:string("SELECT_PLAYER"), 'settingstitle')
	window:setAllowScreensaver(false)

        local menu = SimpleMenu("menu")
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
	local sbsetup = appletManager:loadApplet("SetupSqueezebox")
	if sbsetup and setupNext then
		self.playerMenu:addItem({
			text = self:string("SQUEEZEBOX_SETUP"),
			sound = "WINDOWSHOW",
			callback = function()
				sbsetup:settingsShow()
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
		local snpin = appletManager:loadApplet("SqueezeNetworkPIN")
		snpin:enterPin(nil, player)

		return false
	end

	-- set the current player
	appletManager:callService("setCurrentPlayer", player)

	-- network configuration needed?
	if player:needsNetworkConfig() then
		-- XXXX convert to applet service call
		local sbsetup = appletManager:loadApplet("SetupSqueezebox")
		sbsetup:startSqueezeboxSetup(player:getId(),
					     player:getSSID(),
					     function()
						     jiveMain:closeToHome()
					     end)
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
	jnt:unsubscribe(self)

	-- load the correct wallpaper on exit
	if self.selectedPlayer and self.selectedPlayer:getId() then
		self:_showWallpaper(self.selectedPlayer:getId())
	else
		self:_showWallpaper('wallpaper')
	end
	
	appletManager:freeApplet("SetupWallpaper")

	-- Never free this applet
	return false
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

