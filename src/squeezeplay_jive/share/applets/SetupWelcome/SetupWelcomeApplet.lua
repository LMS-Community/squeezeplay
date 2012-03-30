
--[[
=head1 NAME

applets.SetupWelcome.SetupWelcome

=head1 DESCRIPTION

Setup Applet for (Controller) Squeezebox

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>.

=cut
--]]


-- stuff we use
local ipairs, pairs, assert, io, string, tonumber = ipairs, pairs, assert, io, string, tonumber

local oo               = require("loop.simple")
local os               = require("os")

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
--			Framework:addListener(EVENT_KEY_PRESS | EVENT_KEY_HOLD, -- don't suppress hold for jive, since it is the power button
			Framework:addListener(EVENT_KEY_PRESS,
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
		jiveMain:closeToHome(true, Window.transitionPushLeft)
	end
end


function step1(self)
	-- add 'RETURN_TO_SETUP' at top
	log:debug('step1')
	self:_addReturnToSetupToHomeMenu()
	self:_disableNormalEscapeMechanisms()

	-- choose language
	appletManager:callService("setupShowSetupLanguage",
		function()
			self:step4()
		end, false)
end


-- Scan for not yet setup squeezebox
function step4(self, transition)
	log:info("step4")

	-- Finding networks including not yet setup squeezebox
	self.scanWindow = appletManager:callService("setupScan",
				function()
					self:step5()
					-- FIXME is this required:
					if self.scanWindow then
						self.scanWindow:hide()
						self.scanWindow = nil
					end
				end,
				transition)

	return self.scanWindow
end


-- Scan for not yet setup squeezebox
function step5(self)
	log:info("step5")

	-- Get scan results
	local wlanIface = Networking:wirelessInterface(jnt)
	local scanResults = wlanIface:scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("checking ssid ", ssid)

		-- '+' in SSID means squeezebox has ethernet connected
		if string.match(ssid, "logitech%+squeezebox%+%x+") then
			return self:setupConnectionShow(
					function()
						self:step51()
					end,
					function()
						self:step52()
					end)
		end
	end

	return self:step52()
end

-- Setup bridged mode
function step51(self)
	log:info("step51")

	-- Connect using squeezebox in adhoc mode
	return appletManager:callService("setupAdhocShow",
				function()
					self:step7()
				end)
end

-- Setup Controller to AP
function step52(self)
	log:info("step52")

	-- Connect using regular network, i.e. connect to AP
	return appletManager:callService("setupNetworking",
			function()
				self:step7()
			end)
end


-- Offer selection between standard wireless/wired or bridged setup
function setupConnectionShow(self, setupSqueezebox, setupNetwork)
	local window = Window("window", self:string("WIRELESS_CONNECTION"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")

	menu:addItem({
			     text = self:string("CONNECT_USING_SQUEEZEBOX"),
			     sound = "WINDOWSHOW",
			     callback = setupSqueezebox,
		     })
	menu:addItem({
			     text = self:string("CONNECT_USING_NETWORK"),
			     sound = "WINDOWSHOW",
			     callback = setupNetwork,
		     })
	
	window:addWidget(Textarea("help", self:string("CONNECT_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


-- we are connected when we have a pin and upgrade url
function _squeezenetworkConnected(self, squeezenetwork)
	return squeezenetwork:getPin() ~= nil and squeezenetwork:getUpgradeUrl() and squeezenetwork:isConnected()
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
		step8point5(self, squeezenetwork)
		return
	end

	local settings = self:getSettings()
	if settings.registerDone then
		log:error("SqueezeNetwork registration complete")
		step8point5(self, squeezenetwork)
		return
	end

	if UPGRADE_FROM_SCS_ENABLED then
		_squeezenetworkWait(self, squeezenetwork)
	else
		self:_registerRequest(squeezenetwork)
	end
end


function _squeezenetworkWait(self, squeezenetwork)
	log:info("Looking for upgrade, waiting to connect to SqueezeNetwork and find any compatible SCs")

	-- Waiting popup
	local popup = Popup("waiting_popup")

	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	popup:addWidget(Label("text", self:string("CONNECTING_TO_SN")))
	popup:addWidget(Label("subtext", self:string("MYSQUEEZEBOX_DOT_COM")))
	popup:setAllowScreensaver(false)
	popup:ignoreAllInputExcept()

	local timeout = 0
	--Wait until SN is connected before going to step 8. Also if SN isn't being found, use available SCs. Allow 10 seconds to go by to give all SCs a chacne to be discovered.
	popup:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			step8(self, squeezenetwork)
		else
			log:info("SN not available, Waited: ", timeout + 1)
			--allow 10 seconds to go by before doing SC check to allow SCs to be discovered
			if timeout >= 9 and _anySqueezeCenterWithUpgradeFound(self) then
				step8(self, squeezenetwork)
			else
				log:info("Looking for compatible SCs with an upgrade, Waited: ", timeout + 1)
			end
		end


		timeout = timeout + 1

		--try for 30 seconds
		if timeout >= 30 then
			log:info("Can't find any SC or connect to SqueezeNetwork after ", timeout, " seconds")
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
	log:info("_squeezenetworkError")

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
		self:step4(Window.transitionPushRight)
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
	if not squeezenetwork:isConnected() then
		log:info("get SC from one of discovered SCs")
		appletManager:callService("firmwareUpgrade", nil)
		return
	end

	local url, force = squeezenetwork:getUpgradeUrl()
	local pin = squeezenetwork:getPin()

	log:info("squeezenetwork pin=", pin, " url=", url)

	if force then
      		log:info("firmware upgrade from SN")
		appletManager:callService("firmwareUpgrade", squeezenetwork)
	else
		self:_registerRequest(squeezenetwork)
	end
end


-- step 8.5 makes sure we have a current player, this will already be the
-- case for a local player or a bridged setup (on jive).

function step8point5(self, squeezenetwork)
	log:info("step8point5")
	assert(squeezenetwork)

	local player = appletManager:callService("getCurrentPlayer")
	if player then
		return self:step8point7(squeezenetwork)
	end

	-- find player
	return appletManager:callService("setupShowSelectPlayer", function()
		self:step8point7(squeezenetwork)
	end, 'setuptitle')
end


-- step 8.7 make sure the player is connected to SN

function step8point7(self, squeezenetwork)
	log:info("step8point7")
	assert(squeezenetwork)

	-- if player is still not connected, now connect to SN
	local player = appletManager:callService("getCurrentPlayer")
	assert(player)

	if not player:getSlimServer() then
		log:info("connect ", player, " to ", squeezenetwork)
		player:connectToServer(squeezenetwork)
	end

	self:step9()
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
	end

	log:info("registration on SN")
	appletManager:callService("squeezeNetworkRequest", { 'register', 0, 100, 'service:SN' }, true, successCallback )

	self.locked = true -- don't free applet
	jnt:subscribe(self)
end


function step9(self)
	log:info("step9")

	_setupComplete(self, false)
	_setupDone(self, true, true)

	self.locked = true -- free applet
	jnt:unsubscribe(self)

	jiveMain:goHome()

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
	log:info("server linked: ", server, " pin=", server:getPin(), " registerRequestRequireAlreadyLinked: ", self.registerRequestRequireAlreadyLinked, " wasAlreadyLinked: ", wasAlreadyLinked, " server:isSpRegisteredWithSn(): ", server:isSpRegisteredWithSn())

	if server:isSpRegisteredWithSn() then
		step8point5(self, server)
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

