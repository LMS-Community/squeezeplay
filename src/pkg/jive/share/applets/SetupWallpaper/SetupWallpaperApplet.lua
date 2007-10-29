
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
local ipairs = ipairs

local oo                     = require("loop.simple")

local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local AppletManager          = require("jive.AppletManager")
local Framework              = require("jive.ui.Framework")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")

local EVENT_FOCUS_GAINED     = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST       = jive.ui.EVENT_FOCUS_LOST
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP


local print, tostring = print, tostring


module(...)
oo.class(_M, Applet)


-- Wallpapers
local wallpapers = {
	{
		["SUNRISE"] = "sunrise.png",
	},
	{
		["SUNLIGHT"] = "sunlight.png",
		["FADETOBLACK"] = "fade_to_black.png",
	},
	{
		["CONCRETE"] = "concrete.png",
		["MIDNIGHT"] = "midnight.png",
		["PEA"] = "pea.png",
		["BLACK"] = "black.png",
		["STONE"] = "stone.png",
	},
	{
		["DUNES"] = "Chapple_1.jpg",
		["IRIS"] = "Clearly-Ambiguous_1.jpg",
		["SMOKE"] = "Clearly-Ambiguous_3.jpg",
		["AMBER"] = "Clearly-Ambiguous_4.jpg",
		["FLAME"] = "Clearly-Ambiguous_6.jpg",
		["GRAFFITI"] = "Los-Cardinalos_1.jpg",
		["WEATHERED_WOOD"] = "Orin-Optiglot_1.jpg",
	}
}

local authors = { "Chapple", "Scott Robinson", "Los Cardinalos", "Orin Optiglot" }



function setupShow(self, setupNext)
	local window = Window("window", self:string('WALLPAPER'), 'settingstitle')
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local currentPlayer = _getCurrentPlayer()
	local wallpaper = self:getSettings()[currentPlayer]

        menu:setComparator(menu.itemComparatorAlphaWeight)

	for weight, section in ipairs(wallpapers) do
		for name, file in table.pairsByKeys(section) do
			menu:addItem({
					     text = self:string(name), 
					     callback = function()
								self:_setBackground(file, currentPlayer)
								setupNext()
							end,
					     focusGained = function(event)
								   self:_showBackground(file)
							   end
				     })

			if wallpaper == file then
				menu:setSelectedIndex(menu:numItems())
			end
		end
	end
	menu:addItem(self:_licenseMenuItem(currentPlayer))

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:_showBackground(nil, currentPlayer)
			self:storeSettings()
		end
	)

	self:tieAndShowWindow(window)
	return window
end

function _getCurrentPlayer(self)
	local manager = AppletManager:getAppletInstance("SlimDiscovery")
	-- defaults to 'wallpaper' for backward compatibility to when wallpaper selection was not player-specific
	local currentPlayer = 'wallpaper' 
	if manager then
		local currentPlayerObj = manager:getCurrentPlayer()
		if currentPlayerObj.id then
			currentPlayer = currentPlayerObj.id
		end
	end
	return currentPlayer
end

function settingsShow(self)
	local window = Window("window", self:string('WALLPAPER'), 'settingstitle')
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local currentPlayer = _getCurrentPlayer()
	local wallpaper = self:getSettings()[currentPlayer]
	
	local group = RadioGroup()

        menu:setComparator(menu.itemComparatorAlphaWeight)
	
	for weight, section in ipairs(wallpapers) do
		for name, file in table.pairsByKeys(section) do
			menu:addItem({
					     text = self:string(name), 
					     icon = RadioButton("radio", 
								group, 
								function()
									self:_setBackground(file, currentPlayer)
								end,
								wallpaper == file
							),
					     focusGained = function(event)
								   self:_showBackground(file, currentPlayer)
							   end
				     })

			if wallpaper == file then
				menu:setSelectedIndex(menu:numItems())
			end
		end
	end

	menu:addItem(self:_licenseMenuItem(currentPlayer))

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:_showBackground(nil, currentPlayer)
			self:storeSettings()
		end
	)

	self:tieAndShowWindow(window)
	return window
end


function _licenseMenuItem(self, playerId)
	return {
		text = self:string("CREDITS"),
		callback = function()
			local window = Window("window", self:string("CREDITS"))
			
			local text =
				tostring(self:string("CREATIVE_COMMONS")) ..
				"\n\n" ..
				tostring(self:string("CREDITS_BY")) ..
				"\n " ..
				table.concat(authors, "\n ")

			window:addWidget(Textarea("textarea", text))
			self:tieAndShowWindow(window)
		end,
		focusGained = function(event) self:_showBackground(nil, playerId) end
	}
end


function _showBackground(self, wallpaper, playerId)
	if not playerId then playerId = 'wallpaper' end
	if not wallpaper then
		wallpaper = self:getSettings()[playerId]
		if not wallpaper then
			wallpaper = self:getSettings()["wallpaper"]
		end
	end

	local srf = Tile:loadImage("applets/SetupWallpaper/wallpaper/" .. wallpaper)
	if srf ~= nil then
		Framework:setBackground(srf)
	end
end


function _setBackground(self, wallpaper, playerId)
	if not playerId then playerId = 'wallpaper' end
	-- set the new wallpaper, or use the existing setting
	if wallpaper then
		self:getSettings()[playerId] = wallpaper
	end

	self:_showBackground(wallpaper, playerId)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

