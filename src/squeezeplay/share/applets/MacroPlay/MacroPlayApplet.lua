
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

local LAYER_ALL        = jive.ui.LAYER_ALL

local jive = jive


module(..., Framework.constants)
oo.class(_M, Applet)


-- macro (global) state
local task = false
local timer = false
local macro = false


function init(self)
	self:loadconfig()
end


local function loadmacro(file)
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		local filepath = dir .. file

		if lfs.attributes(filepath, "mode") == "file" then
			local f, err = loadfile(filepath)
			if err == nil then
				-- Set chunk environment to be contained in the
				-- MacroPlay applet.
				setfenv(f, getfenv(1))
				return f, string.match(filepath, "(.*[/\]).+")
			else
				return nil, err
			end
		end
	end

	return nil
end


function loadconfig(self)
	-- Load macro configuration
	local f, err = loadmacro("Macros.lua")
	if f then
		-- Defines self.macros
		f()
	else
		log:warn("Error loading Macros: ", err)
	end

--	if self.autostart then
--		self:autoplay()
--	end
end


function settingsShow(self)
	-- Create window
	local window = Window("window", self:string("MACRO_PLAY"))
	local menu = SimpleMenu("menu", items)
	local help = Textarea("help", "")

	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	window:addWidget(help)
	window:addWidget(menu)

	-- Macro menus
	if self.autostart then
		local item = {
			text = self:string("MACRO_PLAY_AUTOSTART"),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
				self.auto = nil
				self:autoplay()
			end,
			focusGained = function()
				help:setValue(self:string("MACRO_PLAY_AUTOSTART_HELP"))
			end,
			weight = 1,
		}
		menu:addItem(item)
	end

	for k, v in pairs(self.macros) do
		local item = {
			text = self:string(v.name),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
				self.auto = false
				self:play(v)
			end,
			focusGained = function()
				help:setValue(v.desc)
			end,
			weight = 5,
		}

		if v.passed then
			log:warn("SETTING STYLE")
			item.style = "checked"
		end

		menu:addItem(item)
	end

	-- FIXME can't tie applet due to global macro state
	window:show()
end


function autoplay(self)
	if self.auto == false then
		return
	end

	if self.auto == nil then
		self.auto = 1
	end

	if self.auto > #self.autostart then
		log:info("Macro Autoplay FINISHED")
		self.auto = false

		return
	end

	local macro = self.macros[self.autostart[self.auto]]
	self.auto = self.auto + 1

	self:play(macro)
end

-- play the macro
function play(self, entry)
	task = Task("MacroPlay", self,
		function()
			local f, dir = loadmacro(entry.file)
			if f then
				macro = entry
				macro.dir = dir

				log:info("Macro starting: ", macro.file)
				f()

				self:autoplay()
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
function macroIsMenuItem(pattern)
	local menuText = macroGetMenuText()

	log:info("macroIsMenuItem ", menuText, "==", pattern)

	return string.match(tostring(menuText), pattern)
end


-- force return to the home menu
function macroHome()
	log:info("macroHome")
	if #Framework.windowStack > 1 then
		Framework.windowStack[#Framework.windowStack - 1]:hideToTop()
	end
end


-- capture or verify a screenshot
function macroScreenshot(interval, file, limit)
	local pass = false

	limit = limit or 100

	-- create screenshot
	local w, h = Framework:getScreenSize()

	local window = Framework.windowStack[1]

	local screen = Surface:newRGB(w, h)
	window:draw(screen, LAYER_ALL)


	local reffile = macro.dir .. file .. ".bmp"
	if lfs.attributes(reffile, "mode") == "file" then
		-- verify screenshot
		log:debug("Loading reference screenshot " .. reffile)
		local ref = Surface:loadImage(reffile)

		local match = ref:compare(screen, 0xFF00FF)

		if match < limit then
			-- failure
			log:warn("Macro Screenshot FAILED " .. file .. " match=" .. match .. " limt=" .. limit)
			failfile = macro.dir .. file .. "_fail.bmp"
			screen:saveBMP(failfile)
		else
			log:info("Macro Screenshot PASSED " .. file)
			pass = true
		end
	else
		log:debug("Saving reference screenshot " .. reffile)
		screen:saveBMP(reffile)
	end

	macroDelay(interval)
	return pass
end


function macroPass(msg)
	log:warn("Macro PASS ", macro.name, ": ", msg)

	macro.passed = Framework:getTicks()
end


function macroFail(msg)
	log:warn("Macro FAIL ", macro.name, ": ", msg)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
