
--[[
=head1 NAME

applets.SetupWallpaper.SetupWallpaperApplet - The default Jive skin.

=head1 DESCRIPTION

This applet implements the default Jive skin. It can
be used as a model to provide alternate skins for Jive.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SetupWallpaperApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo                     = require("loop.simple")

local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")

local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP


local print, tostring = print, tostring

module(...)
oo.class(_M, Applet)


-- Wallpapers
local wallpapers = {
	["Chapple_1.jpg"] = "Chapple_1.jpg",
	["Clearly-Ambiguous_1.jpg"] = "Clearly-Ambiguous_1.jpg",
	["Clearly-Ambiguous_2.jpg"] = "Clearly-Ambiguous_2.jpg",
	["Clearly-Ambiguous_3.jpg"] = "Clearly-Ambiguous_3.jpg",
	["Clearly-Ambiguous_4.jpg"] = "Clearly-Ambiguous_4.jpg",
	["Clearly-Ambiguous_6.jpg"] = "Clearly-Ambiguous_6.jpg",
	["Los-Cardinalos_1.jpg"] = "Los-Cardinalos_1.jpg",
	["Orin-Optiglot_1.jpg"] = "Orin-Optiglot_1.jpg",
}

local backgroundLicense = "The background images are under a Creative Commons Attribution license. See http://creativecommons.org/licenses/by/3.0/.\n\nThe Credits\n Chapple\n Scott Robinson\n Los Cardinalos\n Orin Optiglot\n"


--[[

=head2 applets.DefaultSkin.DefaultSkinApplet:defaultSettings()

Overridden to return the default wallpaper selected.

=cut
--]]
function defaultSettings(self)
	return { 
		wallpaper = "Chapple_1.jpg",
	}
end


-- wallpaperSettings
-- The meta hooks this function to allow the user to select
-- a wallpaper
function setup(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local wallpaper = self:getSettings()["wallpaper"]
	
	local group = RadioGroup()
	
	for name, file in table.pairsByKeys(wallpapers) do
		menu:addItem({
				     text = name, 
				     icon = RadioButton("radio", 
							group, 
							function()
								self:_setBackground(file)
							end,
							wallpaper == file
						)
			     })
	end

	menu:addItem({
			     text = "License",
			     callback = function()
						local window = Window("window", "License")
						window:addWidget(Textarea("textarea", backgroundLicense))
						window:show()
					end
		     })

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	return window
end


function _setBackground(self, wallpaper)
	-- set the new wallpaper, or use the existing setting
	if wallpaper then
		self:getSettings()["wallpaper"] = wallpaper
	else
		wallpaper = self:getSettings()["wallpaper"]
	end

	local srf = Surface:loadImage("applets/SetupWallpaper/wallpaper/" .. wallpaper)
	if srf ~= nil then
		Framework:setBackground(srf)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

