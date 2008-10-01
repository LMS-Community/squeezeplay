
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

local log              = require("jive.utils.log").logger("applets.setup")
local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD   = jive.ui.EVENT_KEY_HOLD
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local KEY_GO           = jive.ui.KEY_GO
local KEY_BACK         = jive.ui.KEY_BACK
local KEY_HOME         = jive.ui.KEY_HOME

local jiveMain         = jiveMain

local welcomeTitleStyle = 'settingstitle'
local disableHomeKeyDuringSetup
local freeAppletWhenEscapingSetup

module(...)
oo.class(_M, Applet)

function step1(self)
	-- put Return to Setup menu item on jiveMain menu
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

	self._topWindow = appletManager:callService("setupShowSetupLanguage", function() self:step2() end)

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
	freeAppletWhenEscapingSetup =
 		Framework:addListener(EVENT_KEY_HOLD,
		function(event)
			local keycode = event:getKeycode()
			if keycode == KEY_BACK then
				free()
			end
			return EVENT_UNUSED
		end)

	return self.topWindow

--	self._topWindow = self:setupWelcome(function() self:step3() end)
--	return self._topWindow
end

function step2(self)
	return self:setupWelcome(function() self:step3() end)
end

function step3(self)
	return appletManager:callService("setupShowSelectPlayer", function() self:step4() end)
end

function step4(self)
	return self:setupDone(function()
			self._topWindow:hideToTop(Window.transitionPushLeft) 

			self:getSettings().setupDone = true
			jiveMain:removeItemById('returnToSetup')
			self:storeSettings()
		end)
end


function setupWelcome(self, setupNext)
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


function setupDone(self, setupNext)
	local window = Window("window", self:string("DONE"), welcomeTitleStyle)
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

function free(self)
	-- remove listeners when leaving this applet
	Framework:removeListener(disableHomeKeyDuringSetup)
	Framework:removeListener(freeAppletWhenEscapingSetup)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

