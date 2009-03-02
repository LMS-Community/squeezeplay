
-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local log                    = require("jive.utils.log").logger("applets.setup")
local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow(self, menuItem)
	local window = Window("text_list", menuItem.text, 'settingstitle')

	local menu = SimpleMenu("menu", {
					{
						text = self:string("RESET_CANCEL"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("RESET_CONTINUE"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_factoryReset()
							   end
					},
				})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _factoryReset(self)
	-- disconnect from Player/SqueezeCenter
	appletManager:callService("disconnectPlayer")

	local popup = Popup("waiting_popup")
	popup:addWidget(Icon("icon_connected"))
	popup:addWidget(Label("text", self:string("RESET_RESETTING")))

	-- make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)

	-- we're shutting down, so prohibit any key presses or holds
	Framework:addListener(EVENT_ALL_INPUT,
			      function () 
				      return EVENT_CONSUME
			      end,
			      true)

	popup:addTimer(2000, function()
				     log:info("Factory reset...")

				     -- touch .factoryreset and reboot
				     io.open("/.factoryreset", "w"):close()
				     os.execute("/bin/busybox reboot -f")
			      end)

	self:tieAndShowWindow(popup)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
