
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
local pairs, ipairs, tostring      = pairs, ipairs, tostring

local oo                 = require("loop.simple")

local Applet             = require("jive.Applet")
local AppletManager      = require("jive.AppletManager")
local SimpleMenu         = require("jive.ui.SimpleMenu")
local RadioGroup         = require("jive.ui.RadioGroup")
local RadioButton        = require("jive.ui.RadioButton")
local Window             = require("jive.ui.Window")
local Group              = require("jive.ui.Group")
local Icon               = require("jive.ui.Icon")
local Label              = require("jive.ui.Label")
local Framework          = require("jive.ui.Framework")

local log                = require("jive.utils.log").logger("applets.setup")
local debug              = require("jive.utils.debug")

local jiveMain           = jiveMain
local jnt                = jnt

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP

-- load SetupWallpaper for use in previewing Wallpapers
local SetupWallpaper = AppletManager:loadApplet("SetupWallpaper")

module(...)
oo.class(_M, Applet)


function init(self, ...)
	self.playerItem = {}
	jnt:subscribe(self)

	self:manageSelectPlayerMenu()
end

function notify_playerDelete(self, playerObj)
	local playerMac = playerObj.id
	manageSelectPlayerMenu(self)
	if self.playerMenu and self.playerItem[playerMac] then
		self.playerMenu:removeItem(self.playerItem[playerMac])
		self.playerItem[playerMac] = nil
	end
end

function notify_playerNew(self, playerObj)
	-- get number of players. if number of players is > 1, add menu item
	local playerMac = playerObj.id

	manageSelectPlayerMenu(self)
	if self.playerMenu then
		self:_addPlayerItem(playerObj)
	end
end

function notify_playerCurrent(self, playerObj)
	self.selectedPlayer = playerObj
	self:manageSelectPlayerMenu()
end

function manageSelectPlayerMenu(self)
        local sdApplet = AppletManager:getAppletInstance("SlimDiscovery")
	local _numberOfPlayers = sdApplet and sdApplet:countPlayers() or 0

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
		-- FIXME, this probably won't work quite right with new main menu code
		jiveMain:removeItem(self.selectPlayerMenuItem)
		self.selectPlayerMenuItem = nil
	end
end

function _addPlayerItem(self, player)
	local playerMac = player.id
	local playerName = player.name

	log:warn("_addPlayerItem")
	local item = {
		text = playerName,
		sound = "WINDOWSHOW",
		callback = function()
				   self:selectPlayer(player)
				   self.setupNext()
			   end,
		focusGained = function(event)
			self:_showWallpaper(playerMac)
		end,
		weight =  1
	}
	self.playerMenu:addItem(item)
	self.playerItem[playerMac] = item
	
	if self.selectedPlayer == player then
		self.playerMenu:setSelectedItem(item)
	end
end

function _showWallpaper(self, playerId)
	log:info("previewing background wallpaper for ", playerId)
	SetupWallpaper:_setBackground(nil, playerId)
end

function setupShow(self, setupNext)
	-- get list of slimservers
	local window = Window("window", self:string("SELECT_PLAYER"), 'settingstitle')
	window:setAllowScreensaver(false)

        local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	self.playerMenu = menu
	self.setupNext = setupNext or 
		function()
			window:hide(Window.transitionPushLeft)
		end

        local sdApplet = AppletManager:getAppletInstance("SlimDiscovery")
        if not sdApplet then
		return
	end

	self.selectedPlayer = sdApplet:getCurrentPlayer()
	for playerMac, playerObj in sdApplet:allPlayers() do
		_addPlayerItem(self, playerObj)
	end

	-- Bug 6130 add a Set up Squeezebox option
	local sbsetup = AppletManager:loadApplet("SetupSqueezebox")
	if sbsetup then
		self.playerMenu:addItem({
					text = self:string("SQUEEZEBOX_SETUP"),
					sound = "WINDOWSHOW",
					callback = function()
							   sbsetup:settingsShow()
						   end,
					weight =  10
				})
	end

	--[[
	-- no player for debugging
	self.playerMenu:addItem({
					text = "NO PLAYER (DEBUG)",
					sound = "WINDOWSHOW",
					callback = function()
							   self:selectPlayer(nil)
							   self.setupNext()
						   end,
					weight =  9
				})
	--]]

	window:addWidget(menu)

	sdApplet:discover()
	window:addTimer(1000, function() sdApplet:discover() end)

	self:tieAndShowWindow(window)
	return window
end

function selectPlayer(self, player)
	log:warn("Selected player is now ", player)

	local manager = AppletManager:getAppletInstance("SlimDiscovery")
	if manager then
		manager:setCurrentPlayer(player)
	end

	return true
end

function free(self)

	-- load the correct wallpaper on exit
	self:_showWallpaper(self.selectedPlayer.id)
	
	AppletManager:freeApplet("SetupWallpaper")
	-- Never free this applet
	return false
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

