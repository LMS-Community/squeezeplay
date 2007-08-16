
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
local oo                 = require("loop.simple")
local pairs, ipairs, tostring      = pairs, ipairs, tostring

local Applet             = require("jive.Applet")
local AppletMeta         = require("jive.AppletMeta")
local SimpleMenu         = require("jive.ui.SimpleMenu")
local RadioGroup         = require("jive.ui.RadioGroup")
local RadioButton        = require("jive.ui.RadioButton")
local Window             = require("jive.ui.Window")
local Label              = require("jive.ui.Label")
local appletManager      = appletManager
local jiveMain           = jiveMain
local jnt                = jnt

local log                = require("jive.utils.log").logger("applets.browser")
local debug              = require("jive.utils.debug")

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP

module(...)
oo.class(_M, Applet)

function init(self, ...)
--	jiveMain.window:setTitle('Testing')
	-- TODO get currentPlayer from SlimDiscovery instead of from SelectPlayer
	self.selectedPlayer = self:getSettings()["selectedPlayer"]
	self.playerList = {}
	jnt:subscribe(self)
end

function notify_playerDelete(self, playerObj)
	local playerMac = playerObj.id
	self.playerList[playerMac] = nil
	manageSelectPlayerMenu(self)
	if self.playerMenu and self.playerItem[playerMac] then
		self.playerMenu:removeItem(self.playerItem[playerMac])
		self.playerItem[playerMac] = nil
	end
end

function notify_playerNew(self, playerObj)
	-- get number of players. if number of players is > 1, add menu item
	local playerMac = playerObj.id
	local playerName = playerObj.name
	self.playerList[playerMac] = playerName
	-- if there isn't a selected player, make this one the selected player
	if (self.selectedPlayer == nil) then
		self:selectPlayer(playerMac)
	end
	manageSelectPlayerMenu(self)
	if self.playerMenu then
		self:_addPlayerItem(playerObj)
	end
end

function manageSelectPlayerMenu(self)
	local _numberOfPlayers = numberOfPlayers(self.playerList)
	-- if _numberOfPlayers is > 1 and selectPlayerMenuItem doesn't exist, create it
	if (_numberOfPlayers > 1 and self.selectPlayerMenuItem == nil) then
		local menuItem = {
			text = self:string("SELECT_PLAYER"),
			callback = function(_, ...) self:getPlayers(...) end,
			}
		jiveMain:addItem(menuItem, 900)
		self.selectPlayerMenuItem = menuItem
	end
	-- if numberOfPlayers < 2 and selectPlayerMenuItem exists, get rid of it
	if (_numberOfPlayers < 2 and self.selectPlayerMenuItem) then
		jiveMain:removeItem(self.selectPlayerMenuItem)
		self.selectPlayerMenuItem = nil
	end
end

function numberOfPlayers(playerList)
	local numberOfPlayers = 0
	for k,v in pairs(playerList) do
		numberOfPlayers = numberOfPlayers + 1
	end
	return numberOfPlayers
end

function _addPlayerItem(self, player)
	local playerMac = player.id
	local playerName = player.name
	log:warn('player:|', playerMac, '|', playerName)
	-- display as radio selections
	local button = RadioButton(
		"radio", 
		self.radioGroup, 
		function() self:selectPlayer(playerMac) end,
		playerMac == self.selectedPlayer
	)
	local item = {
		text = playerName,
		icon = button,
	}
	self.playerMenu:addItem(item)
	--self.playerItems[playerMac] = item
end

function getPlayers(self)
	-- get list of slimservers
	-- local slimServers = appletManager:getApplet("SlimDiscovery"):getSlimservers():servers()
	local window = Window("window", self:string("SELECT_PLAYER"))
        local menu = SimpleMenu("menu")
        local group = RadioGroup()
	self.playerMenu = menu
	self.radioGroup = group
	-- TODO, get the selectedPlayer from SlimDiscovery
	self.selectedPlayer = self:getSettings()["selectedPlayer"]
        local sdApplet = appletManager:getAppletInstance("SlimDiscovery")
        if sdApplet then
		for playerMac, playerObj in sdApplet:allPlayers() do
			_addPlayerItem(self, playerObj)
		end
	else
		return
	end

	window:addWidget(menu)
	-- Store the selected player when the menu is exited
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
			self.playerMenu = nil
		end
	)
	self:tieAndShowWindow(window)
	return window
end

function selectPlayer(self, playerMac)
	log:warn("Selected player is now ", playerMac)
	-- TODO set currentPlayer in SlimDiscovery
	self:getSettings()["selectedPlayer"] = playerMac
	return true
end

function free(self)
        log:debug("SelectPlayer:free()")
        jnt:unsubscribe(self)
	return true
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

