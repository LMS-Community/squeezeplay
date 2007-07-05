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

local jud = require("jive.utils.debug")


local log           = require("jive.utils.log").logger("browser")

require("jive.ui.Framework")
--require("profiler")



-- Classes
local Menu = oo.class()
local JiveMain = oo.class({}, Menu)

-----------------------------------------------------------------------------
-- Menu
-----------------------------------------------------------------------------

-- create a new menu
function Menu:__init(name, style)

	local obj = oo.rawnew(self, {
		menu = jive.ui.SimpleMenu("menu"),
		window = jive.ui.Window(style or "window", name),
		menus = {},
	})
	
	obj.menu:setComparator(jive.ui.SimpleMenu.itemComparatorWeightAlpha)
	obj.window:addWidget(obj.menu)

	return obj
end

-- create a sub menu
function Menu:subMenu(name, weight)

	if self.menus[name] == nil then
	
		local menu = Menu(name)

		local item = {
			text = name,
			callback = function()
					   menu.window:show()
				   end,
		}

		self:addItem(item, weight)
		self.menus[name] = menu
	end

	return self.menus[name]
end

-- add an item to a menu. the menu is ordered by weight, then item name
function Menu:addItem(item, weight)

	item.weight = weight or 5

	self.menu:addItem(item)
end


-- remove an item from a menu
function Menu:removeItem(item)
	self.menu:removeItem(item)
end

-----------------------------------------------------------------------------
-- JiveMain
-----------------------------------------------------------------------------

local function _callListeners()
	-- we have customers for background work
	for i,v in ipairs(jiveMain.listeners) do
		if type(v) == 'function' then
			v()
		end
	end
end


-- JiveMain:__init
-- creates our JiveMain main object
function JiveMain:__init()
	log:debug("JiveMain:__init()")

	-- Seed the rng
	math.randomseed(os.time())

	-- Initialise UI
--	jive.ui.Framework:setScreenSize(240, 320, 16)
	jive.ui.Framework:init()

	jiveMain = oo.rawnew(self, Menu("Jive Home", "home.window"))
	jiveMain.menu:setCloseable(false)

	-- Singleton instances (globals)
	jnt = NetworkThread()
	appletManager = AppletManager({jnt = jnt})
	iconbar = Iconbar()

--	profiler.start()

	-- Top level menu
	jiveMain:subMenu("Settings", 900)

	-- init our listeners
	jiveMain.skins = {}
	jiveMain.listeners = {}
	jiveMain.timer = false

	-- listen to ACTIVATE and INACTIVE events
	jiveMain.window:addListener(
		jive.ui.EVENT_WINDOW_ACTIVE, 
		function(event) 
			-- start the timer
			jiveMain.timer = jiveMain.window:addTimer(
				3000, 
				_callListeners
			)

			-- bootstrap the search
			_callListeners()
		end
	)
	
	jiveMain.window:addListener(
		jive.ui.EVENT_WINDOW_INACTIVE, 
		function(event) 
			jiveMain.window:removeTimer(jiveMain.timer)
		end
	)

	jive.ui.Framework:addListener(jive.ui.EVENT_WINDOW_RESIZE,
				      function(event)
					      jiveMain:reloadSkin()
					      return jive.ui.EVENT_UNUSED
				      end)

	jive.ui.Framework:addListener(jive.ui.EVENT_KEY_PRESS | jive.ui.EVENT_KEY_HOLD,
				      function(event)
					      if event:getKeycode() == jive.ui.KEY_HOME then
						      while jive.ui.Framework.windowStack[1] ~= jiveMain.window do
							      jive.ui.Framework.windowStack[1]:hide()
						      end

						      return jive.ui.EVENT_CONSUME
					      end

					      return jive.ui.EVENT_UNUSED
				      end,
				      false)
	
	-- show our window!
	jiveMain.window:show()
	
	-- manage applets
	jiveMain:reload()

	-- jive event loop
	jive.ui.Framework:processEvents()

	jnt:stop()
	jive.ui.Framework:quit()

	perfs.dump('Pool Queue')
	perfs.dump('Pool Priority Queue')
	perfs.dump('Anonymous')
--	profiler.stop()
end


-- addInHomeListener
-- registers a function to be called regularly whenever the main Jive menu is shown
function JiveMain:addInHomeListener(closure)
	log:debug("JiveMain:addInHomeListener()")
	
	-- we want a function
	if type(closure) != 'function' then
		log:error("JiveMain:addInHomeListener called with ", type(closure), ", expecting function")
		return
	end
	
	-- we don't want it twice
	for i,v in ipairs(self.listeners) do
		if v == closure then
			log:warn("JiveMain:addInHomeListener called twice with same function")
			return
		end
	end
		
	-- OK, insert it
	table.insert(self.listeners, closure)
end


function JiveMain:reload()
	log:debug("JiveMain:reload()")

	-- reset the skin
	jive.ui.style = autotable.new()

	-- manage applets
	appletManager:discover()
	jive.ui.Framework:styleChanged()
end


function JiveMain:loadSkin(appletName, method)
	log:debug("JiveMain:loadSkin(", appletName, ")")
	
	local obj = appletManager:load(appletName)
	assert(obj, "Cannot load skin " .. appletName)

	obj[method](obj, jive.ui.style)

	self.skins[#self.skins + 1] = { obj, method }
end


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


JiveMain()


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

