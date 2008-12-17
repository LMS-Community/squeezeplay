
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
local Button           = require("jive.ui.Button")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")

--local Wireless         = require("jive.net.Wireless")
local Wireless         = require("jive.net.georgeWireless")

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
--	self:storeSettings()

	-- remove Return to Setup from JiveMain
	jiveMain:removeItemById('returnToSetup')

	log:info("unsubscribe")
	jnt:unsubscribe(self)
end


function georgeStep1(self)
	-- add 'RETURN_TO_SETUP' at top
	log:debug('georgeStep1')
	local returnToSetup = {
		id   = 'returnToSetup',
		node = 'home',
		text = self:string("RETURN_TO_SETUP"),
		weight = 2,
		callback = function()
			self:georgeStep1()
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
	self._topWindow = appletManager:callService("setupShowSetupLanguage", function() self:georgeStep2() end, 'setupfirsttitle', true)

	return self.topWindow
end

function georgeStep2(self)
	log:info("georgeStep2")

	-- welcome!
	return self:setupWelcomeShow( function() self:georgeStep3() end , welcomeTitleStyle)
end

function georgeStep3(self)
	log:info("georgeStep3")

	-- wireless region
	return appletManager:callService("georgeSetupRegionShow", function() self:georgeStep3a() end, welcomeTitleStyle)
	
end

function georgeStep3a(self)

	log:info("georgeStep3a")

	-- network connection type
	return appletManager:callService("georgeSetupConnectionType", 
					function() self:georgeStep4() end, 
					function() self:georgeStep6() end, 
					welcomeTitleStyle)

end

function georgeStep4(self)
	log:info("georgeStep4")

	-- finding networks
	self.scanWindow = appletManager:callService("georgeSetupScanShow", function()
							   self:georgeStep5()
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

function setupScanShow(self, setupNext, windowTitleStyle)
	local window = Popup("popupIcon")
	window:setAllowScreensaver(false)

	window:addWidget(Icon("iconConnecting"))
	window:addWidget(Label("text", self:string("NETWORK_SCANNING")))
	local status = Label("text2", self:string("NETWORK_FOUND_NETWORKS", 0))
	window:addWidget(status)

        -- or timeout after 5 seconds if no networks are found
        window:addTimer(5000, function() setupNext() end)
	local state = 1
        window:addTimer(1000, function()
                                       if state == 1 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 1))
                                       elseif state == 2 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 4))
                                       elseif state == 3 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 5))
                                       elseif state == 4 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 8))
                                       elseif state == 5 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 10))
                                       elseif state == 6 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 11))
                                       elseif state == 7 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 4000))
                                       elseif state == 8 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 'just kidding'))
                                       elseif state == 9 then
                                               status:setValue(self:string("NETWORK_FOUND_NETWORKS", 11))
                                       end
                                       state = state + 1
                               end)

        self:tieAndShowWindow(window)
        return window
end

function georgeStep5(self)
	log:info("georgeStep5")

	-- wireless connection, using squeezebox?
	local scanResults = Wireless.scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("******************************checking ssid ", ssid)

		if string.match(ssid, "logitech%+squeezebox%+%x+") then
			return self:setupConnectionShow(function() self:georgeStep51() end,
							function() self:georgeStep52() end
						)
		end
	end

	return self:georgeStep52()
end

function georgeStep51(self)
	log:info("georgeStep51")

	-- connect using squeezebox in adhoc mode
	return appletManager:callService("georgeSetupAdhocShow", function() self:georgeStep8() end)
end

function georgeStep52(self)
	log:info("georgeStep52")

	-- connect using other wireless network
	return appletManager:callService("georgeSetupNetworksShow", function() self:georgeStep6() end, welcomeTitleStyle)
end

function georgeStep6(self)
	log:info("georgeStep6")

	-- wireless connection, using squeezebox?
	local scanResults = Wireless.scanResults()

	for ssid,_ in pairs(scanResults) do
		log:warn("checking ssid ", ssid)

		if string.match(ssid, "logitech[%-%+]squeezebox[%-%+]%x+") then
			return self:georgeStep61()
		end
	end

	return self:georgeStep7()
end

function georgeStep61(self)
	log:info("georgeStep61")

	-- setup squeezebox
	return appletManager:callService("georgeSetupSqueezeboxShow", function() self:georgeStep7() end)
end

function georgeStep7(self)
	log:info("georgeStep7")

	-- skip this step if a player has been selected
	if appletManager:callService("getCurrentPlayer") then
		return self:georgeStep8()
	end

	-- select player
	return appletManager:callService("setupShowSelectPlayer", function() self:georgeStep8() end, welcomeTitleStyle)
end

function georgeStep8(self)
	log:info("georgeStep8")

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
                             Label("touchButton", self:string("TOUCH_TO_CONTINUE")),
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

