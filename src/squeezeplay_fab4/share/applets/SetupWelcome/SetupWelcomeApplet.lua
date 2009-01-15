
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
local ipairs, pairs, assert, io, string = ipairs, pairs, assert, io, string

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
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")
local localPlayer      = require("jive.slim.LocalPlayer")

local Networking       = require("jive.net.Networking")

local log              = require("jive.utils.log").logger("applets.setup")
local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt           = jnt

local welcomeTitleStyle = 'setuptitle'


module(..., Framework.constants)
oo.class(_M, Applet)


function notify_playerCurrent(self, player)
	log:info("setup complete")

	-- setup is completed when a player is selected
	self:getSettings().setupDone = true
	self:storeSettings()

	-- remove Return to Setup from JiveMain
	jiveMain:removeItemById('returnToSetup')

	log:info("unsubscribe")
	jnt:unsubscribe(self)
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
	self._topWindow = appletManager:callService("setupShowSetupLanguage", function() self:step2() end, 'setupfirsttitle', true)

	return self.topWindow
end

function step2(self)
	log:info("step2")

	-- welcome!
	return self:setupWelcomeShow( function() self:step3() end)
end

function step3(self)
	log:info("step3")

	-- wireless region
	return appletManager:callService("setupRegionShow", function() self:step3a() end, welcomeTitleStyle)
	
end

function step3a(self)

	log:info("step3a")

	-- network connection type
	return appletManager:callService("setupConnectionType", 
					function() self:step4a() end, 
					function() self:step4b() end, 
					welcomeTitleStyle)

end

function step4a(self)
	log:info("step4a")

	-- finding networks
	self.scanWindow = appletManager:callService("setupScanShow", function()
							   self:step5()
							   -- FIXME is this required:
							   if self.scanWindow then
								   self.scanWindow:hide()
								   self.scanWindow = nil
							   end
						end,
						welcomeTitleStyle
	)
	return self.scanWindow
end

function step4b(self)
	log:warn("step4b")

	appletManager:callService("setupConnectWiredInterface")
	self:step6()

	--[[ FIXME: create a popup that comes on screen until wired comes online
	-- connect to wired interface
	self.connectingWindow = appletManager:callService("setupConnectWiredInterface", function()
							   self:step6()
							   -- FIXME is this required:
							   if self.scanWindow then
								   self.scanWindow:hide()
								   self.scanWindow = nil
							   end
						end,
						welcomeTitleStyle
	)
	return self.connectingWindow
	--]]
end

function step5(self)
	log:info("step5")

	-- wireless connection, using squeezebox?
	local scanResults = self.wireless:scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("******************************checking ssid ", ssid)

		if string.match(ssid, "logitech%+squeezebox%+%x+") then
			return self:setupConnectionShow(function() self:step51() end,
							function() self:step52() end
						)
		end
	end

	return self:step52()
end

function step51(self)
	log:info("step51")

	-- connect using squeezebox in adhoc mode
	return appletManager:callService("setupAdhocShow", function() self:step8() end)
end

function step52(self)
	log:info("step52")

	-- connect using other wireless network
	return appletManager:callService("setupNetworksShow", function() self:step6() end, welcomeTitleStyle)
end

function step6(self)
	log:info("step6")

	-- wireless connection, using squeezebox?
	local scanResults = self.wireless:scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("checking ssid ", ssid)

		if string.match(ssid, "logitech[%-%+]squeezebox[%-%+]%x+") then
			return self:step61()
		end
	end

	return self:step7()
end

function step61(self)
	log:info("step61")

	-- setup squeezebox
	return appletManager:callService("setupSqueezeboxShow", function() self:step7() end)
end

function step7(self)
	log:info("step7")

	-- skip this step if a player has been selected
	if appletManager:callService("getCurrentPlayer") then
		return self:step8()
	end

	-- select player
	return appletManager:callService("setupShowSelectPlayer", function() self:step8() end, welcomeTitleStyle)
end

function step8(self)
	log:info("step8")

	-- all done
	self:getSettings().setupDone = true
	jiveMain:removeItemById('returnToSetup')
--	self:storeSettings()

	return self:setupDoneShow(function()
			self._topWindow:hideToTop(Window.transitionPushLeft) 
		end)
end


function setupWelcomeShow(self, setupNext)
	local window = Window("window", self:string("WELCOME"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	local textarea = Textarea("centeredtextarea", self:string("WELCOME_WALKTHROUGH"))

	local continue = Button(
				Group("touchButton", {
					text = Label("touchButton", self:string("PRESS_TO_CONTINUE")),
					icon = Icon("icon"),
				}),
                                function()
                                        window:dispatchNewEvent(EVENT_KEY_PRESS, KEY_GO)
                                        return EVENT_CONSUME
                                end
	)

	window:addWidget(textarea)
	window:addWidget(continue)

	window:addListener(EVENT_KEY_PRESS,
		function(event)
			local keycode = event:getKeycode()
			if keycode == KEY_GO or
				keycode == KEY_FWD then
				window:playSound("WINDOWSHOW")
				setupNext()
			elseif keycode == KEY_BACK or
				keycode == KEY_REW then
				window:playSound("WINDOWHIDE")
				window:hide()
			end

			return EVENT_CONSUME
		end)

	self:tieAndShowWindow(window)
	return window
end


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


function setupDoneShow(self, setupNext)
	local window = Window("window", self:string("DONE"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")

	menu:addItem({ text = self:string("DONE_CONTINUE"),
		       sound = "WINDOWSHOW",
		       callback = setupNext
		     })

	window:addWidget(Textarea("help", self:string("DONE_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function init(self)
	log:info("subscribe")
	jnt:subscribe(self)

	self.wireless = Networking:wirelessInterface(jnt)
end


-- remove listeners when leaving this applet
function free(self)
	log:info("free")
	Framework:removeListener(self.disableHomeKeyDuringSetup)
	Framework:removeListener(self.freeAppletWhenEscapingSetup)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

