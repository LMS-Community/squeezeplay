
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
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local Icon             = require("jive.ui.Icon")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Player           = require("jive.slim.Player")
local LocalPlayer      = require("jive.slim.LocalPlayer")

local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")

local jnt               = jnt
local appletManager    = appletManager

local jiveMain         = jiveMain

local disableHomeKeyDuringSetup
local freeAppletWhenEscapingSetup

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self, ...)
	jnt:subscribe(self)
end


function notify_playerCurrent(self, player)
    if not self:getSettings().setupDone then
        if player and not player:needsMusicSource() then
            log:debug("notify_playerCurrent called with a source, so finishing setup")
            self:setupDone()
        end
    end
end


function _ignoreHomeAction(self)
	log:warn("HOME KEY IS DISABLED IN SETUP. USE PRESS-HOLD BACK BUTTON INSTEAD")
	-- don't allow this event to continue
	return EVENT_CONSUME

end


function _freeAction(self)
	free(self)
	return EVENT_UNUSED

end

function startSetup(self)
	-- put Return to Setup menu item on jiveMain menu
	local returnToSetup = {
		id   = 'returnToSetup',
		node = 'home',
		text = self:string("RETURN_TO_SETUP"),
		weight = 2,
		callback = function()
			--note: don't refer to self here since the applet wil have been freed if this is being called
			appletManager:callService("startSetup")
		end
	}
	jiveMain:addItem(returnToSetup)

	self._topWindow = appletManager:callService("setupShowSetupLanguage", function() self:step2() end, 'setupfirsttitle')

	disableHomeKeyDuringSetup = Framework:addActionListener("go_home", self, _ignoreHomeAction)

	freeAppletWhenEscapingSetup = Framework:addActionListener("soft_reset", self, _freeAction)

	return self.topWindow

end

function step2(self)
	log:info("step2")
	for i, player in Player.iterate() do
		--auto select local player
		if player:isLocal() then
        		return appletManager:callService("selectPlayer", player)
	        end
	end
	return appletManager:callService("setupShowSelectPlayer", function() end, 'setuptitle')
end


function setupDone(self)
	self:getSettings().setupDone = true
	jiveMain:removeItemById('returnToSetup')
	self:storeSettings()
        jiveMain:closeToHome(true, Window.transitionPushLeft)
end


function free(self)
	-- remove listeners when leaving this applet
	Framework:removeListener(disableHomeKeyDuringSetup)
	Framework:removeListener(freeAppletWhenEscapingSetup)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

