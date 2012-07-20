
--[[
=head1 NAME

applets.SetupWelcome.SetupWelcome 

=head1 DESCRIPTION

Setup Applet for (Radio) Squeezebox

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local ipairs, pairs, assert, io, string, tonumber = ipairs, pairs, assert, io, string, tonumber

local oo               = require("loop.simple")
local os               = require("os")
local System           = require("jive.System")
local Applet           = require("jive.Applet")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local Icon             = require("jive.ui.Icon")
local Group            = require("jive.ui.Group")
local Button           = require("jive.ui.Button")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")

local localPlayer      = require("jive.slim.LocalPlayer")
local slimServer       = require("jive.slim.SlimServer")

local DNS              = require("jive.net.DNS")
local Networking       = require("jive.net.Networking")

local debug            = require("jive.utils.debug")
local locale           = require("jive.utils.locale")
local string           = require("jive.utils.string")
local table            = require("jive.utils.table")
local iconbar          = iconbar

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt              = jnt

local welcomeTitleStyle = 'setuptitle'

--This can be enabled for situations like MP where a fw upgrade is absolutely required to complete setup
local UPGRADE_FROM_SCS_ENABLED = false

module(..., Framework.constants)
oo.class(_M, Applet)


function startSetup(self)
	-- flag to SN that we are in setup for testing
	jnt.inSetupHack = true

	step1(self)
end


function startRegister(self)
	step7(self)
end


function _consumeAction(self, event)
	log:warn("HOME ACTIONS ARE DISABLED IN SETUP. USE LONG-PRESS-HOLD BACK BUTTON INSTEAD")
	-- don't allow this event to continue
	return EVENT_CONSUME
end

function _disableNormalEscapeMechanisms(self)

	if not self.disableHomeActionDuringSetup then
		self.disableHomeActionDuringSetup = Framework:addActionListener("go_home", self, _consumeAction)
		self.disableHomeOrNowPlayingActionDuringSetup = Framework:addActionListener("go_home_or_now_playing", self, _consumeAction)
		self.disableHomeKeyDuringSetup =
			Framework:addListener(EVENT_KEY_PRESS | EVENT_KEY_HOLD,
			function(event)
				local keycode = event:getKeycode()
				if keycode == KEY_HOME then
					log:warn("HOME KEY IS DISABLED IN SETUP. USE LONG-PRESS-HOLD BACK BUTTON INSTEAD")
					-- don't allow this event to continue
					return EVENT_CONSUME
				end
				return EVENT_UNUSED
			end)

		-- soft_reset escapes setup (need to clean up when this happens)
		self.freeAppletWhenEscapingSetup =
			Framework:addActionListener("soft_reset", self,
			function(self, event)
				self:_enableNormalEscapeMechanisms()
				return EVENT_UNUSED
			end)
	end
end


function _enableNormalEscapeMechanisms(self)
	log:info("_enableNormalEscapeMechanisms")

	Framework:removeListener(self.disableHomeActionDuringSetup)
	Framework:removeListener(self.disableHomeOrNowPlayingActionDuringSetup)
	Framework:removeListener(self.disableHomeKeyDuringSetup)
	Framework:removeListener(self.freeAppletWhenEscapingSetup)
end


function _addReturnToSetupToHomeMenu(self)
	--first remove any existing
	jiveMain:removeItemById('returnToSetup')

	local returnToSetup = {
		id   = 'returnToSetup',
		node = 'home',
		text = self:string("RETURN_TO_SETUP"),
		iconStyle = 'hm_settings',
		weight = 2,
		callback = function()
			self:step1()
		end
		}
	jiveMain:addItem(returnToSetup)
end


function _setupComplete(self, gohome)
	log:info("_setupComplete gohome=", gohome)

	jiveMain:removeItemById('returnToSetup')
	self:_enableNormalEscapeMechanisms()

	if gohome then
		jiveMain:closeToHomeAfterSetup(true, Window.transitionPushLeft)
	end
end


function step1(self)
	-- add 'RETURN_TO_SETUP' at top
	log:debug('step1')
	self:_addReturnToSetupToHomeMenu()
	self:_disableNormalEscapeMechanisms()
	iconbar:hideBatteryIcon("ON")
	-- choose language
	appletManager:callService("setupShowSetupLanguage",
		function()
			self:step2()
		end, false)
end

function step2(self)
	iconbar:hideBatteryIcon("OFF")
	log:debug('step2')
	appletManager:callService("isBatteryTabThere",
		function()
			self:step3()
		end)
end


function step3(self, transition)
	log:info("step3")

	-- network connection type
	appletManager:callService("setupNetworking", 
		function()
			self:step3a(iface)
		end,
	transition)
end


function step3a(self)
	log:info("step3a")

-- TODO: need to retest first
--	-- Add a dummy window to prevent old content (like wireless PW entry window)
--	--  to show when all popup windows are removed again
--	local window = Window("help_list", self:string("PLEASE_WAIT"))
--	self:tieAndShowWindow(window)

	-- Waiting popup
	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	popup:addWidget(Label("text", self:string("CHECK_FIRMWARE_UPDATE")))
	popup:addWidget(Label("subtext", self:string("PLEASE_WAIT")))
	popup:setAllowScreensaver(false)
	popup:ignoreAllInputExcept()
	popup:addTimer(1000, function()
		-- Contact config server, set correct SN, do not yet register
		if appletManager:hasService("fetchConfigServerData") then
			appletManager:callService("fetchConfigServerData",
				true,	-- set SN
				false,	-- do not register (yet)
				false,  -- don't do firmware upgrade (yet)
				function()
					self:step6()
				end)
		else
			self:step6()
		end
	end,
	true)	--once

	self:tieAndShowWindow(popup)
end

function step6(self)
	log:info("step6")

	-- automatically setup local player as selected player
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			appletManager:callService("setCurrentPlayer", player)
			return self:step7()
		end
        end

	-- this should never be called
	log:error("no local player found?")
	return appletManager:callService("setupShowSelectPlayer",
		function()
			self:step7()
		end, 'setuptitle')
end


-- we are connected when we have a pin and upgrade url
function _squeezenetworkConnected(self, squeezenetwork)
-- Defect 98: disable firmware upgrade from SN or LMS
--	return squeezenetwork:getPin() ~= nil and squeezenetwork:getUpgradeUrl() and squeezenetwork:isConnected()
	return squeezenetwork:getPin() ~= nil and squeezenetwork:isConnected()
end

function _anySqueezeCenterWithUpgradeFound(self)
	local anyFound = false
	for _,server in appletManager:callService("iterateSqueezeCenters") do
		if server:isCompatible() and server:getUpgradeUrl() and not server:isSqueezeNetwork() then
			log:info("At least one compatible SC with an available upgrade found. First found: ", server)
			anyFound = true
			break
		end
	end

	return anyFound
end

function step7(self)
	log:info("step7")

	-- Once here, network setup is complete
	self:_setupDone(true, false)

	-- Bug 12786: Selecting a Network, then backing out
	--  and re-selecting will cause network errors
	self.registerRequest = false

	--might be coming into this from a restart, so re-disable
	self:_disableNormalEscapeMechanisms()
	self:_addReturnToSetupToHomeMenu()

	-- Find squeezenetwork server
	local squeezenetwork = false
	for name, server in slimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end

	if not squeezenetwork then
		log:error("no SqueezeNetwork instance")
		self:_setupComplete(true)
		return
	end

	local settings = self:getSettings()
	if settings.registerDone then
		log:error("SqueezeNetwork registration complete")

		local player = appletManager:callService("getCurrentPlayer")
		log:info("connecting ", player, " to ", squeezenetwork)
		player:connectToServer(squeezenetwork)

		self:_setupComplete(true)
		return
	end

	-- Check if there is a required firmware update, if yes, do it
	if appletManager:hasService("checkRequiredFirmwareUpgrade") then
		if appletManager:callService("checkRequiredFirmwareUpgrade") then
			-- above returns true if there was a required firmware upgrade
			-- return as the player will reboot anyways
			return
		end
	end

	if UPGRADE_FROM_SCS_ENABLED then
		_squeezenetworkWait(self, squeezenetwork)
	else

-- Defect: 47 - [Belsonic] Language selection screen appear(momentarily) again after FW check
-- We need to wait until we are connected to SN before sending the register request.
-- If we don't wait the register request will trigger a (re-)connect event which by
--  default does a disconnect first, leading to a (re-)connection spinny which goes
--  away too early, exposing the last real window (language screen) on the window stack.
-- The reason this is different than before is that before the device did connect
--  to SN as soon as the network was established and that was long enough before the
--  register request was sent so that no (re-)connect event was triggered.
-- Now the first thing after the network is established is the call to the config
--  server to get the SN channel to connect to and only then the connection to
--  SN happens and that's not early enough for the register request to succeed w/o
--  (re-)connect event so we wait until we are connected ok.

--		self:_registerRequest(squeezenetwork)
		_squeezenetworkWait(self, squeezenetwork)
	end
end


function _squeezenetworkWait(self, squeezenetwork)
	log:info("Looking for upgrade, waiting to connect to SqueezeNetwork and find any compatible SCs")

	self.timer = nil

	-- Waiting popup
	local popup = Popup("waiting_popup")

	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	popup:addWidget(Label("text", self:string("CONNECTING_TO_SN")))
	popup:addWidget(Label("subtext", self:string("MYSERVICE_DOT_COM")))
	popup:setAllowScreensaver(false)
	popup:ignoreAllInputExcept()

	local timeout = 0
	--Wait until SN is connected before going to step 8. Also if SN isn't being found, use available SCs. Allow 10 seconds to go by to give all SCs a chacne to be discovered.
	self.timer = popup:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			self.timer:stop()
			step8(self, squeezenetwork)
		else
			log:info("SN not available, Waited: ", timeout + 1)
		end

		timeout = timeout + 1

		--try for 30 seconds
		if timeout >= 30 then
			log:info("Can't find any SC or connect to SqueezeNetwork after ", timeout, " seconds")
			self.timer:stop()
			_squeezenetworkFailed(self, squeezenetwork)
		end
	end)

	self:tieAndShowWindow(popup)
end


function _squeezenetworkFailed(self, squeezenetwork)
	log:info("_squeezenetworkFailed")
	Task("dns", self, function()
		local serverip = squeezenetwork:getIpPort()

		log:info("Can't connect to SqueezeNetwork: ", serverip)

		local ip, err
		if DNS:isip(serverip) then
			ip = serverip
		else
			ip, err = DNS:toip(serverip)
		end

		-- some routers resolve all DNS addresses to the local
		-- network when the internet is down, we catch these here
		if ip then
			local n = string.split("%.", ip)
			n[1] = tonumber(n[1])
			n[2] = tonumber(n[2])

			-- local addresses
			if n[1] == 192 and n[2] == 168 then
				ip = nil
			elseif n[1] == 172 and n[2] >= 16 and n[2] <=31 then
				ip = nil
			elseif n[1] == 10 then
				ip = nil
			end

			-- test addresses, used by BT homehub on DNS failure
			if n[1] == 192 and n[2] >= 18 and n[2] <= 19 then
				ip = nil
			end
		end


		-- have we connected while looking up the DNS?
		if _squeezenetworkConnected(self, squeezenetwork) then
			log:info("SN now seen")
			return
		end		

		if squeezenetwork:isConnected() then
			-- we're connected, but don't have a PIN or Upgrade state
			log:error("SqueezeNetwork error. pin=", squeezenetwork:getPin(), " upgradeUrl=", squeezenetwork:getUpgradeUrl())
			_squeezenetworkError(self, squeezenetwork, "SN_SYSTEM_ERROR")
		elseif ip == nil then
			-- dns failed
			log:info("DNS failed for ", serverip)
			_squeezenetworkError(self, squeezenetwork, "SN_DNS_FAILED")
		else
			-- connection failed
			_squeezenetworkError(self, squeezenetwork, "SN_DNS_WORKED")
		end
	end):addTask()
end


function _squeezenetworkError(self, squeezenetwork, message)
	local window = Window("help_list", self:string("CANT_CONNECT"))
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	menu:addItem({
		text = (self:string("SN_TRY_AGAIN")),
		sound = "WINDOWSHOW",
		callback = function()
			_squeezenetworkWait(self, squeezenetwork)
			window:hide()
		end,
		weight = 1
	})

	window:addWidget(menu)
	menu:setHeaderWidget(Textarea("help_text", self:string(message)))

	-- back goes back to network selection
	-- note add listener to menu, as it has the focus
	menu:addActionListener("back", self, function()
		Framework:playSound("WINDOWHIDE")
		self:step3(Window.transitionPushRight)
	end)

	-- help shows diagnostics
	window:setButtonAction("rbutton", "help")
	window:addActionListener("help", self, function()
		Framework:playSound("WINDOWSHOW")
		appletManager:callService("supportMenu")
	end)
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)


	window:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			step8(self, squeezenetwork)
			window:hide()
		end
	end)

	self:tieAndShowWindow(window)
end


function step8(self, squeezenetwork)
	log:info("step8")
	self:_registerRequest(squeezenetwork)
end


function _registerRequest(self, squeezenetwork)
	if self.registerRequest then
		return
	end

	--defer setting self.registerRequest until first register command completes to avoid race condition where serverLinked occurs early in a
	--  "register or continue" situation since the server in that case is already linked
	local successCallback = function(requireAlreadyLinked)
		self.registerRequest = true
		self.registerRequestRequireAlreadyLinked = requireAlreadyLinked
		local filePath = "/mnt/storage/etc/factoryresetState"
		if System:findFile(filePath) then
			os.remove(filePath)
		end
	end

	log:info("registration on SN")
	local factoryResetFile = "/mnt/storage/etc/factoryresetState"
	local wipeFlag = "wipeFlag:0"
	if System:findFile(factoryResetFile) then
		log:info('located factoryreset file')
		factoryFile = io.open(factoryResetFile)
		if factoryFile == nil then
			log:error("Err in openeing factoryResetFile")
		else
			local line = factoryFile:read()
			if line ~= nil then
				if string.match(line, "factory_reset") then
					wipeFlag = "wipeFlag:1"
				end
				log:debug("wipeFlag read as: ", wipeFlag)
				log:debug("line read as: ", line)
			end
			factoryFile:close()
		end
		--read the data
	else
		log:info('No factory reset info')
	end
	appletManager:callService("squeezeNetworkRequest", { 'register', 0, 100, 'service:SN', wipeFlag }, true, successCallback )


	self.locked = true -- don't free applet
	jnt:subscribe(self)
end


function step9(self)
	log:info("step9")

	_setupComplete(self, false)
	_setupDone(self, true, true)

	self.locked = true -- free applet
	jnt:unsubscribe(self)

	jiveMain:closeToHomeAfterSetup(true, Window.transitionPushLeft)

end


--finish setup if connected server is SC
function notify_playerCurrent(self, player)
	if not player then
		return
	end

	local server = player:getSlimServer()

	if not server then
		return
	end

	if server:isSqueezeNetwork() then
		return
	end

	log:info("Calling step9. server: ", server)

	step9(self)
end



function notify_serverLinked(self, server, wasAlreadyLinked)
	log:info("notify_serverLinked: ", server)

	if not server:isSqueezeNetwork() then
		return
	end

	if not self.registerRequest then
		return
	end
	
	--avoid race condition where we are in the registerRequest but for a player that is already linked
	if  self.registerRequestRequireAlreadyLinked and not wasAlreadyLinked then
		return
	end
	log:info("server linked: ", server, " pin=", server:getPin(), " registerRequestRequireAlreadyLinked: ", self.registerRequestRequireAlreadyLinked, " wasAlreadyLinked: ", wasAlreadyLinked)

	if server:getPin() == false then
		-- for testing connect the player tosqueezenetwork
		local player = appletManager:callService("getCurrentPlayer")

		local squeezenetwork = false
		for name, server in slimServer:iterate() do
			if server:isSqueezeNetwork() then
				squeezenetwork = server
			end
		end

		log:info("connecting ", player, " to ", squeezenetwork)
		player:connectToServer(squeezenetwork)

		self:step9()
	end
end

function isSetupDone(self)
	local settings = self:getSettings()

	return settings and settings.setupDone
end



function _setupDone(self, setupDone, registerDone)
	log:info("network setup complete")

	local settings = self:getSettings()

	settings.setupDone = setupDone
	settings.registerDone = registerDone
	self:storeSettings()

	-- FIXME: workaround until filesystem write issue resolved
	os.execute("sync")
end

function _getPowerSysValue(self, param)

	local f = io.open("/sys/devices/platform/i2c-adapter:i2c-1/1-0010/" .. param)
	log:warn("opening: ", param)

	local value = f:read("*all")
	f:close()

	return value
end

function _isBatteryTabThere(self)
	local batteryTemperature = tonumber(self:_getPowerSysValue("battery_temperature"))
	local batteryVoltage = tonumber(self:_getPowerSysValue("battery_voltage"))
	local batteryMonitor1 = tonumber(self:_getPowerSysValue("battery_vmon1_voltage"))
	local batteryMonitor2 = tonumber(self:_getPowerSysValue("battery_vmon2_voltage"))
	-- read batv twice for correct value
	batteryVoltage = tonumber(self:_getPowerSysValue("battery_voltage"))
	--Bogus values -> bat values temp=679 v=17971 v1=20 v2=20
	if batteryTemperature < 65000 and batteryMonitor1 < 50 and batteryMonitor2 < 50 and (batteryVoltage < 50 or batteryVoltage > 17000) then
		return true
	end
	return false
end

function isBatteryTabThere(self, f)
	local showBatWindow = self:_isBatteryTabThere()
	self.timer = nil

	if showBatWindow == true then
		local window = Window("Battery tab", self:string("BATTERY_TITLE"))
		window:setAllowScreensaver(false)

		local menu = SimpleMenu("menu")
		menu:addItem({
			text = self:string("CONTINUE"),
			sound = "WINDOWSHOW",
			callback = function()
				if self.timer then
					self.timer:stop()
				end
				window:hide(Window.transitionPushLeft)
				f()
			end,
			weight = 1
		})
		menu:setHeaderWidget(Textarea("help_text", self:string("BATTERY_HELP")))

		window:addWidget(menu)

		self.timer = window:addTimer(1000, function()
			local showBatWindow = self:_isBatteryTabThere()
			if showBatWindow == false then
				self.timer:stop()
				window:hide(Window.transitionPushLeft)
				f()
			end
		end)

		self:tieAndShowWindow(window)
	else
		f()
	end
end


--[[
function init(self)
	log:info("subscribe")
	jnt:subscribe(self)
end
--]]


function free(self)
	appletManager:callService("setDateTimeDefaultFormats")
	return not self.locked
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

