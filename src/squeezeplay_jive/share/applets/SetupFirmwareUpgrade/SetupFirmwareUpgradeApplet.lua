

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")
local socket                 = require("socket")
local lfs                    = require("lfs")
local os                     = require("os")
local coroutine               = require("coroutine")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local Upgrade                = require("applets.SetupFirmwareUpgrade.Upgrade")
local hasBSP, BSP            = pcall(require, "jiveBSP")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt
local appletManager          = appletManager
local upgradeUrl             = upgradeUrl

local JIVE_VERSION           = jive.JIVE_VERSION

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local EVENT_ALL_INPUT        = jive.ui.EVENT_ALL_INPUT
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD         = jive.ui.EVENT_KEY_HOLD
local EVENT_WINDOW_ACTIVE    = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_FWD         = jive.ui.KEY_FWD
local KEY_REW         = jive.ui.KEY_REW
local KEY_GO          = jive.ui.KEY_GO
local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_RIGHT       = jive.ui.KEY_RIGHT
local KEY_HOME        = jive.ui.KEY_HOME

local firmwareupgradeTitleStyle = 'settingstitle'

local DEFAULT_FIRMWARE_URL = "http://www.slimdevices.com/update/firmware/7.0/jive.bin"

local SDCARD_PATH = "/mnt/mmc/"

module(...)
oo.class(_M, Applet)


function _firmwareVersion(self, url)

	log:warn("url=", url)

	local major, minor = string.match(url, "jive_([^_]+)_([^_]+)\.bin")

	if not major then
		return
	end

	return major .. " " .. minor
end


function _makeUpgradeItems(self, window, menu, url)
	local help = Textarea("help", "")

	local version = self:_firmwareVersion(url)
	menu:addItem({
		text = self:string("BEGIN_UPDATE"),
		sound = "WINDOWSHOW",
		callback = function()
			self.url = url
			self:_upgrade()
		end,
		focusGained = function()
			if version == JIVE_VERSION then
				help:setValue(self:string("UPDATE_BEGIN_REINSTALL", version or "?"))
			else
				help:setValue(self:string("UPDATE_BEGIN_UPGRADE", version or "?"))
			end
		end
	})

	for entry in lfs.dir(SDCARD_PATH) do
		local fileurl = "file:" .. SDCARD_PATH .. entry
		local version = self:_firmwareVersion(fileurl)
	
		if version or entry == "jive.bin" then
			menu:addItem({
				     text = self:string("UPDATE_CONTINUE_SDCARD"),
				     sound = "WINDOWSHOW",
				     callback = function()
							self.url = fileurl
							self:_upgrade()
						end,
				     focusGained = function()
							   help:setValue(self:string("UPDATE_BEGIN_SDCARD", version or ""))
						   end
			     })
		end
	end

	window:addWidget(help)
	window:addWidget(menu)
end


function forceUpgrade(self, upgUrl)
	local window = Window("window", self:string("UPDATE"), firmwareupgradeTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	menu:setCloseable(false)

	local url = upgUrl
	if not upgUrl then
		url = upgradeUrl[1]
	end
	if not url then
		url = DEFAULT_FIRMWARE_URL
	end

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   local keycode = event:getKeycode()
				   if keycode == KEY_HOME then
					   return EVENT_CONSUME
				   end

				   return EVENT_UNUSED
			   end)

	self:_makeUpgradeItems(window, menu, url)

	self:tieAndShowWindow(window)
	return window
end


function settingsShow(self)
	local window = Window("window", self:string("UPDATE"), firmwareupgradeTitleStyle)

	local menu = SimpleMenu("menu")

	local url = upgradeUrl[1]
	if not url then
		url = DEFAULT_FIRMWARE_URL
	end

	self:_makeUpgradeItems(window, menu, url)

	self:tieAndShowWindow(window)
	return window
end


function _checkBattery()
	if hasBSP then
		return BSP.ioctl(23) == 0 or BSP.ioctl(17) > 830
	else
		return true
	end
end


function _chargeBattery(self)
	local window = Window("window", self:string("UPDATE_BATTERY"), firmwareupgradeTitleStyle)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("CONTINUE"),
						sound = "WINDOWSHOW",
						callback = function()
								   if _checkBattery() then
									   self:_upgrade()
								   else
									   window:bumpRight()
								   end
							   end
					}
				})

	local help = Textarea("help", self:string("UPDATE_BATTERY_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _t_setText(self, done, msg, count)
	self.counter:setValue(count or "")
	self.textarea:setValue(self:string(msg))
	if done then
		self.icon:setStyle("iconConnected")
	end
end

function _t_upgrade(self)
	Task:yield(true)

	local t, err = self.upgrade:start(function(...)
						  self:_t_setText(...)
					  end)

	if t == nil then
		-- error
		self:_upgradeFailed():showInstead()
	end
end


function _upgrade(self)
	-- require ac power or sufficient battery to continue
	if not _checkBattery() then
		return self:_chargeBattery()
	end

	local popup = Popup("popupIcon")

	self.icon = Icon("iconConnecting")
	popup:addWidget(self.icon)

	self.counter = Label("text", "")
	self.textarea = Label("text", self:string("UPDATE_DOWNLOAD", ""))
	popup:addWidget(self.counter)
	popup:addWidget(self.textarea)

	-- make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)

	-- no way to exit this popup
	self.upgradeListener =
		Framework:addListener(EVENT_ALL_INPUT,
				      function()
					      Framework.wakeup()
					      return EVENT_CONSUME
				      end,
				      true)

	-- disconnect from SqueezeCenter, we don't want to up
	-- interrupted during the firmware upgrade.
	local slimDiscovery = appletManager:loadApplet("SlimDiscovery")
	slimDiscovery.serversObj:disconnect()

	-- start the upgrade
	self.upgrade = Upgrade(self.url)
	Task("upgrade", self, _t_upgrade, _upgradeFailed):addTask()

	self:tieAndShowWindow(popup)
	return window
end


function _upgradeFailed(self)
	-- unblock keys
	Framework:removeListener(self.upgradeListener)
	self.upgradeListener = nil

	-- reconnect to server
	local slimDiscovery = appletManager:loadApplet("SlimDiscovery")
	slimDiscovery.serversObj:connect()

	local window = Window("window", self:string("UPDATE_FAILURE"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("UPDATE_TRY_AGAIN"),
						sound = "WINDOWSHOW",
						callback = function()
								   if _checkBattery() then
									   window:hide()
									   self:_upgrade()

								   else
									   window:bumpRight()
								   end
							   end
					}
				})

	local help = Textarea("help", self:string("UPDATE_FAILURE_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
