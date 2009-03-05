
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
local debug              = require("jive.utils.debug")
local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt           = jnt

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
	self._topWindow = appletManager:callService("setupShowSetupLanguage", function() self:step2() end, false)

	return self.topWindow
end


function step2(self)
	log:info("step2")

	-- welcome!
	return self:setupWelcomeShow( function() self:step3() end)
end


function step3(self)
	log:info("step3")

	-- network connection type
	return appletManager:callService(
		"setupNetworking", 
		function()
			self:step6(iface)
		end, 
		welcomeTitleStyle
	)
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

	log:error("no local player found?")
	return appletManager:callService("setupShowSelectPlayer", function() end, 'setuptitle')
end


function step7(self)
	-- XXXX connect to SC and error screens

	self:_setupDone()
end


function _setupDone(self)
	self:getSettings().setupDone = true
	jiveMain:removeItemById('returnToSetup')
	self:storeSettings()

	jiveMain:closeToHome(true, Window.transitionPushLeft)
end


--[[
function step7(self)
	log:info("step7")
	return self:setupDoneShow(function()

			self:getSettings().setupDone = true
			jiveMain:removeItemById('returnToSetup')
			self:storeSettings()

	        jiveMain:closeToHome(true, Window.transitionPushLeft)
		end)
		
end
--]]


function setupWelcomeShow(self, setupNext)
	local window = Window("one_button", self:string("WELCOME"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	window:setButtonAction("rbutton", nil)

	local textarea = Textarea("text", self:string("WELCOME_WALKTHROUGH"))

	local continueButton = SimpleMenu("menu")

	continueButton:addItem({
		text = (self:string("PRESS_TO_CONTINUE")),
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
function setupDoneShow(self, setupNext)
	log:info('setupDoneShow()')
	local window = Window("one_button", self:string("DONE"), welcomeTitleStyle)
	window:setAllowScreensaver(false)

	window:setButtonAction("rbutton", nil)

	local textarea = Textarea("text", self:string("DONE_HELP"))

	local continueButton = SimpleMenu("menu")

	continueButton:addItem({
		text = (self:string("PRESS_TO_CONTINUE")),
		sound = "WINDOWSHOW",
		callback = setupNext,
		weight = 1
	})
	
	window:addWidget(textarea)
	window:addWidget(continueButton)

	self:tieAndShowWindow(window)
	return window
end
--]]


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

