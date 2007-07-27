
--[[
=head1 NAME

applets.SetupLanguage.SetupLanguage - Add a main menu option for setting up language

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
local SimpleMenu       = require("jive.ui.SimpleMenu")
local table            = require("jive.utils.table")
local Window           = require("jive.ui.Window")

local log              = require("jive.utils.log").logger("applets.setup")
local locale           = require("jive.utils.locale")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local KEY_PLAY         = jive.ui.KEY_PLAY

module(...)
oo.class(_M, Applet)

function displayName(self)
	-- this should be changed to a localized string
	--return "Setup Language"
	return "Setup Language"
end

function setupLanguage(self, menuItem)
	local currentLocale = self:getSettings()["locale"]
	if currentLocale == nil then
		currentLocale = "EN"
	end
	self:setLang(currentLocale)
	log:info("locale currently is ", currentLocale)
	log:info("setupLanguage invoked...")
	-- setup menu
	local group = RadioGroup()
	local window = Window(self:displayName(), menuItem.text)
	local menu = SimpleMenu("Menu")

	local availableLanguages = { 
				["EN"] = "English", 
				["DE"] = "Deutsch", 
				["ES"] = "Espanol",
				["FR"] = "Francais",
				["IT"] = "Italiano",
				["NL"] = "Nederlands",
				}

	for locale, languageChoice in pairs(availableLanguages) do 
		local button = RadioButton(
			"radio", 
			group, 
			function() self:setLang(locale) end, 
			locale == currentLocale
		)
		menu:addItem({
			text = languageChoice,
			icon = button,
		})
	end
	window:addWidget(menu)

       -- Store the selected language when the menu is exited
        window:addListener(EVENT_WINDOW_POP,
                function()
                        self:storeSettings()
                end
        )
	return window
end

function setLang(self, choice)
	log:info("Locale choice set to ", choice)
	self:getSettings()['locale'] = choice
	local stringsTable = locale.readStringsFile(choice, 'SetupLanguage')
	self:getSettings()['localeStrings'] = stringsTable
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

