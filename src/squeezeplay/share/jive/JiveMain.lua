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
local coroutine     = require("coroutine")
local oo            = require("loop.simple")

local NetworkThread = require("jive.net.NetworkThread")
local Iconbar       = require("jive.Iconbar")
local AppletManager = require("jive.AppletManager")
local locale        = require("jive.utils.locale")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local HomeMenu      = require("jive.ui.HomeMenu")
local Framework     = require("jive.ui.Framework")
local Task          = require("jive.ui.Task")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jive.main")
local logheap       = require("jive.utils.log").logger("jive.heap")
--require("profiler")

local EVENT_KEY_ALL        = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD       = jive.ui.EVENT_KEY_HOLD
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_WINDOW_RESIZE  = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_UNUSED         = jive.ui.EVENT_UNUSED

local KEY_HOME             = jive.ui.KEY_HOME
local KEY_BACK             = jive.ui.KEY_BACK


-- Classes
local JiveMain = oo.class({}, HomeMenu)


-- strings
local _globalStrings

-- several submenus created by applets (settings, controller settings, extras)
-- should not need to have an id passed when creating it
local _idTranslations = {}
	

-- bring us to the home menu
local function _homeHandler(event)
	local type = event:getType()

	if (( type == EVENT_KEY_PRESS and event:getKeycode() == KEY_HOME) or
	    ( type == EVENT_KEY_HOLD and event:getKeycode() == KEY_BACK)) then

		-- disconnect from player on press and hold left
		if type == EVENT_KEY_HOLD then
			local manager = AppletManager:getAppletInstance("SlimDiscovery")
			if manager then
				manager:setCurrentPlayer(nil)
			end
		end

		local windowStack = Framework.windowStack

		if #windowStack > 1 then
			Framework:playSound("JUMP")
			jiveMain:closeToHome(true)
		else
			Framework:playSound("BUMP")
			windowStack[1]:bumpLeft()
		end
		return EVENT_CONSUME
      end
      return EVENT_UNUSED
end


-- __init
-- creates our JiveMain main object
function JiveMain:__init()
	log:debug("__init()")

	-- Seed the rng
	local initTime = os.time()
	math.randomseed(initTime)

	-- Initialise UI
	Framework:init()

	-- Singleton instances (globals)
	jnt = NetworkThread()

	appletManager = AppletManager(jnt)
	iconbar = Iconbar()
	
	-- Singleton instances (locals)
	_globalStrings = locale:readGlobalStringsFile()

	-- create the main menu
	jiveMain = oo.rawnew(self, HomeMenu(_globalStrings:str("HOME"), nil, "hometitle"))


--	profiler.start()

	-- menu nodes to add...these are menu items that are used by applets
	JiveMain:jiveMainNodes(_globalStrings)

	-- init our listeners
	jiveMain.skins = {}

	-- home key handler, one for KEY_PRESS/HOME, one for KEY_HOLD/BACK
	Framework:addListener(
		EVENT_KEY_PRESS | EVENT_KEY_HOLD,
		function(event)
			_homeHandler(event)
		end,
		false
	)

	-- global listener: resize window (only desktop versions)
	Framework:addListener(EVENT_WINDOW_RESIZE,
				      function(event)
					      jiveMain:reloadSkin()
					      return EVENT_UNUSED
				      end)

	-- show our window!
	jiveMain.window:show()

	-- load style and applets
	jiveMain:reload()

	-- debug: set event warning thresholds (0 = off)
	--Framework:perfwarn({ screen = 50, layout = 1, draw = 0, event = 50, queue = 5, garbage = 10 })
	--jive.perfhook(50)

	-- show splash screen for five seconds, or until key/scroll events
	Framework:setUpdateScreen(false)
	local splashHandler = Framework:addListener(EVENT_KEY_ALL | EVENT_SCROLL,
							    function()
								Framework:setUpdateScreen(true)
								return EVENT_UNUSED
							    end)
	local splashTimer = Timer(5000 - (os.time() - initTime),
		function()
			Framework:setUpdateScreen(true)
			Framework:removeListener(splashHandler)
		end,
		true)
	splashTimer:start()

	local heapTimer = Timer(60000,
		function()
			if not logheap:isDebug() then
				return
			end

			local s = jive.heap()
			logheap:debug("--- HEAP total/new/free ---")
			logheap:debug("number=", s["number"]);
			logheap:debug("integer=", s["integer"]);
			logheap:debug("boolean=", s["boolean"]);
			logheap:debug("string=", s["string"]);
			logheap:debug("table=", s["table"], "/", s["new_table"], "/", s["free_table"]);
			logheap:debug("function=", s["function"], "/", s["new_function"], "/", s["free_function"]);
			logheap:debug("thread=", s["thread"], "/", s["new_thread"], "/", s["free_thread"]);
			logheap:debug("userdata=", s["userdata"], "/", s["new_userdata"], "/", s["free_userdata"]);
			logheap:debug("lightuserdata=", s["lightuserdata"], "/", s["new_lightuserdata"], "/", s["free_lightuserdata"]);
		end)
	heapTimer:start()

	-- run event loop
	Framework:eventLoop(jnt:task())

	Framework:quit()

--	profiler.stop()
end

function JiveMain:jiveMainNodes(globalStrings)

	-- this can be called after language change, 
	-- so we need to bring in _globalStrings again if it wasn't provided to the method
	if globalStrings then
		_globalStrings = globalStrings
	else
		_globalStrings = locale:readGlobalStringsFile()
	end

	jiveMain:addNode( { id = 'hidden', node = 'nowhere' } )
	jiveMain:addNode( { id = 'extras', node = 'home', text = _globalStrings:str("EXTRAS"), weight = 50  } )
	jiveMain:addNode( { id = 'games', node = 'extras', text = _globalStrings:str("GAMES"), weight = 70  } )
	jiveMain:addNode( { id = 'settings', node = 'home', noCustom = 1, text = _globalStrings:str("SETTINGS"), weight = 70, titleStyle = 'settings' })
	jiveMain:addNode( { id = 'advancedSettings', node = 'settings', noCustom = 1, text = _globalStrings:str("ADVANCED_SETTINGS"), weight = 110, titleStyle = 'settings' })
	jiveMain:addNode( { id = 'screenSettings', node = 'settings', text = _globalStrings:str("SCREEN_SETTINGS"), weight = 50, titleStyle = 'settings' })
	jiveMain:addNode( { id = 'factoryTest', node = 'advancedSettings', noCustom = 1, text = _globalStrings:str("FACTORY_TEST"), weight = 105, titleStyle = 'settings' })

end

-- reload
-- 
function JiveMain:reload()
	log:debug("reload()")

	-- reset the skin
	jive.ui.style = {}

	-- manage applets
	appletManager:discover()
	
	Framework:styleChanged()
end


-- loadSkin
-- 
function JiveMain:loadSkin(appletName, method)
	log:debug("loadSkin(", appletName, ")")
	
	local obj = appletManager:loadApplet(appletName)
	assert(obj, "Cannot load skin " .. appletName)

	obj[method](obj, jive.ui.style)

	self.skins[#self.skins + 1] = { obj, method }
end

-- reloadSkin
-- 
function JiveMain:reloadSkin()
	-- reset the skin
	jive.ui.style = {}

	for i,v in ipairs(self.skins) do
		local obj, method = v[1], v[2]
		obj[method](obj, jive.ui.style)
	end

	Framework:styleChanged()
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

