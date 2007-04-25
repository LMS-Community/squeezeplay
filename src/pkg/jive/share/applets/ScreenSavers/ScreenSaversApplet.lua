
--[[
=head1 NAME

applets.ScreenSavers.ScreenSaversApplet - Screensaver manager.

=head1 DESCRIPTION

This applets hooks itself into Jive to provide a screensaver
service, complete with settings.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
ScreenSaversApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Timer            = require("jive.ui.Timer")
local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Label            = require("jive.ui.Label")
local Textarea         = require("jive.ui.Textarea")
local table            = require("jive.utils.table")

local log              = require("jive.utils.log").logger("screensavers")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local KEY_PLAY         = jive.ui.KEY_PLAY


module(...)
oo.class(_M, Applet)


--[[

=head2 applets.ScreenSavers.ScreenSaversApplet:displayName()

Overridden to return the string "Screensavers".

=cut
--]]
function displayName(self)
	return "Screensavers"
end


--[[

=head2 applets.ScreenSavers.ScreenSaversApplet:defaultSettings()

Overridden to return the appropriate default settings.

=cut
--]]
function defaultSettings(self)
	return {
		whenStopped = "None",
		whenPlaying = "None",
		whenDocked = "None",
		timeout = 60000,
	}
end


function __init(self, ...)

	local obj = oo.rawnew(self, Applet(...))


	obj.screensavers = {}
	obj.screensaver_settings = {}
	obj:addScreenSaver("None", nil, nil)

	-- FIXME can't access settings in constructor
	local timeout = 20000 --self:getSettings()["timeout"]
	obj.timer = Timer(timeout, function() obj:_activate() end, true)
	obj.timer:start()

	Framework:addListener(
		EVENT_KEY_PRESS | EVENT_SCROLL,
		function()
			obj:_event()
		end
	)

	return obj
end


--[[

=head2 applets.ScreenSavers.ScreenSaversApplet:free()

Overridden to return always false, this ensure the applet is
permanently loaded.

=cut
--]]
function free(self)
	-- ScreenSavers cannot be freed
	return false
end


--_event()
--Restart the screensaver timer on a key press or scroll event. Any active screensaver
--will be closed.
function _event(self)
	if self.active then
		self.active:hide()
		self.active = nil
	end

	self.timer:restart()
end


--_activate(the_screensaver)
--Activates the screensaver C<the_screensaver>. If <the_screensaver> is nil then the
--screensaver set for the current mode is activated.
function _activate(self, the_screensaver)
	log:debug("Screensaver activate")

	if the_screensaver == nil then
		-- TODO discover the play mode
		the_screensaver = self:getSettings()["whenDocked"]
	end

	local screensaver = self.screensavers[the_screensaver]
	if screensaver == nil or screensaver.applet == nil then
		-- no screensaver, do nothing
		return
	end

	-- activate the screensaver
	self.timer:stop()
	self.active = appletManager:openWindow(screensaver.applet, screensaver.method)
end


function addScreenSaver(self, display_name, applet, method, settings_name, settings)
	self.screensavers[display_name] = {
		applet = applet,
		method = method,
		settings = settings
	}

	if settings_name then
		self.screensaver_settings[settings_name] = self.screensavers[display_name]
	end
end


function setScreenSaver(self, mode, display_name)
	self:getSettings()[mode] = display_name
end


function setTimeout(self, timeout)
	self:getSettings()["timeout"] = timeout
	self.timer:setInterval(timeout)
end


function screensaverSetting(self, menu_item, mode)
	local window, menu = Window:newMenuWindow("menuhelp", menu_item:getValue())

	local active_screensaver = self:getSettings()[mode]

	local group = RadioGroup()
	for display_name, screensaver in table.pairsByKeys(self.screensavers) do
	
		local button = RadioButton(
			"radio", 
			group, 
			function()
				self:setScreenSaver(mode, display_name)
			end,
			display_name == active_screensaver
		)

		-- pressing play should play the screensaver, so we need a handler
		button:addListener(EVENT_KEY_PRESS,
			function(evt)
				if evt:getKeycode() == KEY_PLAY then
					self:_activate(display_name)
					return EVENT_CONSUME
				end
			end
		)

		menu:addItem(Label("label", display_name, button))
	end

	window:addWidget(Textarea("help", "Press Center to select screensaver or PLAY to preview"))

	-- FIXME window focus workaround
	window:removeWidget(menu)
	window:addWidget(menu)

	return window
end


function timeoutSetting(self, menu_item)
	local group = RadioGroup()

	local timeout = self:getSettings()["timeout"]
	
	return (Window:newMenuWindow(
		self:displayName(), 
		menu_item:getValue(),
		{
			{
				"30 Seconds", 
				RadioButton("radio", group, function() self:setTimeout(30000) end, timeout == 30000),
			},
			{
				"1 Minute", 
				RadioButton("radio", group, function() self:setTimeout(60000) end, timeout == 60000),
			},
			{ 
				"2 Minutes", 
				RadioButton("radio", group, function() self:setTimeout(120000) end, timeout == 120000),
			},
			{
				"5 Minutes", 
				RadioButton("radio", group, function() self:setTimeout(300000) end, timeout == 300000),
			},
			{ 
				"10 Minutes", 
				RadioButton("radio", group, function() self:setTimeout(600000) end, timeout == 600000),
			},
		}))
end


function openSettings(self, menu_item)

	local window, menu = Window:newMenuWindow(
		self:displayName(), 
		menu_item:getValue(),
		{
			{ 
				"When docked", 
				nil,
				function(event, menu_item)
					self:screensaverSetting(menu_item, "whenDocked"):show()
					return EVENT_CONSUME
				end
			},
			{ 
				"When playing", 
				nil,
				function(event, menu_item)
					self:screensaverSetting(menu_item, "whenPlaying"):show()
					return EVENT_CONSUME
				end
			},
			{
				"When stopped", 
				nil,
				function(event, menu_item)
					self:screensaverSetting(menu_item, "whenStopped"):show()
					return EVENT_CONSUME
				end
			},
			{
				"Delay", 
				nil,
				function(event, menu_item)
					self:timeoutSetting(menu_item):show()
					return EVENT_CONSUME
				end
			},
		})

	for setting_name, screensaver in table.pairsByKeys(self.screensaver_settings) do
		local menuItem = menu:addItem(Label("label", setting_name))
		menuItem:addListener(EVENT_ACTION,
			function(menu_item)
				appletManager:openWindow(
					screensaver.applet, 
					screensaver.settings, 
					menuItem
				):show()
				return EVENT_CONSUME
			end)
	end


	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

