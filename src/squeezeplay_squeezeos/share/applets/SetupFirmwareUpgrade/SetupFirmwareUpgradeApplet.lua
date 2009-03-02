

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring, type = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring, type

local oo                     = require("loop.simple")

local math                   = require("math")
local string                 = require("string")
local table                  = require("jive.utils.table")
local socket                 = require("socket")
local lfs                    = require("lfs")
local os                     = require("os")
local coroutine               = require("coroutine")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
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

local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE


local MEDIA_PATH = "/media/"

module(..., Framework.constants)
oo.class(_M, Applet)


function _firmwareVersion(self, url)
	local machine = System:getMachine()

	local major, minor = string.match(url, "\/" .. machine .. "_([^_]+)_([^_]+)\.bin")

	if not major then
		return
	end

	return major .. " " .. minor
end


-- return 0 if version are same, +ive if upgrade, -ive if downgrade
function _versionCompare(a, b)
	if not a or not b then
		return math.huge
	end

	local aMajor, aMinor = string.match(a, "(.+) r(%d+)")
	local bMajor, bMinor = string.match(b, "(.+) r(%d+)")

	if not aMajor or not bMajor or aMajor ~= bMajor then
		return math.huge
	end

	return bMinor - aMinor
end


function _findUpgrades(self, url, urlHelp)
	local upgrades = {}

	local machine = System:getMachine()

	if url and string.match(url, machine) then
		local version = self:_firmwareVersion(url)
		upgrades[#upgrades + 1] = {		
			url = url,
			version = version,
			help = urlHelp,
		}
	end

	for media in lfs.dir(MEDIA_PATH) do
		local path = MEDIA_PATH .. media .. "/"

		for entry in lfs.dir(path) do
			local url = "file:" .. path .. entry
			local version = self:_firmwareVersion(url)
	
			if version or entry == machine .. ".bin" then
				upgrades[#upgrades + 1] = {
					url = url,
					version = version,
				}			
			end
		end
	end

	return upgrades
end


function _helpString(self, upgrade)
	local helpString = upgrade.help
	if not helpString then
		if string.match(upgrade.url, "file:") then
			helpString = self:string("UPDATE_BEGIN_REMOVABLE_MEDIA", version or "")
		else
			if _versionCompare(JIVE_VERSION, upgrade.version) <= 0 then
				helpString = self:string(upgrade.help or "UPDATE_BEGIN_REINSTALL", version or "?")
			else
				helpString = self:string(upgrade.help or "UPDATE_BEGIN_UPGRADE", version or "?")
			end
		end
	end

	return helpString
end


function _upgradeWindow(self, upgrades, optional)
	if #upgrades == 1 then
		return _upgradeWindowSingle(self, upgrades, optional)
	else
		return _upgradeWindowChoice(self, upgrades, optional)
	end
end


function _upgradeWindowSingle(self, upgrades, optional)
	local window = Window("one_button", self:string("UPDATE"), 'settingstitle')

	window:setButtonAction("rbutton", nil)

	local text = Textarea("text", _helpString(self, upgrades[1]))

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("BEGIN_UPDATE"),
		sound = "WINDOWSHOW",
		callback = function()
			self:_upgrade(upgrades[1].url)
		end,
	})

	window:addWidget(text)
	window:addWidget(menu)

	if not optional then
		-- forced upgrade, don't allow the user to break out
		window:setAllowScreensaver(false)

		window:setButtonAction("lbutton", nil)
		menu:setCloseable(false)

		window:addListener(EVENT_KEY_PRESS,
			function(event)
				local keycode = event:getKeycode()
				if keycode == KEY_HOME then
					return EVENT_CONSUME
				end

				return EVENT_UNUSED
			end)
	end

	self:tieAndShowWindow(window)
end


function _upgradeWindowChoice(self, upgrades, optional)
	local window = Window("text_list", self:string("UPDATE"), 'settingstitle')
	local helptext = Textarea("helptext", "")
	local menu = SimpleMenu("menu")

	for i,upgrade in ipairs(upgrades) do
		local itemString
		if string.match(upgrade.url, "file:") then
			if upgrade.version then
				itemString = self:string("UPDATE_TO_X", upgrade.version)
			else
				itemString = self:string("UPDATE_FROM_REMOVABLE_MEDIA")
			end
		else
			itemString = self:string("BEGIN_UPDATE")
		end

		local helpString = _helpString(self, upgrade)

		menu:addItem({
			text = itemString,
			sound = "WINDOWSHOW",
			callback = function()
				self:_upgrade(upgrade.url)
			end,
			focusGained = function()
				helptext:setValue(helpString)
			end,			
		})
	end

	window:addWidget(helptext)
	window:addWidget(menu)

	if not optional then
		-- forced upgrade, don't allow the user to break out
		window:setAllowScreensaver(false)

		window:setButtonAction("lbutton", nil)
		menu:setCloseable(false)

		window:addListener(EVENT_KEY_PRESS,
			function(event)
				local keycode = event:getKeycode()
				if keycode == KEY_HOME then
					return EVENT_CONSUME
				end

				return EVENT_UNUSED
			end)
	else
		menu:addItem({
			text = self:string("UPDATE_CANCEL"),
			sound = "WINDOWHIDE",
			callback = function()
				window:hide()
			end,
			focusGained = function()
				helptext:setValue(nil)
			end
		})
	end

	self:tieAndShowWindow(window)
end


function forceUpgrade(self, optional, url, urlHelp)
	if not url then
		url = upgradeUrl[1]
	end
	if not url then
		return
	end

	local upgrades = _findUpgrades(self, url, urlHelp)

	return _upgradeWindow(self, upgrades, optional)
end


function settingsShow(self)
	local url = upgradeUrl[1] or false

	local upgrades = _findUpgrades(self, url)

	return _upgradeWindow(self, upgrades, true)
end


function _checkBattery()
	if hasBSP then
		return BSP.ioctl(23) == 0 or BSP.ioctl(17) > 830
	else
		return true
	end
end


function _chargeBattery(self)
	local window = Window("text_list", self:string("UPDATE_BATTERY"), firmwareupgradeTitleStyle)

	local menu = SimpleMenu("menu", {
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

	local help = Textarea("helptext", self:string("UPDATE_BATTERY_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _t_setText(self, done, msg, count)
	if type(count) == "number" then
		self.counter:setValue(count .. "%")
		self.progress:setRange(1, 100, count)

		if not self.progress:getParent() then
			self.popup:addWidget(self.progress)
		end
	else
		self.counter:setValue("")

		if self.progress:getParent() then
			self.popup:removeWidget(self.progress)
		end
	end

	self.text:setValue(self:string(msg))

	--if done then
	--	self.icon:setStyle("icon_connected")
	--end
end

function _t_upgrade(self)
	Task:yield(true)

	local upgrade = Upgrade()
	local t, err = upgrade:start(self.url,
		function(...)
			self:_t_setText(...)
		end)

	if not t then
		-- error
		log:error("Upgrade failed: ", err)
		self:_upgradeFailed():showInstead()

		if self.popup then
			self.popup:hide()
			self.popup = nil
		end
	end
end


function _upgrade(self, url)
	self.url = url

	-- require ac power or sufficient battery to continue
	if not _checkBattery() then
		return self:_chargeBattery()
	end

	self.popup = Popup("update")

	-- don't allow power saving during upgrades
	self.popup:setAllowPowersave(false)

	self.icon = Icon("icon_software_update")
	self.popup:addWidget(self.icon)

	self.text = Label("text", self:string("UPDATE_DOWNLOAD", ""))
	self.counter = Label("subtext", "")
	self.progress = Slider("progress", 1, 100, 1)

	self.popup:addWidget(self.text)
	self.popup:addWidget(self.counter)

	-- make sure this popup remains on screen
	self.popup:setAllowScreensaver(false)
	self.popup:setAlwaysOnTop(true)
	self.popup:setAutoHide(false)
	self.popup:setTransparent(false)

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
	appletManager:callService("disconnectPlayer")

	-- start the upgrade
	Task("upgrade", self, _t_upgrade, _upgradeFailed):addTask()

	self:tieAndShowWindow(self.popup)
	return window
end


function _upgradeFailed(self)
	-- unblock keys
	Framework:removeListener(self.upgradeListener)
	self.upgradeListener = nil

	-- reconnect to server
	appletManager:callService("connectPlayer")

	local window = Window("text_list", self:string("UPDATE_FAILURE"))

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

	local help = Textarea("helptext", self:string("UPDATE_FAILURE_HELP"))
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
