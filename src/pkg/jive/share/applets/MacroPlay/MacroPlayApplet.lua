
--[[
=head1 NAME

applets.MacroPlay.MarcoPlayApplet - applet to play ui sequences for testing.

=head1 DESCRIPTION

This applet will play ui sequences using a lua script for testing.

=cut
--]]


-- stuff we use
local ipairs, pairs, tostring = ipairs, pairs, tostring

local oo               = require("loop.simple")
local math             = require("math")
local table            = require("jive.utils.table")

local Applet           = require("jive.Applet")
local Event            = require("jive.ui.Event")
local Framework        = require("jive.ui.Framework")
local Menu             = require("jive.ui.Menu")
local Task             = require("jive.ui.Task")
local Timer            = require("jive.ui.Timer")

local log              = require("jive.utils.log").logger("applets.misc")


local EVENT_KEY_PRESS           = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_DOWN            = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP              = jive.ui.EVENT_KEY_UP
local EVENT_KEY_HOLD            = jive.ui.EVENT_KEY_HOLD
local EVENT_SCROLL              = jive.ui.EVENT_SCROLL
local EVENT_CONSUME             = jive.ui.EVENT_CONSUME
local EVENT_ACTION              = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP          = jive.ui.EVENT_WINDOW_POP

local KEY_BACK                  = jive.ui.KEY_BACK
local KEY_DOWN                  = jive.ui.KEY_DOWN
local KEY_HOME                  = jive.ui.KEY_HOME
local KEY_GO                    = jive.ui.KEY_GO
local KEY_PLAY                  = jive.ui.KEY_PLAY


module(...)
oo.class(_M, Applet)


-- XXX Load script from file
local script = function()
	log:info("Starting macro script")

	-- key HOME
	macroEvent(100, EVENT_KEY_PRESS, KEY_HOME)

	while true do
		-- key down until Choose Player
		while not macroIsMenuItem("Choose Player") do
			macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
		end

		-- key go into Choose Player
		macroEvent(10000, EVENT_KEY_PRESS, KEY_GO)

		-- key back from Choose Player
		macroEvent(100, EVENT_KEY_PRESS, KEY_BACK)

		-- key down
		macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
	end
end


-- macro state
local task = false
local timer = false


-- play the macro
function play(self)
	task = Task("MacroPlay", self, script)
	task:addTask()

	timer = Timer(0, function()
				 task:addTask()
			 end, true)
end


-- delay macro for interval ms
function macroDelay(interval)
	timer:restart(interval)
	Task:yield(false)	
end


-- dispatch ui event Event(...), and delay for interval ms
function macroEvent(interval, ...)
	local event = Event:new(...)

	log:info("macroEvent: ", event:tostring())

	Framework:pushEvent(event)
	macroDelay(interval)
end


-- returns the text of the selected menu item (or nil)
function macroGetMenuText()
	local window = Framework.windowStack[1]

	-- find menu + selection
	local item = false
	window:iterate(function(widget)
		if oo.instanceof(widget, Menu) then
			item = widget:getSelectedItem()
		end
	end)

	if not item then
		return
	end

	-- assumes Group with "text" widget
	return item:getWidget("text"):getValue()
end


-- returns true if the menu item 'text' is selected
function macroIsMenuItem(text)
	local menuText = macroGetMenuText()

	log:info("macroIsMenuItem ", menuText, "==", text)

	return tostring(menuText) == tostring(text)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
