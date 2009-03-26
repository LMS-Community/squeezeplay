
--[[
=head1 NAME

applets.SetupWelcome.SetupWelcome 

=head1 DESCRIPTION

Setup Applet for (Touch) Squeezebox

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local ipairs, pairs, assert, io, string, tonumber = ipairs, pairs, assert, io, string, tonumber

local oo               = require("loop.simple")

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

local log              = require("jive.utils.log").logger("applets.setup")
local debug            = require("jive.utils.debug")
local locale           = require("jive.utils.locale")
local string           = require("jive.utils.string")
local table            = require("jive.utils.table")

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt              = jnt

local welcomeTitleStyle = 'setuptitle'


module(..., Framework.constants)
oo.class(_M, Applet)


--[[
function notify_playerCurrent(self, player)
	log:info("setup complete")
    if not self:getSettings().setupDone then

        if player and not player:needsMusicSource() then
            log:debug("notify_playerCurrent called with a source, so finishing setup")
            
            self:step7()
        end
    end

end
--]]


function startSetup(self)
	-- flag to SN that we are in setup for testing
	jnt.inSetupHack = true

	step1(self)
end


function startRegister(self)
	step7(self)
end


function step1(self)
	-- add 'RETURN_TO_SETUP' at top
	log:debug('step1')
	local returnToSetup = {
		id   = 'returnToSetup',
		node = 'home',
		text = self:string("RETURN_TO_SETUP"),
		weight = 2,
		callback = function()
			self:step1()
		end
		}
	jiveMain:addItem(returnToSetup)

	disableHomeKeyDuringSetup = 
		Framework:addListener(EVENT_KEY_PRESS,
		function(event)
			local keycode = event:getKeycode()
			if keycode == KEY_HOME then
				log:warn("HOME KEY IS DISABLED IN SETUP. USE PRESS-HOLD BACK BUTTON INSTEAD")
				-- don't allow this event to continue
				return EVENT_CONSUME
			end
			return EVENT_UNUSED
		end)

	-- add press and hold left to escape setup
	self.freeAppletWhenEscapingSetup =
 		Framework:addListener(EVENT_KEY_HOLD,
		function(event)
			local keycode = event:getKeycode()
			if keycode == KEY_BACK then
				self:free()
			end
			return EVENT_UNUSED
		end)

	-- choose language
	appletManager:callService("setupShowSetupLanguage",
		function()
			self:step2()
		end, false)
end


function step2(self)
	log:info("step2")

	-- welcome!
	self:setupWelcomeShow(
		function()
			self:step3()
		end)
end


function step3(self)
	log:info("step3")

	-- network connection type
	appletManager:callService("setupNetworking", 
		function()
			self:step6(iface)
		end)
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
	return squeezenetwork:getPin() ~= nil and squeezenetwork:getUpgradeUrl()
end


function step7(self)
	-- Once here, network setup is complete
	self:_setupDone()

	-- Find squeezenetwork server
	local squeezenetwork = false
	for name, server in slimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end

	if not squeezenetwork then
		log:error("no SqueezeNetwork instance")
		jiveMain:closeToHome(true, Window.transitionPushLeft)
		return
	end

	local settings = self:getSettings()
	if settings.registerDone then
		log:error("SqueezeNetwork registration complete")

		local player = appletManager:callService("getCurrentPlayer")
		log:info("connecting ", player, " to ", squeezenetwork)
		player:connectToServer(squeezenetwork)

		jiveMain:closeToHome(true, Window.transitionPushLeft)
		return
	end

	_squeezenetworkWait(self, squeezenetwork)
end


function _squeezenetworkWait(self, squeezenetwork)
	log:info("waiting to connect to SqueezeNetwork")

	-- Waiting popup
	local popup = Popup("waiting_popup")

	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	popup:addWidget(Label("text", self:string("CONNECTING_TO_SN")))

	local timeout = 0
	popup:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			step8(self, squeezenetwork)
		end

		timeout = timeout + 1

		if timeout > 30 then
			_squeezenetworkFailed(self, squeezenetwork)
		end
	end)

	self:tieAndShowWindow(popup)
end


function _squeezenetworkFailed(self, squeezenetwork)
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

	window:addWidget(Textarea("help_text", self:string(message)))
	window:addWidget(menu)

	-- back tries again
	-- note add listener to menu, as it has the focus
	menu:addActionListener("back", self, function()
		_squeezenetworkWait(self, squeezenetwork)
		window:hide()
	end)

	-- help shows diagnostics
	window:setButtonAction("rbutton", "help")
	window:addActionListener("help", self, function()
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
	local url, force = squeezenetwork:getUpgradeUrl()
	local pin = squeezenetwork:getPin()

	log:info("squeezenetwork pin=", pin, " url=", url)

	if force then
      		log:info("firmware upgrade from SN")
		appletManager:callService("firmwareUpgrade", squeezenetwork)

	elseif pin then
      		log:info("registration on SN")
		appletManager:callService("squeezeNetworkRequest", { 'register', 0, 100, 'service:SN' })

	else
		local settings = self:getSettings()
		settings.registerDone = true
		self:storeSettings()

		local player = appletManager:callService("getCurrentPlayer")
		log:info("connecting ", player, " to ", squeezenetwork)
		player:connectToServer(squeezenetwork)

		jiveMain:closeToHome(true, Window.transitionPushLeft)
	end
end


function _setupDone(self)
	log:info("network setup complete")

	local settings = self:getSettings()

	settings.setupDone = true
	self:storeSettings()

	jiveMain:removeItemById('returnToSetup')
end


function setupWelcomeShow(self, setupNext)
	local window = Window("help_list", self:string("WELCOME"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	window:setButtonAction("rbutton", nil)

	local textarea = Textarea("help_text", self:string("WELCOME_WALKTHROUGH"))

	local continueButton = SimpleMenu("menu")

	continueButton:addItem({
		text = (self:string("CONTINUE")),
		sound = "WINDOWSHOW",
		callback = setupNext,
		weight = 1
	})
	
	window:addWidget(textarea)
	window:addWidget(continueButton)

	self:tieAndShowWindow(window)
	return window
end


--[[
function init(self)
	log:info("subscribe")
	jnt:subscribe(self)
end
--]]


-- remove listeners when leaving this applet
function free(self)
	Framework:removeListener(self.disableHomeKeyDuringSetup)
	Framework:removeListener(self.freeAppletWhenEscapingSetup)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

