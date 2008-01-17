
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
local AppletManager      = require("jive.AppletManager")
local SimpleMenu         = require("jive.ui.SimpleMenu")
local RadioGroup         = require("jive.ui.RadioGroup")
local RadioButton        = require("jive.ui.RadioButton")
local Window             = require("jive.ui.Window")
local Group              = require("jive.ui.Group")
local Icon               = require("jive.ui.Icon")
local Label              = require("jive.ui.Label")
local Framework          = require("jive.ui.Framework")

local SocketUdp          = require("jive.net.SocketUdp")
local udap               = require("jive.net.Udap")

local log                = require("jive.utils.log").logger("applets.setup")
local debug              = require("jive.utils.debug")

local jiveMain           = jiveMain
local jnt                = jnt

local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_ACTIVE = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE = jive.ui.EVENT_WINDOW_INACTIVE

-- load SetupWallpaper for use in previewing Wallpapers
local SetupWallpaper = AppletManager:loadApplet("SetupWallpaper")

module(...)
oo.class(_M, Applet)


function init(self, ...)
	self.playerItem = {}
	self.scanResults = {}

	jnt:subscribe(self)
	self:manageSelectPlayerMenu()
end


function notify_playerDelete(self, playerObj)
	local mac = playerObj.id
	manageSelectPlayerMenu(self)
	if self.playerMenu and self.playerItem[mac] then
		self.playerMenu:removeItem(self.playerItem[mac])
		self.playerItem[mac] = nil
	end
end


function notify_playerNew(self, playerObj)
	-- get number of players. if number of players is > 1, add menu item
	local mac = playerObj.id

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


function _unifyMac(mac)
	return string.upper(string.gsub(mac, "[^%x]", ""))
end


function _addPlayerItem(self, player)
	local mac = player.id
	local playerName = player.name

	local item = {
		id = _unifyMac(mac),
		text = playerName,
		sound = "WINDOWSHOW",
		callback = function()
				   self:selectPlayer(player)
				   self.setupNext()
			   end,
		focusGained = function(event)
			self:_showWallpaper(mac)
		end,
		weight =  1
	}
	self.playerMenu:addItem(item)
	self.playerItem[mac] = item
	
	if self.selectedPlayer == player then
		self.playerMenu:setSelectedItem(item)
	end
end


-- add a squeezebox discovered using udap or an adhoc network
function _addSqueezeboxItem(self, mac, name, adhoc)
	local item = {
		id = _unifyMac(mac),
		text = name or self:string("SQUEEZEBOX_NAME", string.sub(mac, 7)),
		sound = "WINDOWSHOW",
		callback = function()
				   log:error("SETUP SQUEEZEBOX")
				   --self.setupNext()
			   end,
		focusGained = function(event)
			self:_showWallpaper(nil)
		end,
		weight =  1
	}
	self.playerMenu:addItem(item)
	self.playerItem[mac] = item
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

        self.discovery = AppletManager:getAppletInstance("SlimDiscovery")
        if not self.discovery then
		return
	end

	self.selectedPlayer = self.discovery:getCurrentPlayer()
	for mac, playerObj in self.discovery:allPlayers() do
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

	window:addWidget(menu)

	window:addTimer(1000, function() self:_scan() end)


	window:addListener(EVENT_WINDOW_ACTIVE,
			   function()
				   self:_scanActive()
				   self:_scan()
			   end)

	window:addListener(EVENT_WINDOW_INACTIVE,
			   function()
				   self:_scanInactive()
			   end)

	self:tieAndShowWindow(window)
	return window
end


function _scanActive(self)
	-- socket for udap discovery
	if not self.socket then
		self.socket = assert(SocketUdp(jnt, function(chunk, err)
							    self:_udapSink(chunk, err)
						    end))
	end
end


function _scanInactive(self)
	self.socket:close()
	self.socket = nil
end


function _udapSink(self, chunk, err)
	if chunk == nil then
		return -- ignore errors
	end

	local pkt = udap.parseUdap(chunk.data)

	if pkt.uapMethod ~= "adv_discover"
		or pkt.ucp.device_status ~= "wait_slimserver"
		or pkt.ucp.type ~= "squeezebox" then
		-- we are only looking for squeezeboxen trying to connect to SC
		return
	end

	local mac = pkt.source
	local name = pkt.ucp.name
	if not self.scanResults[mac] then
		self.scanResults[mac] = {
			lastScan = os.time(),
			udap = true,
		}

		self:_addSqueezeboxItem(mac, name, nil)
	end
end


function _scan(self)
	-- SqueezeCenter and player discovery
	self.discovery:discover()

	-- udap discovery
	local packet = udap.createAdvancedDiscover(nil, 1)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)

	-- remove squeezeboxen not seen for 10 seconds
	local now = os.time()
	for mac, entry in pairs(self.scanResults) do
		if os.difftime(now, entry.lastScan) > 10 then
			self.playerMenu:removeItem(self.playerItem[mac])
			self.playerItem[mac] = nil
			self.scanResults[mac] = nil
		end
	end
end


function selectPlayer(self, player)
	log:info("Selected player=", player)

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

