
--[[
=head1 NAME

applets.SetupWelcome.SetupWelcome - Add a main menu option for setting up language

=head1 DESCRIPTION

Allows user to select language used in Jive

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local ipairs, pairs, assert, io, string = ipairs, pairs, assert, io, string

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local AppletManager    = require("jive.AppletManager")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local Icon             = require("jive.ui.Icon")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")

local Wireless         = require("jive.net.Wireless")

local log              = require("jive.utils.log").logger("applets.setup")
local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local KEY_GO           = jive.ui.KEY_GO
local KEY_BACK         = jive.ui.KEY_BACK

local welcomeTitleStyle = 'settingstitle'

module(...)
oo.class(_M, Applet)


function step1(self)
	-- choose language
	self.setupLanguage = assert(appletManager:loadApplet("SetupLanguage"))
	self._topWindow = self.setupLanguage:setupShow(function() self:step2() end)
	return self.topWindow
end

function step2(self)
	-- welcome!
	return self:setupWelcomeShow(function() self:step3() end)
end

function step3(self)
	-- wireless region
	self.setupWireless = assert(appletManager:loadApplet("SetupWireless"))
	return self.setupWireless:setupRegionShow(function() self:step4() end)
end

function step4(self)
	-- finding networks
	self.scanWindow = self.setupWireless:setupScanShow(function()
								   self:step5()
								   if self.scanWindow then
									   self.scanWindow:hide()
									   self.scanWindow = nil
								   end
							   end)
	return self.scanWindow
end

function step5(self)
	-- wireless connection, using squeezebox?
	local scanResults = Wireless.scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("checking ssid ", ssid)

		if string.match(ssid, "logitech%+squeezebox%+%x+") then
			return self:setupConnectionShow(function() self:step51() end,
							function() self:step52() end
						)
		end
	end

	return self:step52()
end

function step51(self)
	-- connect using squeezebox in adhoc mode
	self.setupSqueezebox = assert(appletManager:loadApplet("SetupSqueezebox"))

	-- FIXME set active player to squeezebox that has been setup
	return self.setupSqueezebox:setupAdhocShow(function() self:step8() end)
end

function step52(self)
	-- connect using other wireless network
	return self.setupWireless:setupNetworksShow(function() self:step6() end)
end

function step6(self)
	-- wireless connection, using squeezebox?
	local scanResults = Wireless.scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("checking ssid ", ssid)

		if string.match(ssid, "logitech[%-%+]squeezebox[%-%+]%x+") then
			return self:step61()
		end
	end

	return self:step7()
end

function step61(self)
	-- setup squeezebox
	self.setupSqueezebox = assert(appletManager:loadApplet("SetupSqueezebox"))

	return self.setupSqueezebox:setupSqueezeboxShow(function() self:step7() end)
end

function step7(self)
	-- skip this step if a player has been selected
	local manager = AppletManager:getAppletInstance("SlimDiscovery")
	if manager and manager:getCurrentPlayer() ~= nil then
		return self:step8()
	end

	-- select player
	self.setupPlayer = assert(appletManager:loadApplet("SelectPlayer"))
	return self.setupPlayer:setupShow(function() self:step8() end)
end

function step8(self)
	-- all done
	return self:setupDoneShow(function()
			self._topWindow:hideToTop(Window.transitionPushLeft) 

			self:getSettings().setupDone = true
			self:storeSettings()
		end)
end


function setupWelcomeShow(self, setupNext)
	local window = Window("window", self:string("WELCOME"), welcomeTitleStyle)

	local textarea = Textarea("textarea", self:string("WELCOME_WALKTHROUGH"))
	local help = Textarea("help", self:string("WELCOME_HELP"))

	window:addWidget(textarea)
	window:addWidget(help)

	window:addListener(EVENT_KEY_PRESS,
		function(event)
			local keycode = event:getKeycode()
			if keycode == KEY_GO then
				setupNext()
			elseif keycode == KEY_BACK then
				window:hide()
			end

			return EVENT_CONSUME
		end)

	self:tieAndShowWindow(window)
	return window
end


function setupConnectionShow(self, setupSqueezebox, setupNetwork)
	local window = Window("window", self:string("WIRELESS_CONNECTION"), welcomeTitleStyle)
	local menu = SimpleMenu("menu")

	menu:addItem({
			     text = self:string("CONNECT_USING_SQUEEZEBOX"),
			     callback = setupSqueezebox,
		     })
	menu:addItem({
			     text = self:string("CONNECT_USING_NETWORK"),
			     callback = setupNetwork,
		     })
	
	window:addWidget(Textarea("help", self:string("CONNECT_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function setupDoneShow(self, setupNext)
	local window = Window("window", self:string("DONE"), welcomeTitleStyle)
	local menu = SimpleMenu("menu")

	menu:addItem({ text = self:string("DONE_CONTINUE"),
		       callback = setupNext
		     })

	window:addWidget(Textarea("help", self:string("DONE_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

