
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
local ipairs, pairs, io, string = ipairs, pairs, io, string

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")
local Icon             = require("jive.ui.Icon")
local Timer            = require("jive.ui.Timer")

local log              = require("jive.utils.log").logger("applets.setup")
local locale           = require("jive.utils.locale")
local table            = require("jive.utils.table")
local debug            = require("jive.utils.debug")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local KEY_PLAY         = jive.ui.KEY_PLAY

local jiveMain         = jiveMain

module(...)
oo.class(_M, Applet)


function setupShow(self, setupNext)
	local currentLocale = locale:getLocale()
	log:info("locale currently is ", currentLocale)

	-- this uses private data/methods from Applet and locale. don't do this elsewhere,
	-- but it's needed for speed here
	self.allStrings = locale:loadAllStrings(self._entry.stringsFilepath)

	-- setup menu
	local window = Window("window", self:string("CHOOSE_LANGUAGE"), 'settingstitle')
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")

	for _, locale in ipairs(locale:getAllLocales()) do 
		menu:addItem({
		        text = self:string("LANGUAGE_" .. locale),
			sound = "WINDOWSHOW",
			callback = function()
					   self:setLang(locale)
					   self:storeSettings()
					   setupNext()
				   end,
			focusGained = function() self:_showLang(locale) end
		})

		if locale == currentLocale then
			menu:setSelectedIndex(menu:numItems())
		end
	end


	window:addWidget(Textarea("help", self:string("CHOOSE_LANGUAGE_HELP")))
	window:addWidget(menu)

	-- Store the selected language when the menu is exited
        window:addListener(EVENT_WINDOW_POP,
                function()
			self:_showLang(nil)
                        self:storeSettings()
                end
        )

	-- You have to select your language, no way to close this menu
	menu:setCloseable(false)

	self:tieAndShowWindow(window)
	return window
end


function settingsShow(self, menuItem)
	local currentLocale = locale:getLocale()
	log:info("locale currently is ", currentLocale)

	-- this uses private data/methods from Applet and locale. don't do this elsewhere,
	-- but it's needed for speed here
	self.allStrings = locale:loadAllStrings(self._entry.stringsFilepath)

	-- setup menu
	local window = Window("window", self:string("LANGUAGE"), 'settingstitle')
	local menu = SimpleMenu("menu")

	local group = RadioGroup()
	for _, locale in ipairs(locale:getAllLocales()) do 
		local button = RadioButton(
			"radio", 
			group, 
			function() self:setLang(locale) end, 
			locale == currentLocale
		)
		menu:addItem({
		        text = self:string("LANGUAGE_" .. locale),
			icon = button,
			focusGained = function() self:_showLang(locale) end
		})

		if locale == currentLocale then
			menu:setSelectedIndex(menu:numItems())
		end
	end

	window:addWidget(menu)

	-- Store the selected language when the menu is exited
        window:addListener(EVENT_WINDOW_POP,
                function()
			self:_showLang(nil)
                        self:storeSettings()
                end
        )

	self:tieAndShowWindow(window)
	return window
end


function _showLang(self, choice)
	if not choice then
		choice = self:getSettings().locale
	end

	-- this modifies the Applets strings directly. don't do this elsewhere, but it's
	-- needed for speed here
	for k,v in pairs(self._stringsTable) do
		v.str = self.allStrings[choice][k] or self.allStrings["EN"][k]
	end

	Framework:styleChanged()
end

function setLang(self, choice)
	log:info("Locale choice set to ", choice)
	log:warn("YOU ARE HERE")

        local popup = Popup("popupIcon")
        popup:setAllowScreensaver(false)
        popup:addWidget(Icon("iconConnecting"))
	local stringChoice = "LANGUAGE_" .. choice
        popup:addWidget(Label("text", self:string(stringChoice)))
	-- FIXME why doesn't this popup display immediately?
	popup:show()

	local langChanged = self:_setLang(choice)
	popup:addTimer(1000, 
		function()
			if langChanged then
				popup:hide()
			end
		end
	)
end

function _setLang(self, choice)
	self:_showLang(choice)
	self:getSettings().locale = choice

	-- fetch global strings table first and then send it to setLocale 
	-- so it doesn't have to be refetched for every applet
	local globalStrings = locale:readGlobalStringsFile()
	locale:setLocale(choice, globalStrings)
	jiveMain:jiveMainNodes()
	Framework:styleChanged()
	return true
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

