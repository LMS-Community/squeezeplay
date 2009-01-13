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
local System        = require("jive.System")
local locale        = require("jive.utils.locale")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local HomeMenu      = require("jive.ui.HomeMenu")
local Framework     = require("jive.ui.Framework")
local Task          = require("jive.ui.Task")
local Timer         = require("jive.ui.Timer")
local Event         = require("jive.ui.Event")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jive.main")
local logheap       = require("jive.utils.log").logger("jive.heap")
--require("profiler")

local EVENT_IR_ALL         = jive.ui.EVENT_IR_ALL
local EVENT_IR_PRESS       = jive.ui.EVENT_IR_PRESS
local EVENT_IR_DOWN        = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT      = jive.ui.EVENT_IR_REPEAT
local EVENT_IR_HOLD        = jive.ui.EVENT_IR_HOLD
local EVENT_KEY_ALL        = jive.ui.EVENT_KEY_ALL
local ACTION               = jive.ui.ACTION
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_CHAR_PRESS      = jive.ui.EVENT_CHAR_PRESS
local EVENT_KEY_HOLD       = jive.ui.EVENT_KEY_HOLD
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_WINDOW_RESIZE  = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_UNUSED         = jive.ui.EVENT_UNUSED

local KEY_HOME             = jive.ui.KEY_HOME
local KEY_FWD           = jive.ui.KEY_FWD
local KEY_REW           = jive.ui.KEY_REW
local KEY_GO            = jive.ui.KEY_GO
local KEY_BACK          = jive.ui.KEY_BACK
local KEY_UP            = jive.ui.KEY_UP
local KEY_DOWN          = jive.ui.KEY_DOWN
local KEY_LEFT          = jive.ui.KEY_LEFT
local KEY_RIGHT         = jive.ui.KEY_RIGHT
local KEY_PLAY          = jive.ui.KEY_PLAY
local KEY_PAUSE         = jive.ui.KEY_PAUSE
local KEY_VOLUME_UP     = jive.ui.KEY_VOLUME_UP
local KEY_VOLUME_DOWN   = jive.ui.KEY_VOLUME_DOWN
local KEY_ADD           = jive.ui.KEY_ADD

-- Classes
local JiveMain = oo.class({}, HomeMenu)


-- strings
local _globalStrings

-- several submenus created by applets (settings, controller settings, extras)
-- should not need to have an id passed when creating it
local _idTranslations = {}
	
local keyboardShortcuts = {	
	["S"]  = { keyCode = KEY_REW | KEY_PAUSE ,  event = EVENT_KEY_HOLD },
	["i"]  = { keyCode = KEY_UP,   event = EVENT_KEY_PRESS },
	["k"]  = { keyCode = KEY_DOWN, event = EVENT_KEY_PRESS },
	["j"]  = { keyCode = KEY_LEFT, event = EVENT_KEY_PRESS },
	["J"]  = { keyCode = KEY_LEFT, event = EVENT_KEY_HOLD },
	["l"]  = { keyCode = KEY_RIGHT, event = EVENT_KEY_PRESS },
	["h"]  = { keyCode = KEY_HOME, event = EVENT_KEY_PRESS },
	["p"]  = { keyCode = KEY_PLAY, event = EVENT_KEY_PRESS },
	["P"]  = { keyCode = KEY_PLAY, event = EVENT_KEY_HOLD },
	["x"]  = { keyCode = KEY_PLAY, event = EVENT_KEY_PRESS },
	["c"]  = { keyCode = KEY_PAUSE, event = EVENT_KEY_PRESS },
	[" "]  = { keyCode = KEY_PAUSE, event = EVENT_KEY_PRESS },
	["a"]  = { keyCode = KEY_ADD, event = EVENT_KEY_PRESS },
	["A"]  = { keyCode = KEY_ADD, event = EVENT_KEY_HOLD },
	["z"]  = { keyCode = KEY_REW, event = EVENT_KEY_PRESS },
	["Z"]  = { keyCode = KEY_REW, event = EVENT_KEY_HOLD },
	["<"]  = { keyCode = KEY_REW, event = EVENT_KEY_PRESS },
	["b"]  = { keyCode = KEY_FWD, event = EVENT_KEY_PRESS },
	["B"]  = { keyCode = KEY_FWD, event = EVENT_KEY_HOLD },
	[">"]  = { keyCode = KEY_FWD, event = EVENT_KEY_PRESS },
	["+"]  = { keyCode = KEY_VOLUME_UP, event = EVENT_KEY_PRESS },
	["="]  = { keyCode = KEY_VOLUME_UP, event = EVENT_KEY_PRESS },
	["-"]  = { keyCode = KEY_VOLUME_DOWN, event = EVENT_KEY_PRESS },
	["\b"]  = { keyCode = KEY_BACK, event = EVENT_KEY_PRESS }, -- BACKSPACE
	["\27"]  = { keyCode = KEY_BACK, event = EVENT_KEY_PRESS } -- ESC
}

-- Squeezebox remote IR codes
local irCodes = {
	[ 0x7689e01f ] = KEY_UP,
	[ 0x7689b04f ] = KEY_DOWN,
	[ 0x7689906f ] = KEY_LEFT,
	[ 0x7689d02f ] = KEY_RIGHT,
	[ 0x768922dd ] = KEY_HOME,
	[ 0x768910ef ] = KEY_PLAY,
	[ 0x768920df ] = KEY_PAUSE,
	[ 0x7689609f ] = KEY_ADD,
	[ 0x7689c03f ] = KEY_REW,
	[ 0x7689a05f ] = KEY_FWD,
	[ 0x7689807f ] = KEY_VOLUME_UP,
	[ 0x768900ff ] = KEY_VOLUME_DOWN,
}


local keyActionMappingsPress = {
    [KEY_LEFT] = "arrow_left.press"  -- using button naming convention from SC default.map, though these are action events
}


local keyActionMappingsHold = {
    [KEY_LEFT] = "arrow_left.hold",
    [KEY_BACK] = "arrow_back.hold",
    [KEY_REW | KEY_PAUSE] = "take_screenshot"  -- a stab at how to handle multi-press
}

local _defaultSkin
local _fullscreen

local function _goHome() 
		local windowStack = Framework.windowStack

		if #windowStack > 1 then
			Framework:playSound("JUMP")
			jiveMain:closeToHome(true)
		else
			Framework:playSound("BUMP")
			windowStack[1]:bumpLeft()
		end
end

local function _disconnectPlayer(self, event) --self, event not used in our case, could be left out
    appletManager:callService("setCurrentPlayer", nil)
    _goHome()
end

-- bring us to the home menu
local function _homeHandler(event)
	local type = event:getType()

	if ( type == EVENT_CHAR_PRESS ) then
		local keyboardEntry = string.char(event:getUnicode())
		
		log:debug("Keyboard entry: ", keyboardEntry)
		
		if keyboardShortcuts[keyboardEntry] then
			local keyCode = keyboardShortcuts[keyboardEntry].keyCode
			Framework:pushEvent(Event:new(keyboardShortcuts[keyboardEntry].event, keyCode))
		end
		
		return EVENT_CONSUME

	elseif ( type == EVENT_KEY_PRESS and event:getKeycode() == KEY_HOME) then

        _goHome()
        
		return EVENT_CONSUME
      end
      return EVENT_UNUSED
end

local function _addUserPathToLuaPath()
    local dirSeparator = package.path:match( "(%p)%?%." )
    package.path = package.path .. System.getUserDir() .. dirSeparator .."?.lua;"
    package.path = package.path .. System.getUserDir() .. dirSeparator .. "?" .. dirSeparator .. "?.lua;"
end

local function _irHandler(event)
	local irCode = event:getIRCode()
	local keyCode = irCodes[irCode]
	if (keyCode) then
	log:debug("IR event: ", event:tostring())
	--includes temp hack for up/down to allow Menu, etc to have direct IR event access 
		if event:getType() == EVENT_IR_PRESS and (keyCode ~= KEY_UP and keyCode ~= KEY_DOWN) then
			Framework:pushEvent(Event:new(EVENT_KEY_PRESS, keyCode))
		elseif event:getType() == EVENT_IR_HOLD then
			Framework:pushEvent(Event:new(EVENT_KEY_HOLD, keyCode))
		end
		return EVENT_CONSUME
	end

	return EVENT_UNUSED
end		


-- transform user input events (key, etc) to a matching action name
local function getAction(event)
    --naive implementation for demonstration - will be more involved later

    local eventType = event:getType()
    local action = nil
    
    if eventType == EVENT_KEY_PRESS then
        action = keyActionMappingsPress[event:getKeycode()]
    elseif eventType == EVENT_KEY_HOLD then
        action = keyActionMappingsHold[event:getKeycode()]
    end
    
    return action
    
end

function registerDefaultActions()
    for key, action in pairs(keyActionMappingsPress) do 
        Framework:registerAction(action)
    end
    for key, action in pairs(keyActionMappingsHold) do 
        Framework:registerAction(action)
    end

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

    _addUserPathToLuaPath()

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
		EVENT_CHAR_PRESS| EVENT_KEY_PRESS | EVENT_KEY_HOLD,
		function(event)
			_homeHandler(event)
		end,
		10)

	Framework:addListener(EVENT_IR_ALL,
		function(event) _irHandler(event) end,
		false
	)

	-- global listener: resize window (only desktop versions)
	Framework:addListener(EVENT_WINDOW_RESIZE,
		function(event)
			jiveMain:reloadSkin()
			return EVENT_UNUSED
		end,
		10)

    registerDefaultActions()

	-- action mapping listener, should be last listener in chain to allow for direct access to keys/other input types if needed.
	--todo add other input types
	Framework:addListener(EVENT_KEY_ALL,
		function(event)
		    local action = getAction(event)
		    if not action then
		        return EVENT_UNUSED
		    end
		    
		    local actionEvent = Framework:newActionEvent(action)
		    if not actionEvent then
		        log:error("Odd, newActionEvent returned nil, but should always return a result when match was found for action: ", action)
		        return EVENT_UNUSED
		    end
		    
		    log:debug("Pushing action event (", action, ") - event:getAction: " , actionEvent:getAction())
	        Framework:pushEvent(actionEvent)
			return EVENT_CONSUMED
		end,
		9999)
		
	
    -- disconnect from player on press and hold left
    Framework:addActionListener("arrow_left.hold", self, _disconnectPlayer)
        Framework:addActionListener("arrow_back.hold", self, _disconnectPlayer)
	
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
	local splashTimer = Timer(2000 - (os.time() - initTime),
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

	-- make sure a skin is selected
	if not self.selectedSkin then
		for askin in pairs(self.skins) do
			self:setSelectedSkin(askin)
			break
		end
	end
	assert(self.selectedSkin, "No skin")
end


function JiveMain:registerSkin(name, appletName, method, params)
	log:debug("registerSkin(", name, ",", appletName, ")")
	self.skins[appletName] = { name, method }
	local defaultParams = {
		THUMB_SIZE = 56,
	}
	local params = params or defaultParams
	JiveMain:setSkinParams(appletName, params)

end


function JiveMain:skinIterator()
	local _f,_s,_var = pairs(self.skins)
	return function(_s,_var)
		local appletName, entry = _f(_s,_var)
		if appletName then
			return appletName, entry[1]
		else
			return nil
		end
	end,_s,_var
end


function JiveMain:getSelectedSkin()
	return self.selectedSkin
end


local function _loadSkin(self, appletName, reload, useDefaultSize)
	if not self.skins[appletName] then
		return false
	end

	local name, method = unpack(self.skins[appletName])
	local obj = appletManager:loadApplet(appletName)
	assert(obj, "Cannot load skin " .. appletName)

	-- reset the skin
	jive.ui.style = {}

	obj[method](obj, jive.ui.style, reload==nil and true or relaod, useDefaultSize)

	Framework:styleChanged()

	return true
end


function JiveMain:isFullscreen()
	return _fullscreen
end

function JiveMain:setFullscreen(fullscreen)
	_fullscreen = fullscreen
end


function JiveMain:setSelectedSkin(appletName)
	log:warn(appletName)
	if _loadSkin(self, appletName, false, true) then
		self.selectedSkin        = appletName
	end
end

function JiveMain:getSkinParam(key)

	local skinName = self.selectedSkin or JiveMain:getDefaultSkin()
	
	if key and self.skinParams and self.skinParams[skinName] and self.skinParams[skinName][key] then
		return self.skinParams[skinName][key]
	else
		log:error('no value for skinParam ', key, ' found') 
		return nil
	end

end

-- service method to allow other applets to set skin-specific settings like THUMB_SIZE
function JiveMain:setSkinParams(skinName, settings)

	_assert(type(settings) == 'table')
	if not self.skinParams then
		self.skinParams = {}
	end
	self.skinParams[skinName] = settings

end


-- reloadSkin
-- 
function JiveMain:reloadSkin(reload)
	_loadSkin(self, self.selectedSkin, true);
end


-- loadSkin
-- XXXX deprecated, to be replaced with per window skinning
function JiveMain:loadSkin(appletName, method)
	log:debug("loadSkin(", appletName, ")")
	
	local obj = appletManager:loadApplet(appletName)
	assert(obj, "Cannot load skin " .. appletName)

	obj[method](obj, jive.ui.style)
end

function JiveMain:setDefaultSkin(appletName)
	log:debug("setDefaultSkin(", appletName, ")")
	_defaultSkin = appletName
end

function JiveMain:getDefaultSkin()
	return _defaultSkin or "DefaultSkin"
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

