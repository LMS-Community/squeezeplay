

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring, type = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring, type

local oo                     = require("loop.simple")

local io                     = require("io")
local math                   = require("math")
local string                 = require("jive.utils.string")
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

local debug                  = require("jive.utils.debug")

local jnt                    = jnt
local jiveMain               = jiveMain
local appletManager          = appletManager

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
local STOP_SERVER_TIMEOUT = 10


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	jnt:subscribe(self)

end


function notify_firmwareAvailable(self, server)
        local url, force = server:getUpgradeUrl()

        if force and not url then
                log:warn("sometimes force is true but url is nil, seems like a server bug: server:", server)
        end
        if force and url then
                local player = appletManager:callService("getCurrentPlayer")

                if player and player:getSlimServer() == server then
			self:firmwareUpgrade(server)
                end
        end
end


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


function _findServerUpgrade(self, url, urlHelp, server)

	local machine = System:getMachine()

	if url and string.match(url, machine) then
		local version = self:_firmwareVersion(url)
		log:info("Adding to Upgrades: ", url, " version: ", version)
		local serverName = server and server:getName() or nil
		return {
			url = url,
			version = version,
			help = urlHelp,
			serverName = serverName,
		}
	end

	return nil
end


function _findUpgrades(self, url, urlHelp, server)
	local upgrades = {}

	local machine = System:getMachine()

	if not url then
		--no specific url given means gather from discovered SCs
	                for _,server in appletManager:callService("iterateSqueezeCenters") do
                		local scUrl = server:getUpgradeUrl()
                		log:info("\t", server, "\t url: ", scUrl)
                		local upgrade = _findServerUpgrade(self, scUrl, urlHelp, server)
                		if upgrade then
	                		upgrades[#upgrades + 1] = upgrade
	                	end
                	end

	else
		upgrades[#upgrades + 1] = _findServerUpgrade(self, url, urlHelp, server)
	end

	for media in lfs.dir(MEDIA_PATH) do
		local path = MEDIA_PATH .. media .. "/"

		local attrs = lfs.attributes(path)
		if attrs and attrs.mode == "directory" then

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
	end

	return upgrades
end


function mmFindFirmware(self, devName)
	local upgradePresent = false
	local path = MEDIA_PATH .. devName .. "/"
	local machine = System:getMachine()

	local attrs = lfs.attributes(path)
	if attrs and attrs.mode == "directory" then
		for entry in lfs.dir(path) do
			local url = "file:" .. path .. entry
			local version = self:_firmwareVersion(url)

			if version or entry == machine .. ".bin" then
				log:info('Firmware update detected on ', path)
				upgradePresent = true
-- Bug 15741 - media ejection SD and USB unreliable
-- Do not use 'break' to end directory iterator early but let it run to the very end.
-- Allowing that actively closes the directory so a subsequent 'umount' is less likely to fail.
-- (BTW: There is a close() function in lfs 1.5, but not in lfs 1.2 we are currently using.)
--				break
			end
		end
	end

	return upgradePresent
end


function _helpString(self, upgrade)
	local helpString = upgrade.help
	if not helpString then
		if string.match(upgrade.url, "file:") then
			helpString = self:string("UPDATE_BEGIN_REMOVABLE_MEDIA", upgrade.version or "")
		else
			if _versionCompare(JIVE_VERSION, upgrade.version) <= 0 then
				helpString = self:string(upgrade.help or "UPDATE_BEGIN_REINSTALL", upgrade.version or "?")
			else
				helpString = self:string(upgrade.help or "UPDATE_BEGIN_UPGRADE", upgrade.version or "?")
			end
		end
	end

	return helpString
end


function _upgradeWindow(self, upgrades, optional, disallowScreensaver)
	local window
	if #upgrades == 1 then
		window = _upgradeWindowSingle(self, upgrades, optional, disallowScreensaver)
	else
		window = _upgradeWindowChoice(self, upgrades, optional, disallowScreensaver)
	end

	self:tieWindow(window)
	window:showAfterScreensaver()
end


function _upgradeWindowSingle(self, upgrades, optional, disallowScreensaver)
	local window = Window("help_list", self:string("UPDATE"), 'settingstitle')
	window:setButtonAction("rbutton", "help")

	local text = Textarea("help_text", _helpString(self, upgrades[1]))

	local menu = SimpleMenu("menu")

	local itemString = self:string("BEGIN_UPDATE")
	itemString = itemString.str or itemString
	if upgrades[1].version then
		itemString = itemString .. " (" .. upgrades[1].version .. ")"
	end
	menu:addItem({
		text = itemString,
		sound = "WINDOWSHOW",
		callback = function()
			self:_upgrade(upgrades[1].url)
		end,
	})
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)

	menu:setHeaderWidget(text)
	window:addWidget(menu)

	if disallowScreensaver then
		--disallowScreensaver regardless of optional state (useful when coming down this path during this path: setup->diagnostics->FW update
		window:setAllowScreensaver(false)
	end

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

	return window
end


function _upgradeWindowChoice(self, upgrades, optional, disallowScreensaver)
	local window = Window("text_list", self:string("UPDATE"), 'settingstitle')
	window:setButtonAction("rbutton", "help")

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
			itemString = itemString.str or itemString
			if upgrade.version then
				itemString = itemString .. " (" .. upgrade.version .. ")"
			end
			if upgrade.serverName then
				itemString = itemString .. " - [" .. upgrade.serverName .. "]"
			end

		end

		menu:addItem({
			text = itemString,
			sound = "WINDOWSHOW",
			callback = function()
				self:_upgrade(upgrade.url)
			end,
		})
	end

	window:addWidget(menu)

	if disallowScreensaver then
		--disallowScreensaver regardless of optional state (useful when coming down this path during this path: setup->diagnostics->FW update
		window:setAllowScreensaver(false)
	end

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
		})
	end
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)

	return window
end

--service method
function firmwareUpgrade(self, server, optionalForScDiscoveryMode)
	
	if self.updating then
		log:info("Update is already running... please don't disturb!")
		return
	end

	local upgrades, force, disallowScreensaver
	if not server then
		-- in "SC Discovery Mode"
		log:info("firmware upgrade from discovered SCs")
		upgrades = _findUpgrades(self, nil)
		if optionalForScDiscoveryMode then
			--used for diagnostics page (which offers a FW upgrade page and is offerred during setup, so SS must not work)
			force = false
			disallowScreensaver = true
		else
			force = true
		end
	else
		local url
		url, force = server:getUpgradeUrl()
		upgrades = _findUpgrades(self, url, nil, server)
		log:info("firmware upgrade from ", server, " url=", url, " force=", force)
	end


	return _upgradeWindow(self, upgrades, not force, disallowScreensaver)
end


function showFirmwareUpgradeMenu(self)
	local url = false
	local server
	local player = appletManager:callService("getCurrentPlayer")
	if player then
		server = player:getSlimServer()
		if server then
			url = server:getUpgradeUrl()
		end
	end

	local upgrades = _findUpgrades(self, url, nil, server)

	return _upgradeWindow(self, upgrades, true)
end


function _checkBattery()
	if appletManager:hasService("isBatteryLow") then
		return not appletManager:callService("isBatteryLow")
	else
		return true
	end
end


function _chargeBattery(self)
	local window = Window("help_list", self:string("UPDATE_BATTERY"), firmwareupgradeTitleStyle)
	window:setButtonAction("rbutton", "help")

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

	local help = Textarea("help_text", self:string("UPDATE_BATTERY_HELP"))
	menu:setHeaderWidget(help)
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function wasFirmwareUpgraded(self)

	-- previous version
	local previous = "/etc/squeezeos.version.bak"
	-- existing version
	local current  = "/etc/squeezeos.version"

	local wasRunning73 = self:_whatVersion(previous, '^7\.[0123]')
	local running74 = self:_whatVersion(current, '^7\.4')

	if running74 and wasRunning73 then
		log:warn('Show upgrade window message')
		self:_updatedFirmwareMessage()
	end
	
end


function _updatedFirmwareMessage(self)

	local window = Window("help_list", self:string("UPDATE"))
	window:setButtonAction("rbutton", "help")

	local menu = SimpleMenu("menu", {
		{
			text = self:string("CONTINUE"),
			sound = "WINDOWSHOW",
			callback = function()
				window:hide()
			end
		}
	})

	local help = Textarea("help_text", self:string('UPDATE_7.4_UPGRADE_MESSAGE_JIVE'))
	menu:setHeaderWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


-- opens file and checks for version
function _whatVersion(self, file, version)

        local fh, err = io.open(file)
        if fh == nil then
                return false
        end

        local t = fh:read("*all")
        fh:close()

        local match = string.match(t, version)
        return match
end


function _t_setText(self, done, msg, count)
	if type(count) == "number" then
		if count >= 100 then
			count = 100
		end
		self.counter:setValue(count .. "%")
		self.progress:setRange(1, 100, count)
	else
		self.counter:setValue("")
	end

	self.text:setValue(self:string(msg))

	if done then
		self.icon:setStyle("icon_restart")
	end
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
		self:_upgradeFailed()

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
	
	self.updating = true

	self.popup = Popup("update_popup")

	-- don't allow power saving during upgrades
	self.popup:setAllowPowersave(false)

	self.icon = Icon("icon_software_update")
	self.popup:addWidget(self.icon)

	self.text = Label("text", self:string("UPDATE_DOWNLOAD", ""))
	self.counter = Label("subtext", "")
	self.progress = Slider("progress", 1, 100, 1)

	self.popup:addWidget(self.text)
	self.popup:addWidget(self.counter)
	self.popup:addWidget(self.progress)
	self.popup:focusWidget(self.text)

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

	-- stop memory hungry services before upgrading
	if (System:getMachine() == "fab4") then

		appletManager:callService("stopSqueezeCenter")
		appletManager:callService("stopFileSharing")

		-- start the upgrade once SBS is shut down or timed out
		local timeout = 0
		self.serverStopTimer = self.popup:addTimer(1000, function()

			timeout = timeout + 1
			
			if timeout <= STOP_SERVER_TIMEOUT and appletManager:callService("isBuiltInSCRunning") then
				return
			end

			Task("upgrade", self, _t_upgrade, _upgradeFailed):addTask()
			
			self.popup:removeTimer(self.serverStopTimer)
		end)
	else
		Task("upgrade", self, _t_upgrade, _upgradeFailed):addTask()
	end

	self:tieAndShowWindow(self.popup)
	return window
end


function _upgradeFailed(self)
	-- unblock keys
	Framework:removeListener(self.upgradeListener)
	self.upgradeListener = nil
	self.updating = false

	-- reconnect to server
	appletManager:callService("connectPlayer")

	local window = Window("help_list", self:string("UPDATE_FAILURE"))
	window:setButtonAction("rbutton", "help")
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("UPDATE_TRY_AGAIN"),
						sound = "WINDOWSHOW",
						callback = function()
								   if _checkBattery() then
									   window:hide()
									   self:_upgrade(self.url)

								   else
									   window:bumpRight()
								   end
							   end
					}
				})

	local help = Textarea("help_text", self:string("UPDATE_FAILURE_HELP"))
	menu:setHeaderWidget(help)
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end

function free(self)
	self.updating = false
	return true
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
