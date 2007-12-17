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
local AppletManager = require("jive.AppletManager")
local perfs         = require("jive.utils.perfs")
local locale        = require("jive.utils.locale")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local HomeMenu      = require("jive.ui.HomeMenu")
local Framework     = require("jive.ui.Framework")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("jive.main")
--require("profiler")

local JIVE_VERSION  = jive.JIVE_VERSION

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
			while #windowStack > 1 do
				windowStack[#windowStack - 1]:hide(nil, "JUMP")
			end
		else
			Framework:playSound("BUMP")
			windowStack[1]:bumpLeft()
		end
		return EVENT_CONSUME
      end
      return EVENT_UNUSED
end


	local obj = oo.rawnew(self, {
		menu   = jive.ui.SimpleMenu("menu"),
		window = jive.ui.Window(style or "window", name, titleStyle),
		menus  = {},
		notify = false,
	})

	obj.menu:setComparator(jive.ui.SimpleMenu.itemComparatorWeightAlpha)
	obj.window:addWidget(obj.menu)

	_nodeTable['home'] = { menu = obj.menu, 
		items = {} }

	return obj
end

function JiveMainMenu:changeNode(id, node)
	-- looks at the node and decides whether it needs to be removed
	-- from a different node before adding
	if _menuTable[id] and _menuTable[id].node != node then 
		-- remove menuitem from previous node
		table.delete(_nodeTable[node].items, _menuTable[id])
		-- change menuitem's node
		_menuTable[id].node = node
		-- add item to that node
		JiveMainMenu:addNode(_menuTable[id])
	end
end

function JiveMainMenu:addNode(item)

	assert(item.id)
	assert(item.node)

	log:warn("JiveMain.addNode: Adding a non-root node, ", item.id)

	if not item.weight then 
		item.weight = 5
	end

	-- remove node from previous node (if changed)
	if _menuTable[item.id] then
		local newNode    = item.node
		local prevNode   = _menuTable[id].node
		if newNode != prevNode then
			changeNode(item.id, newNode)
		end
	end

	-- new/update node

	local window
	if item.window and item.window.titleStyle then
		window = Window("window", item.text, item.window.titleStyle .. "title")
	elseif item.titleStyle then
		window = Window("window", item.text, item.titleStyle .. "title")
	else
		window = Window("window", item.text)
	end

	local menu = SimpleMenu("menu", item)
	window:addWidget(menu)

	_nodeTable[item.id] = { menu = menu, 
				items = {} }

	if not item.callback then
		item.callback = function () 
       	                 window:show()
		end
	end

	if not item.sound then
		sound = "WINDOWSHOW"
	end

	-- now add the item to the menu
	self:addItem(item)

	_jiveMainMenuChanged(self)

end

-- add an item to a menu. the menu is ordered by weight, then item name
function JiveMainMenu:addItem(item)

	-- no sense in doing anything without an id and a node
	assert(item.id)
	assert(item.node)

	if not item.weight then 
		item.weight = 5
	end

	if not _menuTable[item.id] then

		log:warn("JiveMain.addItem: Adding ", item.text, " to ", item.node)
		_menuTable[item.id] = item

	else
		log:warn("THIS ID ALREADY EXISTS, removing existing item")
--		table.delete(_nodeTable[item.node].items, _menuTable[item.id])
		_menuTable[item.id] = item
	end

	table.insert(_nodeTable[item.node].items, item)
	_nodeTable[item.node].menu:addItem(item)

	_jiveMainMenuChanged(self)
end


-- remove an item from a menu by its index
function JiveMainMenu:removeItem(item)
	self.menu:removeItem(item)
end


-- remove an item from a menu by its id
function JiveMainMenu:removeItemById(id)
	self.menu:removeItemById(id)
end


-- lock an item in the menu
function JiveMainMenu:lockItem(item, ...)
	if _nodeTable[item.node] then
		_nodeTable[item.node].menu:lock(...)
	end
end


-- unlock an item in the menu
function JiveMainMenu:unlockItem(item)
	if _nodeTable[item.node] then
		_nodeTable[item.node].menu:unlock()
	end
end


-- iterator over items in menu
function JiveMainMenu:iterator()
	return self.menu:iterator()
end


-----------------------------------------------------------------------------
-- JiveMain
-----------------------------------------------------------------------------


-- JiveMain:__init
-- creates our JiveMain main object
function JiveMain:__init()
	log:info("jive ", JIVE_VERSION)

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
--	jiveMain = oo.rawnew(self, JiveMainMenu(_globalStrings:str("JIVE_HOME"), "home.window"))
	jiveMain = oo.rawnew(self, HomeMenu(_globalStrings:str("JIVE_HOME"), nil, "hometitle"))


--	profiler.start()

	-- menu nodes to add...these are menu items that are used by applets
	jiveMain:addNode( { id = 'extras', node = 'home', text = _globalStrings:str("EXTRAS"), weight = 70  } )
	jiveMain:addNode( { id = 'settings', node = 'home', text = _globalStrings:str("SETTINGS"), weight = 50, titleStyle = 'settings' })
	jiveMain:addNode(  { id = 'remoteSettings', node = 'settings', text = _globalStrings:str("REMOTE_SETTINGS"), titleStyle = 'settings' })
	jiveMain:addNode( { id = 'advancedSettings', node = 'remoteSettings', text = _globalStrings:str("ADVANCED_SETTINGS"), weight =100, titleStyle = 'settings' })

	-- if you wanted to add a title style for "Extras", this is where it would go

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
	local splashTimer = Timer(5000 - (os.time() - initTime), function()
				Framework:setUpdateScreen(true)
				Framework:removeListener(splashHandler)
			    end)
	splashTimer:start()

	-- event loop
	Framework:processEvents()

	jnt:stop()
	Framework:quit()

	perfs.dump('Pool Queue')
	perfs.dump('Pool Priority Queue')
	perfs.dump('Anonymous')
--	profiler.stop()
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

