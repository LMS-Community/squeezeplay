
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
local pairs, type = pairs, type

local table           = require("table")

local oo              = require("loop.simple")

local Applet          = require("jive.Applet")
local RadioButton     = require("jive.ui.RadioButton")
local RadioGroup      = require("jive.ui.RadioGroup")
local Checkbox      = require("jive.ui.Checkbox")

local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")

local JiveMain        = jiveMain


module(..., Framework.constants)
oo.class(_M, Applet)


function selectSkin(self, menuItem)
	local window = Window("text_list", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local group = RadioGroup()

	-- add skins
	local selectedSkin = JiveMain:getSelectedSkin()
	for appletName, name in JiveMain:skinIterator() do
		menu:addItem({
			text = name,
			style = 'item_choice',
			check = RadioButton(
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

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

