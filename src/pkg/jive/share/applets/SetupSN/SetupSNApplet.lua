
-- stuff we use
local oo                     = require("loop.simple")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Window                 = require("jive.ui.Window")

local log                    = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, Applet)

function settingsShow(self, menuItem)
	local window = Window("window", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu", {
		{
			text = self:string("SN_BETA_ENABLE"),
			icon = Checkbox("checkbox",
					function(_, isSelected)
						if isSelected then
							self:getSettings()["use_sn_beta"] = true
							self:storeSettings()
						else
							self:getSettings()["use_sn_beta"] = false
							self:storeSettings()
						end
					end,
					self:getSettings()["use_sn_beta"]
				)
		},
	})

	window:addWidget(menu)

	self.window = window
	self.menu = menu

	self:tieAndShowWindow(window)
	return window
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
