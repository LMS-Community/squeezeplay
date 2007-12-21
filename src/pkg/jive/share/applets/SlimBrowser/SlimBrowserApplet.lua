
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
local tostring, tonumber, type, sort = tostring, tonumber, type, sort
local pairs, ipairs, select, _assert = pairs, ipairs, select, _assert

local oo                     = require("loop.simple")
local table                  = require("jive.utils.table")
local string                 = require("string")
                             
local Applet                 = require("jive.Applet")
local AppletManager          = require("jive.AppletManager")
local Player                 = require("jive.slim.Player")
local SlimServer             = require("jive.slim.SlimServer")
local Framework              = require("jive.ui.Framework")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")
local Group                  = require("jive.ui.Group")
local Menu                   = require("jive.ui.Menu")
local Label                  = require("jive.ui.Label")
local Icon                   = require("jive.ui.Icon")
local Choice                 = require("jive.ui.Choice")
local Slider                 = require("jive.ui.Slider")
local Timer                  = require("jive.ui.Timer")
local Textinput              = require("jive.ui.Textinput")
local Textarea               = require("jive.ui.Textarea")
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Checkbox               = require("jive.ui.Checkbox")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local DateTime               = require("jive.utils.datetime")
                             
local DB                     = require("applets.SlimBrowser.DB")

local debug                  = require("jive.utils.debug")

local log                    = require("jive.utils.log").logger("player.browse")
local logd                   = require("jive.utils.log").logger("player.browse.data")
                             
local EVENT_KEY_ALL          = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP           = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_HOLD         = jive.ui.EVENT_KEY_HOLD
local EVENT_SCROLL           = jive.ui.EVENT_SCROLL
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED
local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_FOCUS_GAINED     = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST       = jive.ui.EVENT_FOCUS_LOST
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_WINDOW_ACTIVE    = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_HIDE             = jive.ui.EVENT_HIDE
local EVENT_SHOW             = jive.ui.EVENT_SHOW
local KEY_FWD                = jive.ui.KEY_FWD
local KEY_REW                = jive.ui.KEY_REW
local KEY_HOME               = jive.ui.KEY_HOME
local KEY_PLAY               = jive.ui.KEY_PLAY
local KEY_ADD                = jive.ui.KEY_ADD
local KEY_BACK               = jive.ui.KEY_BACK
local KEY_PAUSE              = jive.ui.KEY_PAUSE
local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN
local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP

local jiveMain               = jiveMain
local iconbar                = iconbar
local jnt                    = jnt


module(...)
oo.class(_M, Applet)


--==============================================================================
-- Global "constants"
--==============================================================================

-- number of items to get for missing items in status.
-- Note the first/pushed number of items is defined in Player.lua
local STATUS_MISSING_FETCH = 100 

-- number of items to fetch initially (window opens) for browse items
local BROWSE_FIRST_FETCH = 100
-- number of items to get for browse missing items
local BROWSE_MISSING_FETCH = 100

-- number of volume steps
local VOLUME_STEPS = 20

--==============================================================================
-- Local variables (globals)
--==============================================================================

-- The string function, for easy reference
local _string

-- The player we're browsing and it's server
local _player = false
local _server = false

-- The path of enlightenment
local _curStep = false
local _statusStep = false

-- Our main menu/handlers
local _playerMenus = {}
local _playerKeyHandler = false

-- The last entered text
local _lastInput = ""

--==============================================================================
-- Local functions
--==============================================================================


-- Forward declarations 
local _newDestination
local _actionHandler


-- _safeDeref
-- safely derefence a structure in depth
-- doing a.b.c.d will fail if b or c are not defined
-- _safeDeref(a, "b", "c", "d") will always work (of course, it returns nil if b or c are not defined!)
local function _safeDeref(struct, ...)
--	log:debug("_safeDeref()")
--	log:debug(struct)
	local res = struct
	for i=1, select('#', ...) do
		local v = select(i, ...)
		if type(res) != 'table' then return nil end
--		log:debug(v)
		if v then
			res = res[v]
			if not res then return nil end
		end
	end
--	log:debug("_safeDeref =>")
--	log:debug(res)
	return res
end


-- _priorityAssign(key, defaultValue, table1, table2, ...)
-- returns the first non nil value of table1[key], table2[key], etc.
-- if no table match, defaultValue is returned
local function _priorityAssign(key, defaultValue, ...)
--	log:debug("_priorityAssign(", key, ")")
	for i=1, select('#', ...) do
		local v = select(i, ...)
--		log:debug(v)
		if v then 
			local res = v[key]
			if res then return res end
		end
	end
	return defaultValue
end


-- artworkThumbUri
-- returns a URI to fetch artwork on the server
-- FIXME: should this be styled?
local function _artworkThumbUri(iconId, size)

	-- we want a 56 pixel thumbnail if it wasn't specified
	if not size then size = 56 end

	-- if the iconId is a number, this is cover art, otherwise it's static content
	-- do some extra checking instead of just looking for type = number
	local thisIsAnId = true
	if type(iconId) == number then -- iconId is a number
		thisIsAnId = true
	elseif string.find(iconId, "%a") then -- iconID string contains a letter
		thisIsAnId = false
	else -- a string with no letters must be an id
		thisIsAnId = true
	end

	-- if this is a number, construct the path for a sizexsize cover art thumbnail
	local artworkUri
	local resizeFrag = '_' .. size .. 'x' .. size .. '_p.png' -- 'p' is for padded, png gives us transparency
	if thisIsAnId then 
		-- we want a 56 pixel thumbnail if it wasn't specified
		artworkUri = '/music/' .. iconId .. '/cover' .. resizeFrag 
	-- if this isn't a number, then we just want the path with server-side resizing
	-- if .png, then resize it
	elseif string.match(iconId, '.png') then
		artworkUri = string.gsub(iconId, '.png', resizeFrag) 
	-- otherwise punt
	else
		return iconId
	end
	return artworkUri
end


-- _openVolumePopup
-- manages the volume pop up window
local function _openVolumePopup(vol)

--	log:debug("_openVolumePopup START ------------------- (", vol, ")")

	local volume = _player:getVolume()

	-- take no action if we don't know the players volume, for example
	-- shortly after changing players.
	if not volume then
		return
	end

	local popup = Popup("volumePopup")

	popup:addWidget(Label("title", "Volume"))

	local slider = Slider("volume")
	slider:setRange(-1, 100, volume)
	popup:addWidget(Group("volumeGroup", {
				      Icon("volumeMin"),
				      slider,
				      Icon("volumeMax")
			      }))

	local volumeStep = 100 / VOLUME_STEPS

	local _updateVolume =
		function(delta)
			local new = volume + delta * volumeStep

			if new > 100 then new = 100 elseif new < 0 then new = 0 end
			
			volume = _player:volume(new) or volume
			slider:setValue(volume)
			
			popup:showBriefly()
		end

	-- timer to change volume
	local timer = Timer(300,
		function()
--			log:debug("_openVolumePopup - timer ", timer)
			_updateVolume(vol)
		end
	)

	-- listener for volume up and down keys
	popup:addListener(
		EVENT_KEY_ALL,
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

			-- if timer is gone, don't do anything => the window is closing
			if not timer then
				return EVENT_CONSUME
			end

			local evtType = event:getType()
			if evtType == EVENT_KEY_UP then
				-- stop volume timer
--				log:debug("stop timer (listener) ", timer)
				timer:stop()
				-- ensure we send an update for the final volume setting
				_player:volume(volume, true)
			elseif evtType == EVENT_KEY_DOWN then
				-- start volume timer
--				log:debug("start timer (listener) ", timer)
				timer.callback()
				timer:restart()
			end

			-- make sure we don't hide popup
			return EVENT_CONSUME
		end
	)

	-- scroll listener
	popup:addListener(EVENT_SCROLL,
			  function(event)
				  _updateVolume(event:getScroll())
			  end)


	-- we handle events
	popup.brieflyHandler = 1

	popup:showBriefly(2000,
		function()
			if timer then
--				log:debug("stop timer (showBriefly timeout), ", timer)
				timer:stop()
				-- make sure it cannot ever be started again
				timer = nil
			end
		end,
		Window.transitionPushPopupUp,
		Window.transitionPushPopupDown
	)

	timer:start()

	-- update volume from initial key press
	_updateVolume(vol)

--	log:debug("_openVolumePopup END --------------------------")
end

local function _pushToNewWindow(step)
	if not step then
		return
	end

	if _curStep.menu then
		_curStep.menu:lock(
			function()
				step.cancelled = true
			end)
	end
	
	step.loaded = function()
		if _curStep.menu then
			_curStep.menu:unlock()
		end
		_curStep = step
		step.window:show()
      	end
end

-- _newWindowSpec
-- returns a Window spec based on the concatenation of base and item
-- window definition
local function _newWindowSpec(db, item, titleStyle)
	if not titleStyle then titleStyle = '' end
	log:debug("_newWindowSpec()")
	
	local bWindow
	local iWindow = _safeDeref(item, 'window')

	if db then
		bWindow = _safeDeref(db:chunk(), 'base', 'window')
	end
	
	-- determine style
	local menuStyle = _priorityAssign('menuStyle', "", iWindow, bWindow)
	return {
		["windowStyle"]      = "",
		["labelTitleStyle"]  = _priorityAssign('titleStyle', titleStyle, iWindow, bWindow) .. "title",
		["menuStyle"]        = menuStyle .. "menu",
		["labelItemStyle"]   = menuStyle .. "item",
		["text"]             = _priorityAssign('text',       item["text"],    iWindow, bWindow),
		["icon-id"]          = _priorityAssign('icon-id',    item["icon-id"], iWindow, bWindow),
		["icon"]             = _priorityAssign('icon',       item["icon"],    iWindow, bWindow),
	} 
end


-- _artworkItem
-- updates a group widget with the artwork for item
local function _artworkItem(item, group)
	local icon = group:getWidget("icon")

	if item["icon-id"] then
		-- Fetch an image from SlimServer
		_server:fetchArtworkThumb(item["icon-id"], icon, _artworkThumbUri, 56)
	elseif item["icon"] then
		-- Fetch a remote image URL, sized to 56x56
		_server:fetchArtworkURL(item["icon"], icon, 56)

	else
		_server:cancelArtwork(icon)

	end
end


-- _checkboxItem
-- returns a checkbox button for use on a given item
local function _checkboxItem(item, db)
	local checkboxFlag = tonumber(item["checkbox"])
	if checkboxFlag and not item["_jive_button"] then
		item["_jive_button"] = Checkbox(
			"checkbox",
			function(_, checkboxFlag)
				log:debug("checkbox updated: ", checkboxFlag)
				if (checkboxFlag) then
					log:debug("ON: ", checkboxFlag)
					_actionHandler(nil, nil, db, nil, nil, 'on', item) 
				else
					log:debug("OFF: ", checkboxFlag)
					_actionHandler(nil, nil, db, nil, nil, 'off', item) 
				end
			end,
			checkboxFlag == 1
		)
	end
	return item["_jive_button"]
end


-- _radioItem
-- returns a radio button for use on a given item
local function _radioItem(item, db)
	local radioFlag = tonumber(item["radio"])
	if radioFlag and not item["_jive_button"] then
		item["_jive_button"] = RadioButton(
			"radio",
			db:getRadioGroup(),
			function() 
				log:warn('Callback has been called') 
				_actionHandler(nil, nil, db, nil, nil, 'do', item) 
			end,
			radioFlag == 1
		)
	end
	return item["_jive_button"]
end


-- _decoratedLabel
-- updates or generates a label cum decoration in the given labelStyle
local function _decoratedLabel(group, labelStyle, item, db)
	-- if item is a windowSpec, then the icon is kept in the spec for nothing (overhead)
	-- however it guarantees the icon in the title is not shared with (the same) icon in the menu.

	if not group then
		group = Group("item", { text = Label("text", ""), icon = Icon("icon"), play = Icon("play") })
	end

	if item then
		group:setWidgetValue("text", item.text)

		if item["radio"] then
			group._type = "radio"
			group:setWidget("icon", _radioItem(item, db))

		elseif item["checkbox"] then
			group._type = "checkbox"
			group:setWidget("icon", _checkboxItem(item, db))

		else
			if group._type then
				group:setWidget("icon", Icon("icon"))
				group._type = nil
			end
			_artworkItem(item, group)
		end
		group:setStyle(labelStyle)

	else
		if group._type then
			group:setWidget("icon", Icon("icon"))
			group._type = nil
		end

		group:setWidgetValue("text", "")
		group:setWidgetValue("icon", nil)
		group:setStyle("item")
	end

	return group
end


-- _performJSONAction
-- performs the JSON action...
local function _performJSONAction(jsonAction, from, qty, sink)
	log:debug("_performJSONAction(from:", from, ", qty:", qty, "):")
	log:warn("_performJSONAction(from:", from, ", qty:", qty, "):")
	
	local cmdArray = jsonAction["cmd"]
	
	-- sanity check
	if not cmdArray or type(cmdArray) != 'table' then
		log:error("JSON action for ", actionName, " has no cmd or not of type table")
		return
	end
	
	-- replace player if needed
	local playerid = jsonAction["player"]
	if not playerid or tostring(playerid) == "0" then
		playerid = _player.id
	end
	
	-- look for __INPUT__ as a param value
	local params = jsonAction["params"]
	local newparams
	if params then
		newparams = {}
		for k, v in pairs(params) do
			if v == '__INPUT__' then
				table.insert( newparams, _lastInput )
			elseif v == '__TAGGEDINPUT__' then
				if k == 'time' then
					local _secondsFromMidnight = DateTime:secondsFromMidnight(_lastInput)
					log:debug("SECONDS FROM MIDNIGHT", _secondsFromMidnight)
					table.insert( newparams, k .. ":" .. _secondsFromMidnight )
				else 
					table.insert( newparams, k .. ":" .. _lastInput )
				end
			else
				table.insert( newparams, k .. ":" .. v )
			end
		end
	end
	
	local request = {}
	
	for i, v in ipairs(cmdArray) do
		table.insert(request, v)
	end
	
	table.insert(request, from)
	table.insert(request, qty)
	
	if newparams then
		for i, v in ipairs(newparams) do
			table.insert(request, v)
		end
	end
	
	-- send the command
	_server:request(sink, playerid, request)
end


-- _goNowPlaying
--
local function _goNowPlaying()
	if _statusStep then
		log:debug("_goNowPlaying()")
	
		-- show our NowPlaying window!
		_statusStep.window:show()
		
		-- arrange so that menuListener works
		_statusStep.origin = _curStep
		_curStep = _statusStep

		-- current playlist should select currently playing item 
		if _statusStep.menu.list.currentIndex then
			_statusStep.menu.selected = _statusStep.menu.list.currentIndex
			if _statusStep.menu["_lastSelectedIndex"] then
				_statusStep.menu["_lastSelectedIndex"] = _statusStep.menu.selected
				_statusStep.menu["_lastSelectedOffset"] = 2
			end
			-- since we've hacked the _lastSelectedIndex, it's necessary to 
			-- _updateWidgets to display correctly selected item
			_statusStep.menu:_updateWidgets()
		end
	
		return EVENT_CONSUME
	end
	return EVENT_UNUSED
end


-- _getStepSink
-- returns a closure to a sink embedding step
local function _getStepSink(step, sink)
	return function(chunk, err)
		sink(step, chunk, err)
	end
end


-- _bigArtworkPopup
-- special case sink that pops up big artwork
local function _bigArtworkPopup(chunk, err)

	log:debug("Rendering artwork")
	local popup = Popup("popupArt")
	local icon = Icon("artwork")

	local screenW, screenH = Framework:getScreenSize()
	local shortDimension = screenW
	if screenW > screenH then
		shortDimension = screenH
	end

	log:debug("Artwork width/height will be ", shortDimension)
	_server:fetchArtworkThumb(chunk.data.artworkId, icon, _artworkThumbUri, shortDimension)
	popup:addWidget(icon)
	popup:show()
	return popup
end


-- _devnull
-- sinks that silently swallows data
-- used for actions that go nowhere (play, add, etc.)
local function _devnull(chunk, err)
	log:debug('_devnull()')
	log:debug(chunk)
end


-- _browseSink
-- sink that sets the data for our go action
local function _browseSink(step, chunk, err)
	log:debug("_browseSink()")

	-- are we cancelled?
	if step.cancelled then
		log:debug("_browseSink(): ignoring data, action cancelled...")
		return
	end

	-- function to perform when the data is loaded? 
	if step.loaded then
		step.loaded()
		step.loaded = nil
	end

	if chunk then
		local data
		
		-- move result key up to top-level
		if chunk.result then
			data = chunk.result
		else
			data = chunk.data
		end
		
		if logd:isDebug() then
			debug.dump(chunk, 8)
		end
	
		-- if our window has a menu - some windows don't :(
		if step.menu then
			step.menu:setItems(step.db:menuItems(data))

			-- what's missing?
			local from, qty = step.db:missing(BROWSE_MISSING_FETCH)
		
			if from then
				_performJSONAction(step.data, from, qty, step.sink)
			end
		end
		
	else
		log:error(err)
	end
end

-- _menuSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _menuSink(self, cmd)
	return function(chunk, err)

		-- catch race condition if we've switch player
		if not _player then
			return
		end

		log:warn("*********** _menuSink has been called***********")
		log:warn(chunk.data[1])
		log:warn(chunk.data[2])
		log:warn(chunk.data[3])
		log:warn(chunk.data[4])

		-- process data from a menu notification
		-- each chunk.data[2] contains a table that needs insertion into the menu
		local menuItems = chunk.data[2]
		-- directive for these items is in chunk.data[3]
		local menuDirective = chunk.data[3]
		-- the player ID this notification is for is in chunk.data[4]
		local playerId = chunk.data[4]

		-- FIXME: `playerId not nil` part of this clause needs to be removed
		-- It is necessary to support pre 21Dec07 versions of SC
		if playerId ~= nil and playerId ~= 'all' and playerId ~= _player.id then
			log:warn('***** This menu notification was not for this player ***** ')
			log:warn("Notification for: ", playerId)
			log:warn("This player is: ", _player.id)
			return
		end

		for k, v in pairs(menuItems) do

			--debug.dump(v.actions, -1)

			local item = {
					id = v.id,
					node = v.node,
					text = v.text,
					weight = v.weight,
					window = v.window,
					sound = "WINDOWSHOW",
				}

			local choiceAction = _safeDeref(v, 'actions', 'do', 'choices')

			if v.isANode then
				jiveMain:addNode(item)

			elseif menuDirective == 'remove' then
				jiveMain:removeItemById(item.id)

			elseif choiceAction then

				local selectedIndex = 1
				if v.selectedIndex then
					selectedIndex = tonumber(v.selectedIndex)
				end

				local choice = Choice(
					"choice",
					v.choiceStrings,
					function(obj, selectedIndex)
						local jsonAction = v.actions['do'].choices[selectedIndex]
						_performJSONAction(jsonAction, nil, nil, nil)
					end,
					selectedIndex
				)
				
				item.icon = choice

				--add the item to the menu
				jiveMain:addItem(item)

			else

				item.callback = function()
					--	local jsonAction = v.actions.go
						local jsonAction, from, to, step, sink
						local doAction = _safeDeref(v, 'actions', 'do')
						local goAction = _safeDeref(v, 'actions', 'go')

						if doAction then
							jsonAction = v.actions['do']
						elseif goAction then
							jsonAction = v.actions.go
						else
							return false
						end

						-- we need a new window for go actions, or do actions that involve input
						if goAction or (doAction and v.input) then
							from = 0
							to = BROWSE_FIRST_FETCH
							step, sink =_newDestination(nil,
										  v,
										  _newWindowSpec(nil, v),
										  _browseSink,
										  jsonAction
									  )
	
							jiveMain:lockItem(item,
								  function()
								  step.cancelled = true
							  end)
	
							step.loaded = function()
								      jiveMain:unlockItem(item)
	
								      _curStep = step
								      step.window:show()
							      end
						end

						_performJSONAction(jsonAction, from, to, sink)
					end

				_playerMenus[item.id] = item
				jiveMain:addItem(item)
			end
		end

		-- add local menus
		local localItems = {
			{
				id = "nowplaying",
				node = "home",
				text = _string("SLIMBROWSER_NOW_PLAYING"),
				callback = _goNowPlaying,
			},
		}

		for i, item in ipairs(localItems) do
			_playerMenus[item.id] = item
			jiveMain:addItem(item)
		end
         end
end


-- _statusSink
-- sink that sets the data for our status window(s)
local function _statusSink(step, chunk, err)
	log:debug("_statusSink()")
		
	if logd:isDebug() then
		debug.dump(chunk, 8)
	end

	-- currently we're not going anywhere with Now Playing...
	_assert(step == _statusStep)

	-- Just in case we get passed a full event
	local data = chunk
	if data.data then
		data = data.data
	end
	
	if data then
		if logd:isDebug() then
			debug.dump(data, 8)
		end
		
		if data.mode == "play" then
			step.window:setTitle(_string("SLIMBROWSER_NOW_PLAYING"))
			step.window:setTitleStyle("newmusictitle")
		elseif data.mode == "pause" then
			step.window:setTitle(_string("SLIMBROWSER_PAUSED"))
			step.window:setTitleStyle("newmusictitle")
		elseif data.mode == "stop" then
			step.window:setTitle(_string("SLIMBROWSER_STOPPED"))
			step.window:setTitleStyle("newmusictitle")
		end

		-- stuff from the player is just json.result
		-- stuff from our completion calls below will be full json
		-- adapt
		-- XXX: still needed?
		if data.id and data.result then
			data = data.result
		end
		
		-- handle the case where the player disappears
		-- return silently
		if data.error then
			log:info("_statusSink() chunk has error: returning")
			return
		end
		
		-- FIXME: this can go away once we dispense of the upgrade messages
		-- if we have a data.item_loop[1].text == 'READ ME', 
		-- we've hit the SC upgrade message and shouldn't be dropping it into NOW PLAYING
		if data.item_loop and data.item_loop[1].text == 'READ ME' then
			log:debug('This is not a message suitable for the Now Playing list')
			return
		end

		step.menu:setItems(step.db:menuItems(data))

		-- what's missing?
		local from, qty = step.db:missing(STATUS_MISSING_FETCH)

		if from then
			_server:request(
				step.sink,
				_player.id,
				{ 'status', from, qty, 'menu:menu' }
			)
		end

	else
		log:error(err)
	end
end


-- _globalActions
-- provides a function for default button behaviour, called outside of the context of the browser
local _globalActions = {
	["home"] = function()
		local windowStack = Framework.windowStack
			   
		-- are we in home?
		if #windowStack > 1 then
			Framework:playSound("JUMP")
			while #windowStack > 1 do
				windowStack[#windowStack - 1]:hide(nil, "JUMP")
			end
		else
			Framework:playSound("WINDOWSHOW")
			_goNowPlaying()
		end
				
		return EVENT_CONSUME
	end,

	["play"] = function()
	        Framework:playSound("PLAYBACK")
		_player:play()
		return EVENT_CONSUME
	end,

	["pause"] = function()
	        Framework:playSound("PLAYBACK")
		_player:togglePause()
		return EVENT_CONSUME
	end,

	["pause-hold"] = function()
	        Framework:playSound("PLAYBACK")
		_player:stop()
		return EVENT_CONSUME
	end,

	["rew"] = function()
	        Framework:playSound("PLAYBACK")
		_player:rew()
		return EVENT_CONSUME
	end,

	["fwd"] = function()
	        Framework:playSound("PLAYBACK")
		_player:fwd()
		return EVENT_CONSUME
	end,

	["volup-down"] = function()
		_openVolumePopup(1)
		return EVENT_CONSUME
	end,

	["voldown-down"] = function()
		_openVolumePopup(-1)
		return EVENT_CONSUME
	end,
}


-- _defaultActions
-- provides a function for each actionName for which Jive provides a default behaviour
-- the function prototype is the same than _actionHandler (i.e. the whole shebang to cover all cases)
local _defaultActions = {
	
	-- default commands in Now Playing
	
	["play-status"] = function(_1, _2, _3, dbIndex)
		if _player:isPaused() and _player:isCurrent(dbIndex) then
			_player:togglePause()
		else
			-- the DB index IS the playlist index + 1
			_player:playlistJumpIndex(dbIndex)
		end
		return EVENT_CONSUME
	end,

	["add-status"] = function(_1, _2, _3, dbIndex)
		_player:playlistDeleteIndex(dbIndex)
		return EVENT_CONSUME
	end,

	["add-hold-status"] = function(_1, _2, _3, dbIndex)
		_player:playlistZapIndex(dbIndex)
		return EVENT_CONSUME
	end,
}


-- _actionHandler
-- sorts out the action business: item action, base action, default action...
_actionHandler = function(menu, menuItem, db, dbIndex, event, actionName, item)
	log:warn("_actionHandler(", actionName, ")")

	if logd:isDebug() then
		debug.dump(item, 4)
	end

	-- some actions work (f.e. pause) even with no item around
	if item then
	
		local chunk = db:chunk()
		local bAction
		local iAction
		local onAction
		local offAction
		
		-- special cases for go action:
		if actionName == 'go' then
			
			-- check first for a hierarchical menu or a input to perform 
			if item['count'] or (item['input'] and not item['_inputDone']) then
				log:debug("_actionHandler(", actionName, "): hierachical or input")

				menuItem:playSound("WINDOWSHOW")

				-- make a new window
				local step, sink = _newDestination(_curStep, item, _newWindowSpec(db, item), _browseSink)
				
				_pushToNewWindow(step)

				-- the item is the data, wrapped into a result hash
				local res = {
					["result"] = item,
				}
				-- make base accessible
				_browseSink(step, res)
				return EVENT_CONSUME
			end
			
			-- check for a 'do' action (overrides a straight 'go')
			-- actionName is corrected below!!
			bAction = _safeDeref(chunk, 'base', 'actions', 'do')
			iAction = _safeDeref(item, 'actions', 'do')
			onAction = _safeDeref(item, 'actions', 'on')
			offAction = _safeDeref(item, 'actions', 'off')
		end
	
		
		-- now check for a run-of-the mill action
		if not (iAction or bAction or onAction or offAction) then
			bAction = _safeDeref(chunk, 'base', 'actions', actionName)
			iAction = _safeDeref(item, 'actions', actionName)
		else
			-- if we reach here, it's a DO action...
			-- okay to call on or off this, as they are just special cases of 'do'
			actionName = 'do'
		end
		
		-- XXX: Fred: After an input box is used, chunk is nil, so base can't be used
	
		if iAction or bAction then
	
			-- the resulting action, if any
			local jsonAction
	
			-- process an item action first
			if iAction then
				log:debug("_actionHandler(", actionName, "): item action")
			
				-- found a json command
				if type(iAction) == 'table' then
					jsonAction = iAction
				end
			
			-- not item action, look for a base one
			elseif bAction then
				log:debug("_actionHandler(", actionName, "): base action")
			
				-- found a json command
				if type(bAction) == 'table' then
			
					jsonAction = bAction
				
					-- this guy may want to be completed by something in the item
					-- base gives the name of item key in key itemParams
					-- we're looking for item[base.itemParams]
					local paramName = jsonAction["itemsParams"]
					log:debug("..paramName:", paramName)
					if paramName then
					
						-- sanity check
						if type(paramName) != 'string' then
							log:error("Base action for ", actionName, " has itemParams field but not of type string!")
							return EVENT_UNUSED
						end

						local iParams = item[paramName]
						if iParams then
						
							-- sanity check, can't hurt
							if type(iParams) != 'table' then
								log:error("Base action for ", actionName, " has itemParams: ", paramName, " found in item but not of type table!")
								return EVENT_UNUSED
							end
						
							-- found 'em!
							-- add them to the command
							-- make sure the base has a params item!
							local params = jsonAction["params"]
							if not params then
								params = {}
								jsonAction["params"] = params
							end
							for k,v in pairs(iParams) do
								params[k] = v
							end
						else
							log:debug("No ", paramName, " entry in item, no action taken")
							return EVENT_UNUSED
						end
					end
				end
			end -- elseif bAction
	
			-- now we may have found a command
			if jsonAction then
				log:debug("_actionHandler(", actionName, "): json action")

				if menuItem then
					menuItem:playSound("WINDOWSHOW")
				end
			
				-- set good or dummy sink as needed
				-- prepare the window if needed
				local step
				local sink = _devnull
				local from
				local to
				if actionName == 'go' then
					from = 0
					to = BROWSE_FIRST_FETCH
					step, sink = _newDestination(_curStep, item, _newWindowSpec(db, item), _browseSink, jsonAction)
				elseif item["showBigArtwork"] then
					sink = _bigArtworkPopup
				end

				_pushToNewWindow(step)
			
				-- send the command
				 _performJSONAction(jsonAction, from, to, sink)
			
				return EVENT_CONSUME
			end
		end
	end
	
	-- fallback to built-in
	-- these may work without an item
	
	-- Note the assumption here: event handling happens for front window only
	if _curStep.actionModifier then
		local builtInAction = actionName .. _curStep.actionModifier

		local func = _defaultActions[builtInAction]
		if func then
			log:debug("_actionHandler(", builtInAction, "): built-in")
			return func(menu, menuItem, db, dbIndex, event, builtInAction, item)
		end
	end
	
	local func = _defaultActions[actionName]
	if func then
		log:debug("_actionHandler(", actionName, "): built-in")
		return func(menu, menuItem, db, dbIndex, event, actionName, item)
	end
	
	-- no success here for this event
	return EVENT_UNUSED
end


--  Go           right, return, mouse middle button
--  Back         left, mouse right button
--  Scroll up    up, mouse wheel
--  Scroll down  down, mouse wheel
--  Up           i
--  Down         k
--  Left         j
--  Right        l
--  Play         x p, mouse left button
--  Pause        c space
--  Add          a
--  Rew          z <
--  Fwd          b >
--  Home         h
--  Volume up    + =
--  Volume down  -


-- map from a key to an actionName
local _keycodeActionName = {
	[KEY_VOLUME_UP] = 'volup', 
	[KEY_VOLUME_DOWN] = 'voldown', 
	[KEY_HOME] = 'home', 
	[KEY_PAUSE] = 'pause', 
	[KEY_PLAY]  = 'play',
	[KEY_FWD]   = 'fwd',
	[KEY_REW]   = 'rew',
	[KEY_ADD]   = 'add',
}
-- internal actionNames:
--				  'inputDone'

-- _browseMenuListener
-- called 
local function _browseMenuListener(menu, menuItem, db, dbIndex, event)

	-- ok so joe did press a key while in our menu...
	-- figure out the item action...
	local evtType = event:getType()

	-- we don't care about focus: we get one everytime we change current item
	-- and it just pollutes our logging.
	if evtType == EVENT_FOCUS_GAINED
		or evtType == EVENT_FOCUS_LOST
		or evtType == EVENT_HIDE
		or evtType == EVENT_SHOW then
		return EVENT_UNUSED
	end

	log:debug("_browseMenuListener(", event:tostring(), ", " , index, ")")
	
	-- we don't care about events not on the current window
	-- assumption for event handling code: _curStep corresponds to current window!
	if _curStep.menu != menu then
		log:debug("_curStep: ", _curStep)

		log:debug("Ignoring, not visible")
		return EVENT_UNUSED
	end
	
	-- we don't want to do anything if this menu item involves an active decoration
	-- like a radio, checkbox, or set of choices
	-- further, we want the event to propagate to the active widget, so return EVENT_UNUSED
	local item = db:item(dbIndex)
	if item["_jive_button"] then
		return EVENT_UNUSED
	end

	
	-- actions on button down
	if evtType == EVENT_ACTION then
		log:debug("_browseMenuListener: EVENT_ACTION")
		
		if item then
			-- check for a local action
			local func = item._go
			if func then
				log:debug("_browseMenuListener: Calling found func")
				menuItem:playSound("WINDOWSHOW")
				return func()
			end
		
			-- otherwise, check for a handler
			return _actionHandler(menu, menuItem, db, dbIndex, event, 'go', item)
		end

	elseif evtType == EVENT_KEY_PRESS then
		log:debug("_browseMenuListener: EVENT_KEY_PRESS")
		
		local actionName = _keycodeActionName[event:getKeycode()]

		if actionName then
			return _actionHandler(menu, menuItem, db, dbIndex, event, actionName, item)
		end
		
	elseif evtType == EVENT_KEY_HOLD then
		log:debug("_browseMenuListener: EVENT_KEY_HOLD")
		
		local actionName = _keycodeActionName[event:getKeycode()]

		if actionName then
			return _actionHandler(menu, menuItem, db, dbIndex, event, actionName .. "-hold", item)
		end
	end

	-- if we reach here, we did not handle the event :(
	return EVENT_UNUSED
end


-- _browseMenuRenderer
-- renders a basic menu
local function _browseMenuRenderer(menu, widgets, toRenderIndexes, toRenderSize, db)
	--	log:debug("_browseMenuRenderer(", toRenderSize, ", ", db, ")")
	-- we must create or update the widgets for the indexes in toRenderIndexes.
	-- this last list can contain null, so we iterate from 1 to toRenderSize

	local labelItemStyle = db:labelItemStyle()
	
	for widgetIndex = 1, toRenderSize do
		local dbIndex = toRenderIndexes[widgetIndex]
		
		if dbIndex then
			
			-- the widget in widgets[widgetIndex] shall correspond to data[dataIndex]
--			log:debug(
--				"_browseMenuRenderer: rendering widgetIndex:", 
--				widgetIndex, ", dataIndex:", dbIndex, ")"
--			)
			
			local widget = widgets[widgetIndex]

			local item, current = db:item(dbIndex)

			local style = labelItemStyle
			
			if current then
				style = "albumcurrent"
			elseif item and item["style"] then
				style = item["style"]
			end

			widgets[widgetIndex] = _decoratedLabel(widget, style, item, db)
		end
	end
end


-- _newDestination
-- origin is the step we are coming from
-- item is the source item
-- windowSpec is the window spec, generally computed by _newWindowSpec to aggregate base and item
-- sink is the sink this destination will use: we must create a closure so that on receiving the data
--  the destination can be retrieved (i.e. reunite data and window)
-- data is generic data that is stored in the step; it is used f.e. to keep the json action between the
--  first incantation and the subsequent ones needed to capture all data (see _browseSink).
_newDestination = function(origin, item, windowSpec, sink, data)
	log:debug("_newDestination():")
	log:debug(windowSpec)
	
	
	-- a DB (empty...) 
	local db = DB(windowSpec)
	
	-- create a window in all cases
	local window = Window(windowSpec.windowStyle)
	window:setTitleWidget(_decoratedLabel(nil, windowSpec.labelTitleStyle, windowSpec, db))
	
	local menu

	-- if the item has an input field, we must ask for it
	if item and item['input'] and not item['_inputDone'] then

		local inputSpec
		
		-- legacy SS compatibility
		-- FIXME: remove SS compatibility with legacy JiveMLON generation
		if type(item['input']) != "table" then
			inputSpec = {
				len = item['input'],
				help = {
					token = "SLIMBROWSER_SEARCH_HELP",
				},
			}
		else
			inputSpec = item["input"]
		end
		
		-- make sure it's a number for the comparison below
		-- Lua insists on checking type while Perl couldn't care less :(
		inputSpec.len = tonumber(inputSpec.len)
		
		-- default allowedChars
		if not inputSpec.allowedChars then
			inputSpec.allowedChars = _string("ALLOWEDCHARS_CAPS")
		end
		local v = ""
		local initialText = _safeDeref(item, 'input', 'initialText')
                local inputStyle  = _safeDeref(item, 'input', '_inputStyle')
		if initialText then
			v = tostring(initialText)
			if inputStyle == 'time' then
				local _v = DateTime:timeFromSFM(v)
				v = Textinput.timeValue(_v)
			end
		else 
			if inputStyle == 'time' then
				v = Textinput.timeValue("00:00")
			end
		end

		-- create a text input
		local input = Textinput(
			"textinput", 
			v,
			function(_, value)
				-- check for min number of chars
				if #value < inputSpec.len then
					return false
				end

				
				log:debug("Input: " , value)
				_lastInput = value
				item['_inputDone'] = value
				
				-- now we should perform the action !
				_actionHandler(nil, nil, db, nil, nil, 'go', item)
				-- close the text input if this is a "do"
				local doAction = _safeDeref(item, 'actions', 'do')
				if doAction then
					-- close the window
					window:playSound("WINDOWHIDE")
					window:hide()
				end
				return true
			end,
			inputSpec.allowedChars
		)

		-- fix up help
		local helpText
		if inputSpec.help then
			local help = inputSpec.help
			helpText = help.text
			if not helpText then
				if help.token then
					helpText = _string(help.token)
				end
			end
		end
		
		local softButtons = { inputSpec.softbutton1, inputSpec.softbutton2 }
		local helpStyle = 'help'

		if softButtons[1] or softButtons[2] then
			helpStyle = 'softHelp'
		end

		if helpText then
			local help = Textarea(helpStyle, helpText)
			window:addWidget(help)
		end

		if softButtons[1] then
			window:addWidget(Label("softButton1", softButtons[1]))
		end
		if softButtons[2] then
			window:addWidget(Label("softButton2", softButtons[2]))
		end
		
		window:addWidget(input)

	-- special case for sending over textArea
	elseif item and item['textArea'] then
		local textArea = Textarea("textarea", item['textArea'])
		window:addWidget(textArea)
	else
	
		-- create a cozy place for our items...
		-- a db above
	
		-- a menu. We manage closing ourselves to guide our path
		menu = Menu(windowSpec.menuStyle, _browseMenuRenderer, _browseMenuListener)
		
		-- alltogether now
		menu:setItems(db:menuItems())
		window:addWidget(menu)
	
	end
	
	
	-- a step for our enlightenment path
	local step = {
		origin          = origin,   -- origin step
		destination     = false,    -- destination step
		window          = window,   -- step window
		menu            = menu,     -- step menu
		db              = db,       -- step db
		sink            = false,    -- sink closure embedding this step
		data            = data,     -- data (generic)
		actionModifier  = false,    -- modifier
	}
	
	log:debug("new step: " , step)
	
	-- make sure closing our windows do keep the path alive!
	window:addListener(
		EVENT_WINDOW_POP,
		function(evt)
			-- clear it if present, so we can start again the textinput
			if item then
				item['_inputDone'] = nil
			end

			-- cancel the step to prevent new data being loaded
			step.cancelled = true

			if _curStep and _curStep.origin then
				_curStep = _curStep.origin
			end
		end
	)
		
	-- manage sink
	local stepSink = _getStepSink(step, sink)
	step.sink = stepSink
	
	return step, stepSink
end


local function _installPlayerKeyHandler()
	if _playerKeyHandler then
		return
	end

	_playerKeyHandler = Framework:addListener(
		EVENT_KEY_DOWN | EVENT_KEY_PRESS | EVENT_KEY_HOLD,
		function(event)
			local type = event:getType()

			local actionName = _keycodeActionName[event:getKeycode()]
			if not actionName then
				return EVENT_UNUSED
			end

			if type == EVENT_KEY_DOWN then
				actionName = actionName .. "-down"
			elseif type == EVENT_KEY_HOLD then
				actionName = actionName .. "-hold"
			end

			local func = _globalActions[actionName]

			if not func then
				return EVENT_UNUSED
			end

			-- call the action
			func()
			return EVENT_CONSUME
		end,
		false
	)
end


local function _removePlayerKeyHandler()
	if not _playerKeyHandler then
		return
	end

	Framework:removeListener(_playerKeyHandler)
	_playerKeyHandler = false
end


--==============================================================================
-- SlimBrowserApplet public methods
--==============================================================================


-- notify_playerPower
-- we refresh the main menu after playerPower changes
function notify_playerPower(self, player, power)
	log:debug("SlimBrowserApplet:notify_playerPower(", player, ")")
	-- only if this concerns our player
	if _player == player then
		-- refresh the main menu
		for id, v in pairs(_playerMenus) do
			jiveMain:addItem(v)
		end
	end
end

-- notify_playerNewName
-- this is called when the player name changes
-- we update our main window title
function notify_playerNewName(self, player, newName)
	log:debug("SlimBrowserApplet:notify_playerNewName(", player, ",", newName, ")")

	-- if this concerns our player
	if _player == player then
		jiveMain:setTitle(newName)
	end
end


-- notify_playerDelete
-- this is called when the player disappears
function notify_playerDelete(self, player)
	log:debug("SlimBrowserApplet:notify_playerDelete(", player, ")")

	-- if this concerns our player
	if _player == player then
		-- panic!
		log:warn("Player gone while browsing it ! -- packing home!")
		self:free()
	end
end


-- notify_playerCurrent
-- this is called when the current player changes (possibly from no player)
function notify_playerCurrent(self, player)
	log:debug("SlimBrowserApplet:notify_playerCurrent(", player, ")")

	-- has the player actually changed?
	if _player == player then
		return
	end

	-- free current player
	if _player then
		self:free()
	end

	-- nothing to do if we don't have a player
	if not player then
		return
	end
	
	-- assign our locals
	_player = player
	_server = player:getSlimServer()
	_string = function(token) return self:string(token) end


	log:warn('**** SUBSCRIBING to /slim/menustatus/', _player.id)
	local cmd = { 'menustatus' }
	_server.comet:subscribe(
		'/slim/menustatus/' .. _player.id,
		_menuSink(sink, cmd),
		_player.id,
		cmd
	)

	-- create a window for Now Playing, this is our _statusStep
	local step, sink = _newDestination(
		nil,
		nil,
		_newWindowSpec(
			nil, 
			{
				text = _string("SLIMBROWSER_NOW_PLAYING"),
				window = { 
					["menuStyle"] = "album", 
				}
			}
		),
		_statusSink
	)
	_statusStep = step
	
	-- make sure it has our modifier (so that we use different default action in Now Playing)
	_statusStep.actionModifier = "-status"
	
	-- showtime for the player
	_player:onStage(sink)
	jiveMain:setTitle(player:getName())

	_server:request(sink, _player.id, { 'menu', 0, 100 })

	_installPlayerKeyHandler()
end

function notify_serverConnected(self, server)
	if _server ~= server then
		return
	end

	iconbar:setServerError("OK")

	-- hide connection error window
	if self.serverErrorWindow then
		self.serverErrorWindow:hide(Window.transitionNone)
		self.serverErrorWindow = false
	end
end


function notify_serverDisconnected(self, server, numPendingRequests)
	if _server ~= server then
		return
	end

	iconbar:setServerError("ERROR")

	if numPendingRequests == 0 then
		return
	end

	-- open connection error window
	local window = Window("window", self:string("SLIMBROWSER_PROBLEM_CONNECTING"), 'settingstitle')

	local menu = SimpleMenu("menu")

	menu:addItem({
			     text = self:string("SLIMBROWSER_TRY_AGAIN"),
			     callback = function()
						server:connect()
					end,
		     })

	--[[ XXXX to do
	menu:addItem({
			     text = self:string("SLIMBROWSER_CHOOSE_MUSIC_SOURCE"),
			     callback = function()
					end,
		     })
	--]]
	--[[ XXXX to do
	menu:addItem({
			     text = self:string("SLIMBROWSER_CHOOSE_PLAYER"),
			     callback = function()
					end,
		     })
	--]]

	window:addWidget(Textarea("help", self:string("SLIMBROWSER_PROBLEM_CONNECTING_HELP", tostring(_player:getName()), tostring(_server:getName()))))
	window:addWidget(menu)

	window:show()

	self.serverErrorWindow = window
end



--[[

=head2 applets.SlimBrowser.SlimBrowserApplet:free()

Overridden to close our player.

=cut
--]]
function free(self)
	log:debug("SlimBrowserApplet:free()")

	-- unsubscribe from this player's menustatus
	log:warn("***** UNSUBSCRIBING FROM /slim/menustatus/", _player.id)
	_server.comet:unsubscribe('/slim/menustatus/' .. _player.id)

	_player:offStage()

	_removePlayerKeyHandler()

	-- remove player menus
	jiveMain:setTitle(nil)
	for id, v in pairs(_playerMenus) do
		jiveMain:removeItem(v)
	end

	_player = false
	_server = false
	_string = false

	-- walk down our path and close...
	local step = _curStep
	
	while step do
		step.window:hide()
		step = step.origin
	end
	
	local step = _statusStep
	
	while step do
		step.window:hide()
		step = step.origin
	end
	
	return true
end


--[[

=head2 applets.SlimBrowser.SlimBrowserApplet:init()

Overridden to subscribe to events about players

=cut
--]]
function init(self)
	jnt:subscribe(self)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

