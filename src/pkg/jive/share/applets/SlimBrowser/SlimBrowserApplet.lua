
--[[
=head1 NAME

applets.SlimBrowser.SlimBrowserApplet - Browse music and control players.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]


-- stuff we use
local tostring, ipairs, setmetatable, pairs, assert = tostring, ipairs, setmetatable, pairs, assert
local type = type

local oo               = require("loop.simple")
local table            = require("table")

local Applet           = require("jive.Applet")
local Icon             = require("jive.ui.Icon")
local Label            = require("jive.ui.Label")
local Menu             = require("jive.ui.Menu")
local Slider           = require("jive.ui.Slider")
local Timer            = require("jive.ui.Timer")
local Window           = require("jive.ui.Window")
local RequestHttp      = require("jive.net.RequestHttp")

local log              = require("jive.utils.log").logger("player.browse")

local EVENT_KEY_ALL    = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN   = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP     = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD   = jive.ui.EVENT_KEY_HOLD
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local KEY_PLAY         = jive.ui.KEY_PLAY
local KEY_ADD          = jive.ui.KEY_ADD
local KEY_BACK         = jive.ui.KEY_BACK
local KEY_PAUSE        = jive.ui.KEY_PAUSE
local KEY_VOLUME_DOWN  = jive.ui.KEY_VOLUME_DOWN
local KEY_VOLUME_UP    = jive.ui.KEY_VOLUME_UP

local Context          = require("applets.SlimBrowser.Context")

local jnt              = jnt


local debug = require("jive.utils.debug")

module(...)
oo.class(_M, Applet)


-- The player we're browsing and it's server
local _player = false
local _server = false

-- The applet main window
local _playerMenuWindow = false

-- Now Playing window & stuff
local _nowPlayingWindow = false
local _nowPlayingMenu = false
local _nowPlayingOldCurIdx = false


-- metatable for menuItems "values"
-- set a tostring handler to the items that uses a style function...
local _nowPlayingMenuItemValueMetatable = {
	__tostring = function(item)
		return _nowPlayingMenu:styleValue("format", "unused", item)
	end
}


-- forward declarations
local _browseMenu






-- Local functions
------------------

-- _openVolumePopup
-- manages the volume pop up window
local function _openVolumePopup(vol)

	local popup = Window("volume")
	local background = Icon("background")
	popup:addWidget(background)

	local label = Label("label", "Volume")
	popup:addWidget(label)

	local slider = Slider("slider")
	slider:setSlider(-1, 100, _player:getVolume())
	popup:addWidget(slider)

	-- timer to change volume
	local timer = Timer(100,
		function()
			if vol > 0 then
				_player:volumeUp()
			elseif vol < 0 then
				_player:volumeDown()
			end
			popup:showBriefly()
			slider:setSlider(-1, 100, _player:getVolume())
		end
	)

	-- listener for volume up and down keys
	popup:addListener(EVENT_KEY_ALL,
		function(event)
			local evtCode = event:getKeycode()

			-- we're only interested in volume keys
			if evtCode == KEY_VOLUME_UP then
				vol = 1
			elseif evtCode == KEY_VOLUME_DOWN then
				vol = -1
			else
				return EVENT_UNUSED
			end

			local evtType = event:getType()
			if evtType == EVENT_KEY_UP then
				-- stop volume timer
				timer:stop()
			elseif evtType == EVENT_KEY_DOWN then
				-- start volume timer
				timer:start()
			end

			-- make sure we don't hide popup
			return EVENT_CONSUME
		end
	)

	popup:showBriefly(2000,
		function()
			timer:stop()
		end,
		Window.transitionNone,
		Window.transitionPushPopupLeft
	)


	-- start the timer
	if vol > 0 then
		_player:volumeUp()
		timer:start()
	elseif vol < 0 then
		_player:volumeDown()
		timer:start()
	end
end


-- artworkThumbUri
-- returns a URI to fetch artwork on the server
-- FIXME: should this be styled?
local function _artworkThumbUri(artworkId)
	return '/music/' .. artworkId .. '/cover_50x50_f_000000.jpg'
end


-- _createNowPlayingMenuItem
-- Creates a new shiny menuItem (i.e. a Label)
local function _createNowPlayingMenuItem(item, artworkId)

	local icon
	
	if artworkId then
		icon = Icon("artwork")
		_server:fetchArtworkThumb(artworkId, icon:sink(), _artworkThumbUri)
	end
	
	return Label("label", setmetatable(item, _nowPlayingMenuItemValueMetatable), icon)
end


-- _createNowPlayingWindow
-- Creates the now Playing window and associated paraphernalia
local function _createNowPlayingWindow()
	log:debug("_createNowPlayingWindow()")
	
	local window = Window("slimbrowser.status", "Now Playing")
	local menu = Menu("menu")
	window:addWidget(menu)

	-- hide the window on back key
	window:addListener(EVENT_KEY_PRESS,
		function(evt)
			if evt:getKeycode() == KEY_BACK then
				window:hide()
			end
		end
	)

	return window, menu
end


-- _nowPlayingMenuListener
-- handles all keypresses on now playing menus
local function _nowPlayingMenuListener(event, menuItem)

	local evtType = event:getType()

	log:debug("_nowPlayingMenuListener(", tostring(evtType), ")")

	-- ACTION -> show Now Playing window
	if evtType == EVENT_ACTION then
		log:debug("_nowPlayingMenuListener(EVENT_ACTION)")

		if _nowPlayingWindow then
			if _nowPlayingMenu and _nowPlayingOldCurIdx then
				-- select current song
				log:debug("selecting item ", tostring(_nowPlayingOldCurIdx + 1))
				_nowPlayingMenu:setSelectedIndex(_nowPlayingOldCurIdx + 1)
			end
			_nowPlayingWindow:show()
			return EVENT_CONSUME
		else
			return EVENT_UNUSED
		end

	-- actions on button presses
	elseif evtType == EVENT_KEY_PRESS then
		log:debug("_nowPlayingMenuListener(EVENT_KEY_PRESS, ", tostring(menuItem:getValue()), ")")

		local evtCode = event:getKeycode()

		if evtCode == KEY_PAUSE then
			log:info('Pause toggle')

			_player:togglepause()
			return EVENT_CONSUME
			
		elseif evtCode == KEY_PLAY then

			-- play ???
--			if context then
--				log:info('Play ', tostring(menuItem:getValue()))
				
				--local cmd = context2playcmd(context)
--				_player:call(context:getPlayCmd())
--			else
--				log:info('Cannot play ', tostring(menuItem:getValue()))
--			end
--			return EVENT_CONSUME

		elseif evtCode == KEY_ADD then

			log:debug('Add in Now Playing ???')

		end

	-- actions on button held
	elseif evtType == EVENT_KEY_HOLD then
		log:debug("_menuListener(EVENT_KEY_HOLD, ", tostring(menuItem:getValue()), ")")

		local evtCode = event:getKeycode()

		if evtCode == KEY_PAUSE then
			log:debug('Stop')

			_player:stop()
			return EVENT_CONSUME

		end

	-- actions on button down
	elseif evtType == EVENT_KEY_DOWN then
	
		local evtCode = event:getKeycode()

		if evtCode == KEY_VOLUME_UP then
			log:info('Volume up')
		
			_openVolumePopup(1)
			return EVENT_CONSUME
		
		elseif evtCode == KEY_VOLUME_DOWN then
			log:info('Volume down')

			_openVolumePopup(-1)
			return EVENT_CONSUME
		end
	end
		
	-- if we reach here, we did not use the event
	-- maybe someone else wants it ?
	return EVENT_UNUSED
end



-- _statusSink
-- where the now playing data lands
local function _statusSink(chunk, err)
	log:debug("_statusSink()")

--[[
	170055:684063 INFO (Player.lua:194) - {id = "xdf27e20", method = "slim.request", params = {"31:70:05:5b:cc:5b", {"status", "-", 10, "subscribe:30", "tags:alj"}}, result = {@playlist = {{album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 38, playlist index = 0, title = "Introdiction"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 32, playlist index = 9, title = "Baby Love"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 49, playlist index = 1, title = "Solaar Pleure"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 45, playlist index = 2, title = "LÃ¨ve-Toi Et Rap"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 44, playlist index = 3, title = "Les Colonies"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 35, playlist index = 4, title = "Hasta La Vista (Intro)"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 36, playlist index = 5, title = "Hasta La Vista"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 41, playlist index = 6, title = "La Belle Et Le Bad Boy"}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 42, playlist index = 7, title = "La La La, La."}, {album = "CinquiÃ¨me As", artist = "MC Solaar", coverart = 1, id = 31, playlist index = 8, title = "Arkansas"}}, 
	duration = 113.607, 
	mixer volume = 67, 
	mode = "stop", 
	player_connected = 1, 
	player_name = "Krapul_Krapul", 
	playlist repeat = 0, 
	playlist shuffle = 0, 
	playlist_cur_index = 0, 
	playlist_tracks = 19, 
	power = 1, 
	rate = 1, 
	time = 0}}
--]]

	local emptyItem = {
		title = "Empty playlist",
		id = 0,
		["playlist index"] = 0,
	}

	local loadingItem = {
		title = "Loading...",
		id = 0,
		["playlist index"] = 0,
	}


	local chItems -- items in the current chunk
	local chItemsFirst -- first item playlist index
	local chItemsLast -- last item playlist index
	local plOldCur -- old current item
	local plNewCur
	local plCount -- total items in playlist

--[[
	local holes = {}
	local function _hole(index)
		log:debug("_hole=", tostring(index))
		for i,v in ipairs(holes) do
			if index == v.to + 1 then
				v.to = v.to+1
				return
			end
		end
		-- not in there, create
		table.insert(holes, {from=index, to=index})
	end
--]]	
	if chunk.power and chunk.power == 1 then
	
		log:debug("power is on")

		if chunk.playlist_tracks and chunk.playlist_tracks > 0 then
		
			plCount = chunk.playlist_tracks
			
			chItems = chunk["@playlist"]
			chItemsFirst = chItems[1]["playlist index"] + 1 -- CLI is 0 based
			chItemsLast = chItemsFirst + #chItems - 1
			
			if chunk.playlist_cur_index != _nowPlayingOldCurIdx then
				if _nowPlayingOldCurIdx then
					plOldCur = _nowPlayingOldCurIdx + 1
				end
				plNewCur = chunk.playlist_cur_index + 1
				_nowPlayingOldCurIdx = chunk.playlist_cur_index
			end
		end
	end
	
	if not chItems then
		plCount = 1
		chItems = {emptyItem}
		chItemsFirst = 1
		chItemsLast = 1
		_nowPlayingOldCurIdx = false
	end
	
	log:debug("playlist has ", tostring(plCount), " tracks")
	log:debug("chunk covers items ", tostring(chItemsFirst), " to ", tostring(chItemsLast))
	log:debug("rawitems in chunk = ", tostring(#chItems))
	
	
	local curChItem
	local curChIdx
	
	-- for each item in the playlist
	for plIdx = 1, plCount do

		log:debug("Playlist index ", tostring(plIdx))
	
		-- calculate the chunk for this item, may be null
		if plIdx < chItemsFirst or plIdx > chItemsLast then
			curChIdx = nil
			curChItem = nil
			log:debug(".. not in chunk data")
		else
			curChIdx = plIdx - chItemsFirst + 1
			log:debug(".. in chunk data at pos ", tostring(curChIdx))
			curChItem = chItems[curChIdx]
			assert(curChItem)
			assert(curChItem["playlist index"] == plIdx - 1)
		end
	
		-- we need a menu item for each article in the playlist
		local menuItem = _nowPlayingMenu:getItem(plIdx)
		
		if menuItem then -- there's one
			
			-- do we have the data
			if curChItem then
			
				log:debug(".. checking menuItem")
				
				-- compare items based on the id
				if curChItem.id != menuItem:getValue().id then
				
					-- not the same id, so update the menuItem
					log:debug("...id changed!")

					--get artwork if we have it
					local artworkId = curChItem.artwork_track_id
					if not artworkId and curChItem.coverart and curChItem.coverart == 1 then
						artworkId = curChItem.id
					end

					menuItem = _createNowPlayingMenuItem(curChItem, artworkId)
					_nowPlayingMenu:replaceIndex(menuItem, plIdx)
				end

			end
			
			-- don't do anything we ain't got the data...
		
		else
		
			-- there is no menu item for this playlist position
			-- create it
			log:debug("..creating menuItem")
			
			-- do we have the data ?
			if curChItem then
			
				--get artwork if we have it
				local artworkId = curChItem.artwork_track_id
				if not artworkId and curChItem.coverart and curChItem.coverart == 1 then
					artworkId = curChItem.id
				end
			
				menuItem = _createNowPlayingMenuItem(curChItem, artworkId)
				
			else
			
				-- No data, we're "loading..."
				menuItem = _createNowPlayingMenuItem(loadingItem)
--				_hole(plIdx)
			end
			
			-- add the menuItem!
			_nowPlayingMenu:addItem(menuItem)
		end
	end
--	debug.dump(holes)
	
	-- avoid crash if removing the selected item
	if _nowPlayingMenu:getSelectedIndex() > plCount+1 then
		_nowPlayingMenu:setSelectedIndex(plCount)
	end
	
	-- remove anything left in the menu
	-- go downwards to avoid moving items...
	for i = _nowPlayingMenu:numItems(), plCount+1, -1 do
		log:debug("deleting menuItem @ ", tostring(i))
		_nowPlayingMenu:removeIndex(i)
	end

	-- update current
	if plOldCur then
		log:debug("Item ", tostring(plOldCur), " was current")
		_nowPlayingMenu:styleIndex(plOldCur, "menu")
	end
	if plNewCur then
		log:debug("Item ", tostring(plNewCur), " is current")
		_nowPlayingMenu:styleIndex(plNewCur, "current")
	end
end








-- _createWindow
-- create a window in the plugin_browse style
local function _createWindow(title, titlek)
	log:debug("_createWindow(", tostring(title), ", ", tostring(titlek), ")")
	
	-- create a window
	local window = Window("slimbrowser." .. (titlek or "top"), tostring(title))

	-- create a menu
	local menu = Menu("menu")
	
	window:addWidget(menu)
	
	return window, menu
end


-- _menuListener
-- handles all keypresses on plugin_browe menus
local function _menuListener(event, menuItem, context, windowTitle)
--	log:debug("_menuListener() " .. event:getType())

	local evtType = event:getType()

	-- actions on enter
	if evtType == EVENT_ACTION then
		log:debug("_menuListener(EVENT_ACTION, ", tostring(menuItem:getValue()), ")")

		if context then
			return _browseMenu(menuItem, context, windowTitle)
		else
			return EVENT_UNUSED
		end

	-- actions on button presses
	elseif evtType == EVENT_KEY_PRESS then
		log:debug("_menuListener(EVENT_KEY_PRESS, ", tostring(menuItem:getValue()), ")")
		local evtCode = event:getKeycode()

		if evtCode == KEY_PAUSE then
			log:info('Pause toggle')

			_player:togglepause()
			return EVENT_CONSUME
			
		elseif evtCode == KEY_PLAY then

			-- play the selected item
			if context then

				log:info('Play ', tostring(menuItem:getValue()))
				
				_player:call(context:getPlayCmd())

			else
				log:info('Cannot play ', tostring(menuItem:getValue()))
			end

			return EVENT_CONSUME

		elseif evtCode == KEY_ADD then

			log:debug('Add')

		end

	-- actions on button held
	elseif evtType == EVENT_KEY_HOLD then
		log:debug("_menuListener(EVENT_KEY_HOLD, ", tostring(menuItem:getValue()), ")")

		local evtCode = event:getKeycode()

		if evtCode == KEY_PAUSE then
			log:debug('Stop')

			_player:stop()
			return EVENT_CONSUME

		end

	-- actions on button down
	elseif evtType == EVENT_KEY_DOWN then
		local evtCode = event:getKeycode()

		if evtCode == KEY_VOLUME_UP then
			log:info('Volume up')
		
			_openVolumePopup(1)
			return EVENT_CONSUME
		
		elseif evtCode == KEY_VOLUME_DOWN then
			log:info('Volume down')

			_openVolumePopup(-1)
			return EVENT_CONSUME
		end
	end
		
	-- if we reach here, we did not use the event
	-- maybe someone else wants it ?
	return EVENT_UNUSED
end


-- _browseSink
-- where the data lands
local function _browseSink(chunk, err, context)
	log:debug("_browseSink()")

	-- FIXME: make sure we land safely...
	
	-- restore full context
	local menuItem, windowTitle = context:restore()

	-- stop our loading icon
	menuItem:getParent():styleItem(menuItem, nil)
	
	-- get the contextual keys to navigate our chunk
	local loopk, titlek, idk, artworkk = context:getkeys()

	-- create a new window
	local window, menu = _createWindow(windowTitle, titlek)

	-- the string function used to format the menu item
	local itemMetatable = {
		__tostring = function(e)
			return menu:styleValue("format", tostring(e[titlek]), e)
		end
	}

	log:debug(chunk)
	chunk = chunk.result
	if (loopk and not chunk[loopk]) then
		-- FIXME: empty playlist?
		log:debug("empty playlist!!! ", loopk, "/", titlek)

	elseif (loopk) then

		for i, item in ipairs(chunk[loopk]) do
		
			--get artwork if we have it
			local menuIcon
			if artworkk then
				local artworkId = item[artworkk]
				if artworkId then
					menuIcon = Icon("artwork")
					_server:fetchArtworkThumb(artworkId, menuIcon:sink(), _artworkThumbUri)
				end
			end

			setmetatable(item, itemMetatable)
			local menuItem = Label("label", item, menuIcon)
			
			-- set our listener so we get events
			menuItem:addListener(
				EVENT_ACTION | EVENT_KEY_ALL,
				function(event)
					local context = context:down(item[idk])
					return _menuListener(event, menuItem, context, item[titlek])
				end
			)

			-- add item to menu
			menu:addItem(menuItem)
		end
		
	else
	
		for key, value in pairs(chunk) do
			-- FIXME: key translation
			-- FIXME: sorting
			if key != 'count' then
				local menuItem = Label("label", key .. ":" .. value)
				menu:addItem(menuItem)
				-- associate the current context with each item!
				-- so that stuff like songinfo get the trackid
				menuItem.context = context
			end
		end
	end
	
	window:show()
end


-- _getBrowseSink
-- returns a sink that remembers our context!
local function _getBrowseSink(context)
	return function(chunk, err)
		_browseSink(chunk, err, context)
	end
end


-- browseMenu
-- creates a window with a menu browsing music for the player
_browseMenu = function(menuItem, context, windowTitle)
	log:debug("_browseMenu(", windowTitle, ")")
	
	-- remember the window and the menu in the context
	context:store(menuItem, windowTitle)
	
	-- give feedback to user by updating the icon
	menuItem:getParent():styleItem(menuItem, "loading")

	-- get the data through the SlimServer object
	-- will call our sink asynchronously with the data
	_player:queuePriority(context:getBrowseRequest(_getBrowseSink(context)))

	return EVENT_CONSUME
end


-- _exit
-- exits the plugin...
local function _exit()
	log:debug("_exit()")
	
	if _playerMenuWindow then
		_playerMenuWindow:hide()
		_playerMenuWindow = nil
	end
	
	return EVENT_CONSUME
end


-- playerMenu
-- creates a window with a menu for the player out of SS delivered items
-- FIXME: document API
local function _playerMenu(menuItem, items)
	log:debug("_playerMenu(", menuItem:getValue(), ")")

	local window, menu = _createWindow(menuItem:getValue())

	if items then

		for i, item in ipairs(items) do
		
			-- create a menu item
			local menuItem = Label("label", item.title)

			-- unless handled below, the menuItem does nothing
			
			-- handle a submenu, like for Browse or Search
			if (item.action == 'items') then
			
				menuItem:addListener(
					EVENT_ACTION,
					_playerMenu, 
					item["@items"]
				)
			
			
			-- handles exit
			elseif item.action == 'exit' then
			
				-- if we have exit, then the menu cannot be closed with left
				menu:setCloseable(false)
				menuItem:addListener(EVENT_ACTION, _exit)
			
			
			-- handles browse
			elseif (item.action == 'browse') then
				
				if item.hierarchy then

					-- FIXME: need a status item.action, not this hack
					if item.hierarchy[1] == 'status' then

						menuItem:addListener(
							EVENT_ACTION | EVENT_KEY_ALL,
							function(event)
								return _nowPlayingMenuListener(
									event, 
									menuItem
								)
							end
						)

					else
				
						menuItem:addListener(
							EVENT_ACTION | EVENT_KEY_ALL,
							function(event)
								return _menuListener(event, menuItem, Context(_player, item.hierarchy), item.title)
							end
						)
					end
				else
					log:error("item: ", item.title, " has browse action without hierarchy!")
				end
			end

			-- add the menuItem to the menu
			menu:addItem(menuItem)
			
		end
	end
	
	return window
end


--==============================================================================
-- SlimBrowserApplet public methods
--==============================================================================


function displayName(self)
	return "SlimBrowser"
end


-- openPlayer
-- method attached to each player entry in the main menu by SlimDiscovery 
-- applet. Our meta ensures SlimDiscovery is loaded.
function openPlayer (self, menuItem, player)
	log:debug(
		"SlimBrowserApplet:openPlayer(", 
		tostring(menuItem:getValue()), 
		", ", 
		tostring(player), 
		")"
	)

	-- assign our locals
	_player = player
	_server = player:getSlimServer()
	
	-- get notified if the player goes away!
	jnt:subscribe(self)

	-- create a window for Now Playing
	_nowPlayingWindow, _nowPlayingMenu = _createNowPlayingWindow()

	-- the player's on
	-- FIXME: handle player off...
	local items = _player:onStage(_statusSink)
	
	if not items then
	
		-- FIXME: what to do in these cases? Error message? Back to home ?
		log:error("Player has no menu!!!!")
		items = {{action = "exit", title = "Exit"}}
	end
	
	-- save the main window
	_playerMenuWindow = _playerMenu(menuItem, items)
	
	return _playerMenuWindow, EVENT_CONSUME
end


-- notify_playerDelete
-- this is called by jnt when the playerDelete message is sent
function notify_playerDelete(self, player)

	-- if this concerns our player
	if player == _player then
		-- panic!
		log:warn("Player gone while browsing it ! -- packing home!")
		-- FIXME: need a Window:hideMeAndAbove?
	end
end


-- free
-- should free resources, stop threads, whatever
function free(self)
	log:debug("SlimBrowserApplet:free()")
	
	_player:offStage()
		
	_player = nil
	_server = nil
	_playerMenuWindow = nil
	_nowPlayingWindow = nil
	
	return true
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

