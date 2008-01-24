
-- stuff we use
local oo                     = require("loop.simple")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Window                 = require("jive.ui.Window")

local jnt                    = jnt

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
							jnt:setSNBetaSetting(true);
						else
							jnt:setSNBetaSetting(false);
						end
					end,
					jnt:getSNBetaSetting()
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
