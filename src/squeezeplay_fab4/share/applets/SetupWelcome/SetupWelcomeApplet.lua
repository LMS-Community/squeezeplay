
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

local debug            = require("jive.utils.debug")
local locale           = require("jive.utils.locale")
local string           = require("jive.utils.string")
local table            = require("jive.utils.table")

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt              = jnt

--This can be enabled for situations like MP where a fw upgrade is absolutely required to complete setup
local UPGRADE_FROM_SCS_ENABLED = false

module(..., Framework.constants)
oo.class(_M, Applet)


function startSetup(self)
	-- flag to SN that we are in setup for testing
	jnt.inSetupHack = true

	step1(self)
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
	log:info('step1')
	self:_addReturnToSetupToHomeMenu()
	self:_disableNormalEscapeMechanisms()

	-- choose language
	appletManager:callService("setupShowSetupLanguage",
		function()
			self:step2()
		end, false)
end


function step2(self, transition)
	log:info("step2")
	self:_disableNormalEscapeMechanisms()

	-- network connection type
	appletManager:callService("setupNetworking", 
		function()
			self:step3(iface)
		end,
	transition)
end


function step3(self)
	log:info("step3")

	-- automatically setup local player as selected player
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			appletManager:callService("setCurrentPlayer", player)
			return self:step4()
		end
        end

	-- this should never be called
	log:error("no local player found?")
	return appletManager:callService("setupShowSelectPlayer",
		function()
			self:step4()
		end, 'setuptitle')
end


function step4(self)
	log:info("step4")

	if UPGRADE_FROM_SCS_ENABLED then
		appletManager:callService("waitForSqueezenetwork")
	end

	-- Once here, network setup is complete
	self:_setupComplete(false)
	self:_setupDone(true)

	self.locked = true -- free applet
	jnt:unsubscribe(self)

	jiveMain:goHome()

end

function _setupDone(self, setupDone)
	log:info("network setup complete")

	local settings = self:getSettings()

	settings.setupDone = setupDone
	self:storeSettings()

end

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

