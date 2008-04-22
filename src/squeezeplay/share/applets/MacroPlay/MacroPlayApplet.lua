
--[[
=head1 NAME

applets.MacroPlay.MarcoPlayApplet - applet to play ui sequences for testing.

=head1 DESCRIPTION

This applet will play ui sequences using a lua script for testing.

=cut
--]]


-- stuff we use
local getfenv, loadfile, ipairs, package, pairs, require, setfenv, setmetatable, tostring = getfenv, loadfile, ipairs, package, pairs, require, setfenv, setmetatable, tostring

local oo               = require("loop.simple")
local lfs              = require("lfs")
local math             = require("math")
local string           = require("string")
local table            = require("jive.utils.table")


local Applet           = require("jive.Applet")
local Event            = require("jive.ui.Event")
local Framework        = require("jive.ui.Framework")
local Menu             = require("jive.ui.Menu")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Timer            = require("jive.ui.Timer")
local Window           = require("jive.ui.Window")

local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("applets.misc")

local jive = jive


module(..., Framework.constants)
oo.class(_M, Applet)


-- macro (global) state
local task = false
local timer = false
local macrodir = false


local function loadmacro(file)
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		-- FIXME file test first

		local f, err = loadfile(dir .. file)
		if err == nil then
			-- Set chunk environment to be contained in the
			-- MacroPlay applet.
			setfenv(f, getfenv(1))
			return f, string.match(dir .. file, "(.*[/\]).+")
		end
	end

	return nil, err
end


function settingsShow(self)
	-- Create window
	local window = Window("window", self:string("MACRO_PLAY"))
	local menu = SimpleMenu("menu", items)
	local help = Textarea("help", "")

	window:addWidget(help)
	window:addWidget(menu)

	-- Load macro configuration
	local f = loadmacro("applets/MacroPlay/Macros.lua")
	if f then
		-- Defines self.macros
		f()

		for i, v in ipairs(self.macros) do
			local item = {
				text = self:string(v.name),
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:play(v.file)
				end,
				focusGained = function()
					help:setValue(v.desc)
				end,
			}
			menu:addItem(item)
		end
	end

	-- FIXME can't tie applet due to global macro state
	window:show()
end


-- play the macro
function play(self, file)
	task = Task("MacroPlay", self,
		function()
			local f, dir = loadmacro(file)
			if f then
				log:info("Macro starting: ", file)
				macrodir = dir
				f()
			else
				log:warn("Macro error: ", err)
			end
		end)
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


-- capture or verify a screenshot
function macroScreenshot(interval, file, limit)
	local pass = false

	limit = limit or 100

	-- create screenshot
	local w, h = Framework:getScreenSize()

	local window = Framework.windowStack[1]

	local screen = Surface:newRGB(w, h)
	window:draw(screen, JIVE_LAYER_ALL)


	local reffile = macrodir .. file .. ".bmp"
	if lfs.attributes(reffile, "mode") == "file" then
		-- verify screenshot
		log:debug("Loading reference screenshot " .. reffile)
		local ref = Surface:loadImage(reffile)

		local match = ref:compare(screen, 0xFF00FF)

		if match < limit then
			-- failure
			log:warn("Screenshot FAILED " .. file .. " match=" .. match .. " limt=" .. limit)
			failfile = macrodir .. file .. "_fail.bmp"
			screen:saveBMP(failfile)
		else
			log:info("Screenshot PASSED " .. file)
			pass = true
		end
	else
		log:debug("Saving reference screenshot " .. reffile)
		screen:saveBMP(reffile)
	end

	macroDelay(interval)
	return pass
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
