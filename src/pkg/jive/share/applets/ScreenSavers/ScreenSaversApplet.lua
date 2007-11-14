
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
local ipairs, pairs, tostring = ipairs, pairs, tostring

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local AppletManager    = require("jive.AppletManager")
local Timer            = require("jive.ui.Timer")
local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Textarea         = require("jive.ui.Textarea")
local string           = require("string")
local table            = require("jive.utils.table")

local log              = require("jive.utils.log").logger("applets.screensavers")

local appletManager    = appletManager
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_MOTION     = jive.ui.EVENT_MOTION
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_INACTIVE = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local KEY_PLAY         = jive.ui.KEY_PLAY
local KEY_GO           = jive.ui.KEY_GO


module(...)
oo.class(_M, Applet)


function init(self, ...)

	self.screensavers = {}
	self.screensaverSettings = {}
	self:addScreenSaver(self:string("SCREENSAVER_NONE"), nil, nil, _, _, 100)

	self.timeout = self:getSettings()["timeout"]

	self.timer = Timer(self.timeout, function() self:_activate() end, true)
	self.timer:start()

	-- listener to restart screensaver timer
	Framework:addListener(
		EVENT_KEY_PRESS | EVENT_SCROLL | EVENT_MOTION,
		function(event)
			self.timer:restart(self.timeout)

			-- allow active screensaver to process events if
			-- it is on top of the window stack
			if self.active == Framework.windowStack[1] and
				-- motion should not exit the screensaver,
				-- it was too annoying having Now Playing
				-- disappear when you picked it up!
				event:getType() ~= EVENT_MOTION then

				local r = self.active:_event(event)

				if r == EVENT_UNUSED and self.active then
					self.active:hide(Window.transitionNone)
				end

				-- Go should close the screensaver, and not
				-- perform an action
				if event:getType() == EVENT_KEY_PRESS and
					event:getKeycode() == KEY_GO then
					return EVENT_CONSUME
				end
				return r
			end
			return EVENT_UNUSED
		end
	)

	return self
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


--_activate(the_screensaver)
--Activates the screensaver C<the_screensaver>. If <the_screensaver> is nil then the
--screensaver set for the current mode is activated.
function _activate(self, the_screensaver)
	log:debug("Screensaver activate")

	-- check if the top window will allow screensavers, if not then
	-- set the screensaver to activate 10 seconds after the window
	-- is closed, assuming we still don't have any activity
	if not Framework.windowStack[1]:canActivateScreensaver() then
		Framework.windowStack[1]:addListener(
			EVENT_WINDOW_INACTIVE,
			function()
				if not self.timer:isRunning() then
					self.timer:restart(10000)
				end
			end)
		return
	end

	if the_screensaver == nil then
		local sd = AppletManager:getAppletInstance("SlimDiscovery")
		
		if sd and sd:getCurrentPlayer() and sd:getCurrentPlayer():getPlayMode() == "play" then
			the_screensaver = self:getSettings()["whenPlaying"]
		else
			the_screensaver = self:getSettings()["whenStopped"]
		end
	end

	local screensaver = self.screensavers[the_screensaver]
	if screensaver == nil or screensaver.applet == nil then
		-- no screensaver, do nothing
		return
	end

	-- activate the screensaver
	self.timer:stop()
	local instance = appletManager:loadApplet(screensaver.applet)
	self.active = instance[screensaver.method](instance)

	self.active:addListener(EVENT_WINDOW_POP,
				function()
					log:warn("screensaver is inactive")
					self.active = nil
				end)
end


function addScreenSaver(self, displayName, applet, method, settingsName, settings, weight)
	local key = tostring(applet) .. ":" .. tostring(method)
	self.screensavers[key] = {
		applet = applet,
		method = method,
		displayName = displayName,
		settings = settings,
		weight = weight
	}

	if settingsName then
		self.screensaverSettings[settingsName] = self.screensavers[key]
	end
end


function setScreenSaver(self, mode, key)
	self:getSettings()[mode] = key
end


function setTimeout(self, timeout)
	self:getSettings()["timeout"] = timeout

	self.timeout = timeout
	self.timer:setInterval(self.timeout)
end


function screensaverSetting(self, menuItem, mode)
	local menu = SimpleMenu("menu")
        menu:setComparator(menu.itemComparatorWeightAlpha)

	local activeScreensaver = self:getSettings()[mode]

	local group = RadioGroup()
	for key, screensaver in pairs(self.screensavers) do
		local button = RadioButton(
			"radio", 
			group, 
			function()
				self:setScreenSaver(mode, key)
			end,
			key == activeScreensaver
		)

		-- pressing play should play the screensaver, so we need a handler
		button:addListener(EVENT_KEY_PRESS,
			function(evt)
				if evt:getKeycode() == KEY_PLAY then
					self:_activate(key)
					return EVENT_CONSUME
				end
			end
		)
		-- set default weight to 100
		if not screensaver.weight then screensaver.weight = 100 end
		menu:addItem({
				text = screensaver.displayName,
				icon = button,
				weight = screensaver.weight
			     })
	end

	local window = Window("screensavers", menuItem.text, 'settingstitle')
	window:addWidget(Textarea("help", "Press Center to select screensaver or PLAY to preview"))
	window:addWidget(menu)

	window:addListener(EVENT_WINDOW_POP, function() self:storeSettings() end)

	self:tieAndShowWindow(window)
	return window
end


function timeoutSetting(self, menuItem)
	local group = RadioGroup()

	local timeout = self:getSettings()["timeout"]
	
	local window = Window("window", menuItem.text, 'settingstitle')
	window:addWidget(SimpleMenu("menu",
		{
			{
				text = self:string('DELAY_10_SEC'),
				icon = RadioButton("radio", group, function() self:setTimeout(10000) end, timeout == 10000),
			},
			{
				text = self:string('DELAY_20_SEC'),
				icon = RadioButton("radio", group, function() self:setTimeout(20000) end, timeout == 20000),
			},
			{
				text = self:string('DELAY_30_SEC'),
				icon = RadioButton("radio", group, function() self:setTimeout(30000) end, timeout == 30000),
			},
			{
				text = self:string('DELAY_1_MIN'),
				icon = RadioButton("radio", group, function() self:setTimeout(60000) end, timeout == 60000),
			},
			{ 
				text = self:string('DELAY_2_MIN'),
				icon = RadioButton("radio", group, function() self:setTimeout(120000) end, timeout == 120000),
			},
			{
				text = self:string('DELAY_5_MIN'),
				icon = RadioButton("radio", group, function() self:setTimeout(300000) end, timeout == 300000),
			},
			{ 
				text = self:string('DELAY_10_MIN'),
				icon = RadioButton("radio", group, function() self:setTimeout(600000) end, timeout == 600000),
			},
			{ 
				text = self:string('DELAY_30_MIN'),
				icon = RadioButton("radio", group, function() self:setTimeout(1800000) end, timeout == 1800000),
			},
		}))

	window:addListener(EVENT_WINDOW_POP, function() self:storeSettings() end)

	self:tieAndShowWindow(window)
	return window
end


function openSettings(self, menuItem)

	local menu = SimpleMenu("menu",
		{
			{ 
				text = self:string('SCREENSAVER_PLAYING'),
				weight = 1,
				sound = "WINDOWSHOW",
				callback = function(event, menu_item)
						   self:screensaverSetting(menu_item, "whenPlaying")
					   end
			},
			{
				text = self:string("SCREENSAVER_STOPPED"),
				weight = 1,
				sound = "WINDOWSHOW",
				callback = function(event, menu_item)
						   self:screensaverSetting(menu_item, "whenStopped")
					   end
			},
			{
				text = self:string("SCREENSAVER_DELAY"),
				weight = 2,
				sound = "WINDOWSHOW",
				callback = function(event, menu_item)
						   self:timeoutSetting(menu_item)
					   end
			},
		})

	menu:setComparator(menu.itemComparatorWeightAlpha)
	for setting_name, screensaver in pairs(self.screensaverSettings) do
		menu:addItem({
				     text = setting_name,
				     weight = 3,
				     sound = "WINDOWSHOW",
				     callback =
					     function(event, menuItem)
							local instance = appletManager:loadApplet(screensaver.applet)
							instance[screensaver.settings](instance, menuItem)
					     end
			     })
	end

	local window = Window("window", menuItem.text, 'settingstitle')
	window:addWidget(menu)

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
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

