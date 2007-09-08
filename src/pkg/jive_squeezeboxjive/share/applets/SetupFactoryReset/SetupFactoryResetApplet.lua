
-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local log                    = require("jive.utils.log").logger("applets.setup")


module(...)
oo.class(_M, Applet)


function settingsShow(self, menuItem)
	local window = Window("window", menuItem.text)

	local menu = SimpleMenu("menu", {
					{
						text = self:string("RESET_CANCEL"),
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("RESET_CONTINUE"),
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
	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnected"))
	window:addWidget(Label("text", self:string("RESET_RESETTING")))

	window:addTimer(2000, function()
				      log:warn("Factory reset...")

				      -- touch .factoryreset and reboot
				      io.open("/.factoryreset", "w"):close()
				      os.execute("/bin/busybox reboot -n -f")
			      end)

	self:tieAndShowWindow(window)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
