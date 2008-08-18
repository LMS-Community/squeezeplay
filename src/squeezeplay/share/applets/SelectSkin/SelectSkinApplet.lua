
--[[
=head1 NAME

applets.SelectSkin.SelectSkinApplet - An applet to select different SqueezePlay skins

=head1 DESCRIPTION

This applet allows the SqueezePlay skin to be selected.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SelectSkinApplet overrides the following methods:

=cut
--]]


-- stuff we use
local pairs = pairs

local table           = require("table")

local oo              = require("loop.simple")
local logging         = require("logging")

local Applet          = require("jive.Applet")
local RadioButton     = require("jive.ui.RadioButton")
local RadioGroup      = require("jive.ui.RadioGroup")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local jul             = require("jive.utils.log")

local JiveMain        = jiveMain
local log             = jul.logger("applets.browser")


module(..., Framework.constants)
oo.class(_M, Applet)


function selectSkin(self, menuItem)
	local window = Window("window", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local group = RadioGroup()

	-- add skins
	local selectedSkin = JiveMain:getSelectedSkin()
	for appletName, name in JiveMain:skinIterator() do
		menu:addItem({
			text = name,
			icon = RadioButton(
				"radio", 
				group, 
				function()
					JiveMain:setSelectedSkin(appletName)

					self:getSettings().skin = appletName
					self.changed = true
				end,
				appletName == selectedSkin
			)
		})
	end

	window:addWidget(menu)

	window:addListener(EVENT_WINDOW_POP,
		function()
			if self.changed then
				self:storeSettings()
			end
		end
	)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

