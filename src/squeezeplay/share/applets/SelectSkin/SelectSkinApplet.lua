
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
local System        = require("jive.System")
local debug            = require("jive.utils.debug")

local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local appletManager   = appletManager

local JiveMain        = jiveMain


module(..., Framework.constants)
oo.class(_M, Applet)

local _defaultSkinNameForType = {
		["touch"] = "WQVGAsmallSkin",
		["remote"] = "WQVGAlargeSkin",
}


--service method
function getSelectedSkinNameForType(self, skinType)
	return self:getSettings()[skinType] or _defaultSkinNameForType[skinType]
end


function selectSkinEntryPoint(self, menuItem)
	if System:hasTouch() and System:isHardware() then
		local window = Window("text_list", menuItem.text, 'settingstitle')
		local menu = SimpleMenu("menu")
		menu:addItem({
			text = self:string("SELECT_SKIN_TOUCH_SKIN"),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
				self:selectSkin(self:string("SELECT_SKIN_TOUCH_SKIN"), "touch", self:getSelectedSkinNameForType("touch"))
			end
			
		})
		menu:addItem({
			text = self:string("SELECT_SKIN_REMOTE_SKIN"),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
				self:selectSkin(self:string("SELECT_SKIN_REMOTE_SKIN"), "remote", self:getSelectedSkinNameForType("remote"))
			end
			
		})

		window:addWidget(menu)
	
		self:tieAndShowWindow(window)
		return window

	else
		return selectSkin(self, menuItem.text, "skin", JiveMain:getSelectedSkin())
	end
end


function selectSkin(self, title, skinType, previouslySelectedSkin)
	local window = Window("text_list", title, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local group = RadioGroup()

	-- add skins
	for appletName, name in JiveMain:skinIterator() do
		menu:addItem({
			text = name,
			style = 'item_choice',
			check = RadioButton(
				"radio", 
				group, 
				function()
					local activeSkinType = appletManager:callService("getActiveSkinType") or "skin"
					if activeSkinType == skinType then
						--current type is active, so immediately switch the overall selected skin
						JiveMain:setSelectedSkin(appletName)
					end

					self:getSettings()[skinType] = appletName
					self.changed = true
				end,
				appletName == previouslySelectedSkin
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

