--[[

Copyright 2007 Logitech. All Rights Reserved.

This file contains Original Code and/or Modifications of Original Code
as defined in and that are subject to the Logitech Public Source License 
Version 1.0 (the "License"). You may not use this file except in
compliance with the License.  You should obtain a copy of the License at 
http://www.logitech.com/ and read it before using this file.  Note that
the License is not an "open source" license, as that term is defined in
the Open Source Definition, http://opensource.org/docs/definition.php.
The terms of the License do not permit distribution of source code.

The Original Code and all software distributed under the License are 
distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER 
EXPRESS OR IMPLIED, AND LOGITECH HEREBY DISCLAIMS ALL SUCH WARRANTIES, 
INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  Please see the License for
the specific language governing rights and limitations under the License.  
--]]

--[[
=head1 NAME

jive.JiveMain - Main Jive application.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

JiveMainMenu notifies any change with mainMenuUpdate

=cut
--]]


-- stuff we use
local math          = require("math")
local os            = require("os")
local oo            = require("loop.simple")

local NetworkThread = require("jive.net.NetworkThread")
local Iconbar       = require("jive.Iconbar")
local autotable     = require("jive.utils.autotable")
local AppletManager = require("jive.AppletManager")
local perfs         = require("jive.utils.perfs")
local locale        = require("jive.utils.locale")

local jud = require("jive.utils.debug")


local log           = require("jive.utils.log").logger("jive.main")

require("jive.ui.Framework")
--require("profiler")



-- Classes
local JiveMainMenu = oo.class()
local JiveMain = oo.class({}, JiveMainMenu)


-- strings
local _globalStrings

-----------------------------------------------------------------------------
-- JiveMainMenu
-- This class abstracts some window/menu functions for the main menu
-----------------------------------------------------------------------------

-- changed
local function _jiveMainMenuChanged(self)
	if self.notify then
		jnt:notify("jiveMainMenuChanged")
	end
end


-- create a new menu
function JiveMainMenu:__init(name, style)

	local obj = oo.rawnew(self, {
		menu = jive.ui.SimpleMenu("menu"),
		window = jive.ui.Window(style or "window", name),
		menus = {},
		notify = false,
	})
	
	obj.menu:setComparator(jive.ui.SimpleMenu.itemComparatorWeightAlpha)
	obj.window:addWidget(obj.menu)

	return obj
end


-- returns true if menu is submenu
function JiveMainMenu:isSubMenu(name)
	return (self.menus[name] != nil)
end


-- create a sub menu
function JiveMainMenu:subMenu(name, weight)

	if self.menus[name] == nil then
	
		local menu = JiveMainMenu(name)

		local item = {
			text = name,
			callback = function()
				menu.window:show()
			end,
		}

		self:addItem(item, weight)
		self.menus[name] = menu
		_jiveMainMenuChanged(self)
	end

	return self.menus[name]
end


-- add an item to a menu. the menu is ordered by weight, then item name
function JiveMainMenu:addItem(item, weight)

	if not item.weight then 
		item.weight = weight or 5
	end

	self.menu:addItem(item)
	_jiveMainMenuChanged(self)
end


-- remove an item from a menu
function JiveMainMenu:removeItem(item)
	self.menu:removeItem(item)
	_jiveMainMenuChanged(self)
end


-- iterator over items in menu
function JiveMainMenu:iterator()
	return self.menu:iterator()
end


-- startNotify
function JiveMainMenu:startNotify()
	self.notify = true
end

-----------------------------------------------------------------------------
-- JiveMain
-----------------------------------------------------------------------------


-- JiveMain:__init
-- creates our JiveMain main object
function JiveMain:__init()
	log:debug("JiveMain:__init()")

	-- Seed the rng
	local initTime = os.time()
	math.randomseed(initTime)

	-- Initialise UI
	jive.ui.Framework:init()

	-- Singleton instances (globals)
	jnt = NetworkThread()
	appletManager = AppletManager(jnt)
	iconbar = Iconbar()
	
	-- Singleton instances (locals)
	_globalStrings = locale:readGlobalStringsFile()

	-- create our object (a subclass of JiveMainMenu)
	jiveMain = oo.rawnew(self, JiveMainMenu(_globalStrings:str("JIVE_HOME"), "home.window"))
	jiveMain.menu:setCloseable(false)


--	profiler.start()

	-- Top level menu
	jiveMain:subMenu(_globalStrings:str("SETTINGS"), 50)

	-- init our listeners
	jiveMain.skins = {}

	-- home key handler
	jive.ui.Framework:addListener(jive.ui.EVENT_KEY_PRESS,
				      function(event)
					      if event:getKeycode() == jive.ui.KEY_HOME then
						      local windowStack = jive.ui.Framework.windowStack

						      while #windowStack > 1 do
							      windowStack[#windowStack - 1]:hide(nil, "JUMP")
						      end
						      return jive.ui.EVENT_CONSUME
					      end
					      
					      return jive.ui.EVENT_UNUSED
				      end,
				      false)

	-- global listener: resize window (only desktop versions)
	jive.ui.Framework:addListener(jive.ui.EVENT_WINDOW_RESIZE,
				      function(event)
					      jiveMain:reloadSkin()
					      return jive.ui.EVENT_UNUSED
				      end)

	-- show our window!
	jiveMain.window:show()

	-- load style and applets
	jiveMain:reload()

	-- debug: set event warning thresholds (0 = off)
	--jive.ui.Framework:perfwarn({ screen = 50, layout = 1, draw = 0, event = 50, queue = 5, garbage = 10 })
	--jive.perfhook(50)

	-- show splash screen for five seconds, or until key/scroll events
	jive.ui.Framework:setUpdateScreen(false)
	local splashHandler = jive.ui.Framework:addListener(jive.ui.EVENT_KEY_ALL | jive.ui.EVENT_SCROLL,
							    function()
								jive.ui.Framework:setUpdateScreen(true)
								return jive.ui.EVENT_UNUSED
							    end)
	local splashTimer = jive.ui.Timer(5000 - (os.time() - initTime), function()
				jive.ui.Framework:setUpdateScreen(true)
				jive.ui.Framework:removeListener(splashHandler)
			    end)
	splashTimer:start()

	-- event loop
	jive.ui.Framework:processEvents()

	jnt:stop()
	jive.ui.Framework:quit()

	perfs.dump('Pool Queue')
	perfs.dump('Pool Priority Queue')
	perfs.dump('Anonymous')
--	profiler.stop()
end


-- reload
-- 
function JiveMain:reload()
	log:debug("JiveMain:reload()")

	-- reset the skin
	jive.ui.style = autotable.new()

	-- manage applets
	appletManager:discover()
	
	jive.ui.Framework:styleChanged()
end


-- loadSkin
-- 
function JiveMain:loadSkin(appletName, method)
	log:debug("JiveMain:loadSkin(", appletName, ")")
	
	local obj = appletManager:loadApplet(appletName)
	assert(obj, "Cannot load skin " .. appletName)

	obj[method](obj, jive.ui.style)

	self.skins[#self.skins + 1] = { obj, method }
end


-- reloadSkin
-- 
function JiveMain:reloadSkin()
	-- reset the skin
	jive.ui.style = autotable.new()

	for i,v in ipairs(self.skins) do
		local obj, method = v[1], v[2]
		obj[method](obj, jive.ui.style)
	end

	jive.ui.Framework:styleChanged()
end


-----------------------------------------------------------------------------
-- main()
-----------------------------------------------------------------------------

-- we create an object
JiveMain()


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

