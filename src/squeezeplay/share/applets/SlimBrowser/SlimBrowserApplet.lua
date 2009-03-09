
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
local math                   = require("math")
local table                  = require("jive.utils.table")
local string                 = require("string")
                             
local Applet                 = require("jive.Applet")
local Player                 = require("jive.slim.Player")
local SlimServer             = require("jive.slim.SlimServer")
local Framework              = require("jive.ui.Framework")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")
local Group                  = require("jive.ui.Group")
local Event                  = require("jive.ui.Event")
local Menu                   = require("jive.ui.Menu")
local Label                  = require("jive.ui.Label")
local Icon                   = require("jive.ui.Icon")
local Choice                 = require("jive.ui.Choice")
local Slider                 = require("jive.ui.Slider")
local Timer                  = require("jive.ui.Timer")
local Textinput              = require("jive.ui.Textinput")
local Keyboard               = require("jive.ui.Keyboard")
local Textarea               = require("jive.ui.Textarea")
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Checkbox               = require("jive.ui.Checkbox")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Button                 = require("jive.ui.Button")
local DateTime               = require("jive.utils.datetime")

local DB                     = require("applets.SlimBrowser.DB")
local Volume                 = require("applets.SlimBrowser.Volume")
local Scanner                = require("applets.SlimBrowser.Scanner")

local debug                  = require("jive.utils.debug")

local log                    = require("jive.utils.log").logger("player.browse")
local logd                   = require("jive.utils.log").logger("player.browse.data")

local jiveMain               = jiveMain
local appletManager          = appletManager
local iconbar                = iconbar
local jnt                    = jnt


module(..., Framework.constants)
oo.class(_M, Applet)


--==============================================================================
-- Global "constants"
--==============================================================================

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
local _emptyStep = false

local _lockedItem = false

-- Our main menu/handlers
local _playerMenus = {}
local _playerKeyHandler = false

-- The last entered text
local _lastInput = ""

-- connectingToPlayer and _upgradingPlayer popup handlers
local _connectingPopup = false
local _updatingPlayerPopup = false
local _userUpdatePopup = false
local _menuReceived = false

local modeTokens = {	
			play  = "SLIMBROWSER_PLAYLIST",
			pause = "SLIMBROWSER_PAUSED", 
			stop  = "SLIMBROWSER_STOPPED",
			off   = "SLIMBROWSER_OFF"
}

-- legacy map of menuStyles to windowStyles
-- this allows SlimBrowser to make an educated guess at window style when one is not sent but a menu style is
local menu2window = {
	album = 'icon_list',
}
-- legacy map of item styles to new item style names
local styleMap = {
	itemplay = 'item_play',
	itemadd  = 'item_add',
	itemNoAction = 'item_no_arrow',
	albumitem = 'item',
	albumitemplay = 'item_play',
}
-- legacy map of item id/nodes
local itemMap = {
	-- nodes
	myMusic = { "_myMusic", "hidden" },
	music_services = { "_music_services", "hidden" },
	music_stores = { "_music_stores", "hidden" },

	-- items
	opmlrhapsodydirect = { "opmlrhapsodydirect", "home", 30 },
	opmlpandora = { "opmlpandora", "home", 30 },
	opmlsirius = { "opmlsirius", "home", 30 },
}
-- legacy map of items for "app guide"
local guideMap = {
	opmlamazon = true,
	opmlclassical = true,
	opmllma = true,
	opmllfm = true,
	opmlmp3tunes = true,
	opmlmediafly = true,
	opmlnapster = true,
	opmlpandora = true,
	podcast = true,
	opmlrhapsodydirect = true,
	opmlslacker = true,
	opmlsounds = true,
	opmlmusic = true,
	opmlsirius = true,
	opmlradioio = true,
}


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

-- turns a jsonAction table into a string that can be saved for a browseHistory key
local function _stringifyJsonRequest(jsonAction)

	if not jsonAction then
		return nil
	end

	local command = {}

	-- jsonActions can be uniquely identified by the cmd and params components
	if jsonAction.cmd then
		for i, v in ipairs(jsonAction.cmd) do
			command[#command + 1] = ' ' .. v
		end
	end
	if jsonAction.params then
		local sortedParams = table.sort(jsonAction.params)
		for k in table.pairsByKeys (jsonAction.params) do
			command[#command + 1] = ' ' .. k .. ":" .. jsonAction.params[k]
		end
	end

	return table.concat(command)
end

local function _getNewStartValue(index)
	-- start with the first item if we have no history
	if not index then
		return 0
	end
	local BLOCK_SIZE = DB:getBlockSize()

	-- if we have history, we want what is going to be the selected item to be included in the first chunk requested
	return math.floor(index/BLOCK_SIZE) * BLOCK_SIZE
end


-- _decideFirstChunk
-- figures out the from values for performJSONAction, including logic for finding the previous browse index in this list
local function _decideFirstChunk(db, jsonAction)
	local qty           = DB:getBlockSize()
	local commandString = _stringifyJsonRequest(jsonAction)
	local lastBrowse    = _player:getLastBrowse(commandString)

	if not lastBrowse then
		_player.menuAnchor = nil
	end

	local from = 0

	log:debug('Saving this json command to browse history table:')
	log:debug(commandString)

	if lastBrowse then
		from = _getNewStartValue(lastBrowse.index)
		_player.menuAnchor = lastBrowse.index 
	else
		lastBrowse = { index = 1 }
		_player:setLastBrowse(commandString, lastBrowse)
	end

	log:debug('We\'ve been here before, lastBrowse index was: ', lastBrowse.index)
	_player.lastKeyTable = lastBrowse
	
	return from, qty

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


local function _pushToNewWindow(step)
	if not step then
		return
	end

	if _curStep and _curStep.menu then
		_curStep.menu:lock(
			function()
				step.cancelled = true
			end)
	end
	step.loaded = function()
		if _curStep and _curStep.menu then
			_curStep.menu:unlock()
		end
		_curStep = step
		step.window:show()
      	end
end

-- _newWindowSpec
-- returns a Window spec based on the concatenation of base and item
-- window definition
local function _newWindowSpec(db, item)
	log:debug("_newWindowSpec()")
	
	local bWindow
	local iWindow = _safeDeref(item, 'window')

	if db then
		bWindow = _safeDeref(db:chunk(), 'base', 'window')
	end
	
	local help = _safeDeref(item, 'window', 'help', 'text')

	-- determine style
	local menuStyle = _priorityAssign('menuStyle', "", iWindow, bWindow)
log:warn('Menu:   ', menuStyle)
	local windowStyle = (iWindow and iWindow['windowStyle']) or menu2window[menuStyle] or 'text_list'
log:warn('Window: ', windowStyle)

	return {
		["windowStyle"]      = windowStyle,
		["labelTitleStyle"]  = 'title',
		["menuStyle"]        = "menu",
		["labelItemStyle"]   = "item",
		['help']             = help,
		["text"]             = _priorityAssign('text',       item["text"],    iWindow, bWindow),
		["icon-id"]          = _priorityAssign('icon-id',    item["icon-id"], iWindow, bWindow),
		["icon"]             = _priorityAssign('icon',       item["icon"],    iWindow, bWindow),
	} 

end


-- _artworkItem
-- updates a group widget with the artwork for item
local function _artworkItem(item, group, menuAccel)
	local icon = group and group:getWidget("icon")
	local iconSize

	local THUMB_SIZE = jiveMain:getSkinParam("THUMB_SIZE")
	iconSize = THUMB_SIZE

	if item["icon-id"] then
		if menuAccel and not _server:artworkThumbCached(item["icon-id"], iconSize) then
			-- Don't load artwork while accelerated
			_server:cancelArtwork(icon)
		else
			-- Fetch an image from SlimServer
			_server:fetchArtworkThumb(item["icon-id"], icon, iconSize)
		end

	elseif item["icon"] then
		if menuAccel and not _server:artworkThumbCached(item["icon"], iconSize) then
			-- Don't load artwork while accelerated
			_server:cancelArtwork(icon)
		else
			-- Fetch a remote image URL, sized to iconSize x iconSize (artwork from a streamed source)
			_server:fetchArtworkURL(item["icon"], icon, iconSize)
		end
	elseif item["trackType"] == 'radio' and item["params"] and item["params"]["track_id"] then
		if menuAccel and not _server:artworkThumbCached(item["params"]["track_id"], iconSize) then
			-- Don't load artwork while accelerated
			_server:cancelArtwork(icon)
               	else
			-- workaround: this needs to be png not jpg to allow for transparencies
			_server:fetchArtworkThumb(item["params"]["track_id"], icon, iconSize, 'png')
		end
	else
		_server:cancelArtwork(icon)

	end
end

-- _getTimeFormat
-- loads SetupDateTime and returns current setting for date time format
local function _getTimeFormat()
	local SetupDateTimeSettings = appletManager:callService("setupDateTimeSettings")
	local format = '12'
	if SetupDateTimeSettings and SetupDateTimeSettings['hours'] then
		format = SetupDateTimeSettings['hours']
	end
	return format
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
					log:warn("ON: ", checkboxFlag)
					_actionHandler(nil, nil, db, nil, nil, 'on', item) 
				else
					log:warn("OFF: ", checkboxFlag)
					_actionHandler(nil, nil, db, nil, nil, 'off', item) 
				end
			end,
			checkboxFlag == 1
		)
	end
	return item["_jive_button"]
end

-- _choiceItem
-- returns a choice set for use on a given item
local function _choiceItem(item, db)
	local choiceFlag = tonumber(item["selectedIndex"])
	local choiceActions = _safeDeref(item, 'actions', 'do', 'choices')

	if choiceFlag and choiceActions and not item["_jive_button"] then
		item["_jive_button"] = Choice(
			"choice",
			item['choiceStrings'],
			function(_, index) 
				log:info('Callback has been called: ', index) 
				_actionHandler(nil, nil, db, nil, nil, 'do', item, index) 
			end,
			choiceFlag
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
				log:info('Callback has been called') 
				_actionHandler(nil, nil, db, nil, nil, 'do', item) 
			end,
			radioFlag == 1
		)
	end
	return item["_jive_button"]
end


-- _decoratedLabel
-- updates or generates a label cum decoration in the given labelStyle
local function _decoratedLabel(group, labelStyle, item, db, menuAccel)
	-- if item is a windowSpec, then the icon is kept in the spec for nothing (overhead)
	-- however it guarantees the icon in the title is not shared with (the same) icon in the menu.
	local showIcons = true
	if db:windowStyle() == 'text_list' then
		showIcons = false
	end
	if not group then
		if labelStyle == 'title' then
			group = Group(labelStyle, { 
				text = Label("text", ""), 
				icon = Icon("icon"), 
				lbutton = Button(
					Icon("button_back"), 
					function()
						Framework:pushAction("back")
	
						return EVENT_CONSUME
					end,
					function()
						Framework:pushAction("go_home")
						return EVENT_CONSUME
					end
				), 
				rbutton = Button(
					Icon("button_go_now_playing"), 
					function() 
						Framework:pushAction("go_now_playing")
						return EVENT_CONSUME 
					end
				), 
				xofy = Label('xofy', ''),
			})
		else
			group = Group(labelStyle, { 
				icon = Icon("icon"), 
				text = Label("text", ""), 
				arrow = Icon('arrow'),
				check = Icon('check'),
			})
		end
	end

	if item then
		group:setWidgetValue("text", item.text)
		if showIcons then
			group:setWidget('icon', Icon('icon_no_artwork'))
		end

		-- set an acceleration key, but not for playlists
		if item.params and item.params.textkey then
			-- FIXME the, el, la, etc articles
			group:setAccelKey(item.params.textkey)
		end

		if item["radio"] then
			group._type = "radio"
			group:setWidget("icon", _radioItem(item, db))

		elseif item["checkbox"] then
			group._type = "checkbox"
			group:setWidget("icon", _checkboxItem(item, db))

		elseif item['selectedIndex'] then
			group._type = 'choice'
			group:setWidget('icon', _choiceItem(item, db))

		else
			if group._type then
				if showIcons then
					group:setWidget("icon", Icon("icon_no_artwork"))
				end
				group._type = nil
			end
			_artworkItem(item, group, menuAccel)
		end
		group:setStyle(labelStyle)

	else
		if group._type then
			if showIcons then
				group:setWidget("icon", Icon("icon_no_artwork"))
			end
			group._type = nil
		end

		group:setWidgetValue("text", "")
		group:setStyle(labelStyle .. "waiting_popup")
	end

	return group
end


-- _performJSONAction
-- performs the JSON action...
local function _performJSONAction(jsonAction, from, qty, step, sink)
	log:debug("_performJSONAction(from:", from, ", qty:", qty, "):")

	local cmdArray = jsonAction["cmd"]
	
	-- sanity check
	if not cmdArray or type(cmdArray) != 'table' then
		log:error("JSON action for ", actionName, " has no cmd or not of type table")
		return
	end
	
	-- replace player if needed
	local playerid = jsonAction["player"]
	if not playerid or tostring(playerid) == "0" then
		playerid = _player:getId()
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

	if step then
		step.jsonAction = request
	end

	-- send the command
	_server:userRequest(sink, playerid, request)
end

-- for a given step, rerun the json request that created that slimbrowser menu
local function _refreshJSONAction(step)
	if not _player then
		return
	end

	if not step.jsonAction then
		log:warn('No jsonAction request defined for this step')
		return
	end

	local playerid = _player:getId()
	if not playerid then
		log:warn('no player!')
		return
	end

	_server:userRequest(step.sink, playerid, step.jsonAction)

end

-- _getStepSink
-- returns a closure to a sink embedding step
local function _getStepSink(step, sink)
	return function(chunk, err)
		sink(step, chunk, err)
	end
end

-- _inputInProgress
-- full screen popup that appears until action from text input is complete
local function _inputInProgress(self, msg)
	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	if msg then
		local label = Label("text", msg)
		popup:addWidget(label)
	end
	popup:show()
end

-- _hideUserUpdatePopup
-- hide the full screen popup that appears until player is updated
local function _hideUserUpdatePopup()
	if _userUpdatePopup then
		log:info("_userUpdatePopup popup hide")
		_userUpdatePopup:hide()
		_userUpdatePopup = false
	end
end


-- _hidePlayerUpdating
-- hide the full screen popup that appears until player is updated
local function _hidePlayerUpdating()
	if _updatingPlayerPopup then
		log:info("_updatingPlayer popup hide")
		_updatingPlayerPopup:hide()
		_updatingPlayerPopup = false
	end
end


-- _connectingToPlayer
-- full screen popup that appears until menus are loaded
local function _connectingToPlayer(self)
	log:info("_connectingToPlayer popup show")

	if _connectingPopup or _userUpdatePopup or _updatingPlayerPopup then
		-- don't open this popup twice or when firmware update windows are on screen
		return
	end

	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	local playerName = _player:getName()
	local label = Label("text", self:string("SLIMBROWSER_CONNECTING_TO", playerName))
	popup:addWidget(icon)
	popup:addWidget(label)
	popup:setAlwaysOnTop(true)

	-- add a listener for KEY_PRESS that disconnects from the player and returns to home
	local disconnectPlayer = function()
		appletManager:callService("setCurrentPlayer", nil)
		popup:hide()
	end

	popup:addActionListener("back", self, disconnectPlayer)
		
	popup:show()

	_connectingPopup = popup
end

-- _userTriggeredUpdate
-- full screen popup that appears until user hits brightness on player to start upgrade
local function _userTriggeredUpdate(self)
	log:warn("_connectingToPlayer popup show")


	if _userUpdatePopup then
		return
	end


	-- only show this window if the player has a brightness button available
	local playerModel = _player:getModel()
	if playerModel == 'receiver' 
		or playerModel == 'softsqueeze'
		or playerModel == 'softsqueeze3'
		or playerModel == 'controller'
		or playerModel == 'squeezeplay'
		or playerModel == 'squeezeslave'
		then
			return
	end

	local window = Window("text_list", self:string('SLIMBROWSER_PLAYER_UPDATE_REQUIRED'))
	local label = Textarea("text", self:string('SLIMBROWSER_USER_UPDATE_FIRMWARE_SQUEEZEBOX', _player:getName()))
	window:addWidget(label)
	window:setAlwaysOnTop(true)
	window:setAllowScreensaver(false)

	-- add a listener for KEY_HOLD that disconnects from the player and returns to home
	local disconnectPlayer = function()
		appletManager:callService("setCurrentPlayer", nil)
		window:hide()
	end

	window:addActionListener("back", self, disconnectPlayer)

	window:show()

	_userUpdatePopup = window
end


-- _updatingPlayer
-- full screen popup that appears until menus are loaded
local function _updatingPlayer(self)
	log:warn("_connectingToPlayer popup show")

	if _userUpdatePopup then
		_hideUserUpdatePopup()
	end

	if _updatingPlayerPopup then
		-- don't open this popup twice
		return
	end

	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	local label = Label("text", self:string('SLIMBROWSER_UPDATING_FIRMWARE_SQUEEZEBOX', _player:getName()))
	popup:addWidget(icon)
	popup:addWidget(label)
	popup:setAlwaysOnTop(true)

	-- add a listener for KEY_PRESS that disconnects from the player and returns to home
	local disconnectPlayer = function()
		appletManager:callService("setCurrentPlayer", nil)
		popup:hide()
	end

	popup:addActionListener("back", self, disconnectPlayer)

	popup:show()

	_updatingPlayerPopup = popup
end

-- _renderTextArea
-- special case when single SlimBrowse item is a textarea
local function _renderTextArea(step, item)

	if not step and step.window then
		return
	end
	_assert(item)
	_assert(item.textArea)

	local textArea = Textarea("text", item.textArea)
	step.window:addWidget(textArea)

end


-- _renderSlider
-- special case when SlimBrowse item is configured for a slider widget
local function _renderSlider(step, item)

	if not step and step.window then
		return
	end
	_assert(item)
	_assert(item.min)
	_assert(item.max)
	_assert(item.actions['do'])

	if not item.adjust then
		item.adjust = 0
	end

	local sliderInitial
	if not item.initial then
		sliderInitial = item.min + item.adjust
	else
		sliderInitial = item.initial + item.adjust
	end

	local sliderMin = tonumber(item.min) + tonumber(item.adjust)
	local sliderMax = tonumber(item.max) + tonumber(item.adjust)

	local slider = Slider("slider", sliderMin, sliderMax, sliderInitial,
                function(slider, value, done)
			local jsonAction = item.actions['do']
			local valtag = _safeDeref(item, 'actions', 'do', 'params', 'valtag')
			if valtag then
				item.actions['do'].params[valtag] = value - item.adjust
			end
			_performJSONAction(jsonAction, nil, nil, nil, nil)

                        if done then
                                window:playSound("WINDOWSHOW")
                                window:hide(Window.transitionPushLeft)
                        end
                end)
	local help, text
	if item.text then
		text = Textarea("text", item.text)
		step.window:addWidget(text)
	end
	if item.help then
        	help = Textarea("help_text", item.help)
		step.window:addWidget(help)
	end

	if item.sliderIcons == 'none' then
        	step.window:addWidget(slider)
	elseif item.sliderIcons == 'volume' then
		step.window:addWidget(Group("slider_group", {
			min = Icon("button_volume_min"),
			slider = slider,
			max = Icon("button_volume_max")
		}))
	else
		step.window:addWidget(Group("slider_group", {
			min = Icon("button_slider_min"),
			slider = slider,
			max = Icon("button_slider_max")
		}))
	end



end

-- _bigArtworkPopup
-- special case sink that pops up big artwork
local function _bigArtworkPopup(chunk, err)

	log:debug("Rendering artwork")
	local popup = Popup("image_popup")
	popup:setAllowScreensaver(true)

	local icon = Icon("image")

	local screenW, screenH = Framework:getScreenSize()
	local shortDimension = screenW
	if screenW > screenH then
		shortDimension = screenH
	end

	log:debug("Artwork width/height will be ", shortDimension)
	if chunk.data and chunk.data.artworkId then
		_server:fetchArtworkThumb(chunk.data.artworkId, icon, shortDimension)
	elseif chunk.data and chunk.data.artworkUrl then
		_server:fetchArtworkURL(chunk.data.artworkUrl, icon, shortDimension)
	end
	popup:addWidget(icon)
	popup:show()
	return popup
end

local function _refreshMe(step)
	if step then
		local timer = Timer(100,
			function()
				_refreshJSONAction(step)
			end, true)
		timer:start()
	end

end

local function _refreshOrigin(step)
	if step.origin then
		local timer = Timer(100,
			function()
				_refreshJSONAction(step.origin)
			end, true)
		timer:start()
	end
end

-- _hideMeAndMyDad
-- hides the top window and the parent below it, refreshing the 'grandparent' window via a new request
local function _hideMeAndMyDad(step)
	Framework:playSound("WINDOWHIDE")
	step.window:hide()
	if step.origin then
		local parentStep = step.origin
		if parentStep.origin then
			parentStep.window:hide()
			local grandparentStep = parentStep.origin
			local timer = Timer(1000,
				function()
					_refreshJSONAction(grandparentStep)
				end, true)
			timer:start()
		end
	end
end


-- _hideMe
-- hides the top window and refreshes the parent window, via a new request
local function _hideMe(step)
	Framework:playSound("WINDOWHIDE")
	step.window:hide()
	if step.origin then
		_curStep = step.origin
		local timer = Timer(1000,
			function()
				_refreshJSONAction(_curStep)
			end, true)
		timer:start()
	end


end

-- _goNowPlaying
-- pushes next window to the NowPlaying window
local function _goNowPlaying(transition)
	if not transition then
		transition = Window.transitionPushRight
	end
	Framework:playSound("WINDOWSHOW")
	appletManager:callService('goNowPlaying', 'browse', transition)
end

-- _goPlaylist
-- pushes next window to the Playlist window
local function _goPlaylist()
	Framework:playSound("WINDOWSHOW")
	showPlaylist()
end

-- _devnull
-- sinks that silently swallows data
-- used for actions that go nowhere (play, add, etc.)
local function _devnull(chunk, err)
	log:debug('_devnull()')
	log:debug(chunk)
end

-- _goNow
-- go immediately to a particular destination
local function _goNow(destination, transition, step)
	if not transition then
		transition = Window.transitionPushRight
	end
	if destination == 'nowPlaying' then
		_goNowPlaying(transition)
	elseif destination == 'home' then
		goHome()
	elseif destination == 'playlist' then
		_goPlaylist()
	elseif destination == 'parent' and step and step.window then
		_hideMe(step)
	elseif destination == 'grandparent' and step and step.window then
		_hideMeAndMyDad(step)
	elseif destination == 'refreshOrigin' and step and step.window then
		_refreshOrigin(step)
	elseif destination == 'refresh' and step and step.window then
		_refreshMe(step)
	end
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

		if step.window and data and data.goNow then
			_goNow(data.goNow)
		end
		if data.networkerror then
			if step.menu then
				step.window:removeWidget(step.menu)
			end
			local textArea = Textarea("text", data.networkerror)
			if step.window then
				step.window:setTitle(_string("SLIMBROWSER_PROBLEM_CONNECTING"), 'settingstitle')
				step.window:addWidget(textArea)
			end
		elseif step.window and data and data.window and data.window.textArea then
			if step.menu then
				step.window:removeWidget(step.menu)
			end
			local textArea = Textarea("text", data.window.textArea)
			step.window:addWidget(textArea)
		elseif step.menu and data and data.count and data.count == 1 and data.item_loop and (data.item_loop[1].slider or data.item_loop[1].textArea) then
			-- no menus here, thankyouverymuch
			if step.menu then
				step.window:removeWidget(step.menu)
			end

			if data.item_loop[1].slider then
				_renderSlider(step, data.item_loop[1])
			else
				_renderTextArea(step, data.item_loop[1])
			end

		-- avoid infinite request loop on count == 0
		elseif step.menu and data and data.count and data.count == 0 then
			-- this will render a blank menu, which is typically undesirable 
			-- but we don't want to reach the next clause
			-- count == 0 responses should not be typical
		elseif step.menu then
			step.menu:setItems(step.db:menuItems(data))
			if _player.menuAnchor then
				step.menu:setSelectedIndex(_player.menuAnchor)
			end

			-- update the window properties
			--step.menu:setStyle(step.db:menuStyle())
			local titleBar = step.window:getTitleWidget()
			-- styling both the menu and title with icons is problematic to the layout
			if step.db:menuStyle() == 'albummenu' and titleBar:getStyle() == 'albumtitle' then
				titleBar:setWidget('icon', nil)
				step.window:setTitleStyle('title')
			end

			if not data.window and (data.base and data.base.window) then
				data.window =  data.base.window
			end
			if data.window or data.base and data.base.window then
				local windowStyle = data.window and data.window.windowStyle or 
							data.base and data.base.window and data.base.window.windowStyle
				if windowStyle then
					step.window:setStyle(data.window['windowStyle'])
				end
				-- if a titleStyle is being sent, we need to setTitleWidget completely
				if data.window.titleStyle or data.window['icon-id'] then
					local titleText, titleStyle, titleIcon
					local titleWidget = step.window:getTitleWidget()
					-- set the title text if specified
					if data.window.text then
						titleText = data.window.text
					-- otherwise default back to what's currently in the title widget
					else	
						titleText = step.window:getTitle()
						if not titleText then
							log:warn('no title found in existing title widget')
							titleText = ''
						end
					end
					if data.window.titleStyle then
						titleStyle = data.window.titleStyle .. 'title'
					else
						titleStyle = step.window:getTitleStyle()
					end
					-- add the icon if it's been specified in the window params
					if data.window['icon-id'] then
						-- Fetch an image from SlimServer
						titleIcon = Icon("icon")
						_server:fetchArtworkThumb(data.window["icon-id"], titleIcon, jiveMain:getSkinParam("THUMB_SIZE"))
					-- only allow the existing icon to stay if titleStyle isn't being changed
					elseif not data.window.titleStyle and titleWidget:getWidget('icon') then
						titleIcon = titleWidget:getWidget('icon')
					else
						titleIcon = Icon("icon")
					end

					local xofyLabel
					if titleWidget:getWidget('xofy') then
						xofyLabel = titleWidget:getWidget('xofy')
					else
						xofyLabel = Label('xofy', '')
					end
					local newTitleWidget = 
						--Group(titleStyle, { 
						Group('title', { 
							text = Label("text", titleText), 
							icon = titleIcon,
							xofy = xofyLabel,
							lbutton = Button(
								Icon("button_back"), 
								function()
									Framework:pushAction("back")

									return EVENT_CONSUME
								end,
								function()
									Framework:pushAction("go_home")
									return EVENT_CONSUME
								end
							), 
							rbutton = Button(
								Icon("button_go_now_playing"), 
								function() 
									Framework:pushAction("go_now_playing")
									return EVENT_CONSUME
								end
							), 
						})	
					step.window:setTitleWidget(newTitleWidget)
				-- change the text as specified if no titleStyle param was also sent
				elseif data.window.text then
					step.window:setTitle(data.window.text)
				end
				-- textarea data for the window
				if data.window and data.window.textarea then
					local textarea = Textarea('help_text', data.window.textarea)
					-- remove the menu
					if step.menu then
						step.window:removeWidget(step.menu)
					end
					step.window:addWidget(textarea)
					-- menu back, in thank you
					step.window:addWidget(step.menu)
				end
				-- contextual help comes from data.window.help
				if data.window and data.window.help then
					local helpWindow = function()
						local window = Window("text_list", "Help")
						window:setAllowScreensaver(false)
						local textarea = Textarea("text", data.window.help)
						window:addWidget(textarea)
						window:show()
					end
					step.window:addActionListener("help", _, helpWindow)
					step.window:setButtonAction("rbutton", "help")
				end
			end

			-- what's missing?
			local from, qty = step.db:missing(_player.menuAnchor)
		
			if from then
				_performJSONAction(step.data, from, qty, step, step.sink)
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

		log:info("_menuSink()")

		-- process data from a menu notification
		-- each chunk.data[2] contains a table that needs insertion into the menu
		local menuItems = chunk.data[2]
		-- directive for these items is in chunk.data[3]
		local menuDirective = chunk.data[3]
		-- the player ID this notification is for is in chunk.data[4]
		local playerId = chunk.data[4]

		if playerId ~= 'all' and playerId ~= _player:getId() then
			log:debug('This menu notification was not for this player')
			log:debug("Notification for: ", playerId)
			log:debug("This player is: ", _player:getId())
			return
		end

		-- if we get here, it was for this player. set menuReceived to true
		_menuReceived = true


if _menuReceived then
-- a problem, we lose the icons..
jiveMain:addNode({
  sound = "WINDOWSHOW",
  weight = 20,
  id = "radios",
  text = "Internet Radio",
  node = "home",
})
end

		for k, v in pairs(menuItems) do

			local item = {
					id = v.id,
					node = v.node,
					style = v.style,
					text = v.text,
					homeMenuText = v.homeMenuText,
					weight = v.weight,
					window = v.window,
					sound = "WINDOWSHOW",
				}

			local itemIcon = v.window  and v.window['icon-id'] or v['icon-id']
			if itemIcon then
				item["icon-id"] = itemIcon
				item.icon = Icon('icon')
				_server:fetchArtworkThumb(item["icon-id"], item.icon, jiveMain:getSkinParam('THUMB_SIZE'))
			end

			-- hack to modify styles from SC
			if item.style and styleMap[item.style] then
				item.style = styleMap[item.style]
			end
			local choiceAction = _safeDeref(v, 'actions', 'do', 'choices')

			-- hack to modify menu structure from SC
			if guideMap[item.id] then
				item.guide = true
				item.node = "appguide"
				item.weight = 30
			end
			if itemMap[item.id] then
				local id = item.id
				item.id = itemMap[id][1]
				item.node = itemMap[id][2]
				if itemMap[id][3] then
					item.weight = itemMap[id][3]
				end
			end
			if itemMap[item.node] then
				local node = item.node
				item.node = itemMap[node][1]
			end

			-- a problem, we lose the icons..
			if item.id == "radios" then
				v.isANode = true
			end


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
						_performJSONAction(jsonAction, nil, nil, nil, nil)
					end,
					selectedIndex
				)
				
				item.style = 'item_choice'
				item.check = choice

				--add the item to the menu
				_playerMenus[item.id] = item
				jiveMain:addItem(item)

			else

				item.callback = function()
					--	local jsonAction = v.actions.go
						local jsonAction, from, qty, step, sink
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
							log:debug(v.nextWindow)
							if v.nextWindow then
								if v.nextWindow == 'home' then
									sink = goHome
								elseif v.nextWindow == 'playlist' then
									sink = _goPlaylist
								elseif v.nextWindow == 'nowPlaying' then
									sink = _goNowPlaying
								end
							else
								step, sink =_newDestination(nil,
											  v,
											  _newWindowSpec(nil, v),
											  _browseSink,
											  jsonAction
										  )
								if v.input then
									step.window:show()
									_curStep = step
								else
									from, qty = _decideFirstChunk(step.db, jsonAction)

									_lockedItem = item
									jiveMain:lockItem(item,
										  function()
										  step.cancelled = true
									  end)
		
									step.loaded = function()
										      jiveMain:unlockItem(item)
		
										      _lockedItem = false
										      _curStep = step
										      step.window:show()
									      end
								end
							end
						end

						if not v.input then
							_performJSONAction(jsonAction, from, qty, step, sink)
						end
					end

				_playerMenus[item.id] = item
				jiveMain:addItem(item)
			end
		end
		if _menuReceived then
			hideConnectingToPlayer()
		end
         end
end


-- _requestStatus
-- request the next chunk from the player status (playlist)
local function _requestStatus()
	local step = _statusStep

	local from, qty = step.db:missing()
	if from then
		-- note, this is not a userRequest as the playlist is
		-- updated when the playlist changes
		_server:request(
				step.sink,
				_player:getId(),
				{ 'status', from, qty, 'menu:menu' }
			)
	end
end


-- _statusSink
-- sink that sets the data for our status window(s)
local function _statusSink(step, chunk, err)
	log:debug("_statusSink()")
		
	-- currently we're not going anywhere with current playlist...
	_assert(step == _statusStep)

	local data = chunk.data
	if data then

		local hasSize = _safeDeref(data, 'item_loop', 1)
		if not hasSize then return end

		if logd:isDebug() then
			debug.dump(data, 8)
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
			log:debug('This is not a message suitable for the current playlist')
			return
		end

		step.menu:setItems(step.db:menuItems(data))
		_requestStatus()

	else
		log:error(err)
	end
end

-- _globalActions
-- provides a function for default button behaviour, called outside of the context of the browser
local _globalActions = {
	["rew"] = function()
	        Framework:playSound("PLAYBACK")
		_player:rew()
		return EVENT_CONSUME
	end,

	["rew-hold"] = function(self, event)
		return self.scanner:event(event)
	end,

	["fwd"] = function()
	        Framework:playSound("PLAYBACK")
		_player:fwd()
		return EVENT_CONSUME
	end,

	["fwd-hold"] = function(self, event)
		return self.scanner:event(event)
	end,

	["volup-down"] = function(self, event)
		return self.volume:event(event)
	end,

	["volup"] = function(self, event)
		return self.volume:event(event)
	end,

	["voldown-down"] = function(self, event)
		return self.volume:event(event)
	end,
	["voldown"] = function(self, event)
		return self.volume:event(event)
	end,
--[[	
	["go-hold"] = function(self, event)
		return self.scanner:event(event)
	end,
--]]
}


function _goMenuTableItem(key)
	if jiveMain:getMenuTable()[key] then
		Framework:playSound("JUMP")
		jiveMain:getMenuTable()[key].callback()
	end
end

function _goNowPlayingAction()
	_goNow('nowPlaying', Window.transitionPushLeft)
	return EVENT_CONSUME
end

function _goSearchAction()
	_goMenuTableItem("myMusicSearch")
	return EVENT_CONSUME
end

function _goMusicLibraryAction()
	_goMenuTableItem("myMusic")
	return EVENT_CONSUME
end


function _goPlaylistAction()
	_goPlaylist()
	return EVENT_CONSUME
end


function _goFavoritesAction()
	_goMenuTableItem("favorites")
	return EVENT_CONSUME
end


function _goPlaylistsAction()
	_goMenuTableItem("myMusicPlaylists")
	return EVENT_CONSUME
end


function _goRhapsodyAction()
	_goMenuTableItem("opmlrhapsodydirect")
	return EVENT_CONSUME
end


function _goRepeatToggleAction()
	_player:repeatToggle()
	return EVENT_CONSUME
end


function _goShuffleToggleAction()
	_player:shuffleToggle()
	return EVENT_CONSUME
end


function _goSleepAction()
	_player:sleepToggle()
	return EVENT_CONSUME
end


function _goPlayFavoriteAction(self, event)
	local action = event:getAction()
	local number = string.sub(action, -1 , -1)
	if not number or not string.find(number, "%d") then
		log:error("Expected last character of action string would be numeric, for action :", action)
		return EVENT_CONSUME
	end

	_player:numberHold(number)

	return EVENT_CONSUME
end


function _goCurrentTrackDetailsAction()
	--todo -get menu object, iterate through to current, select it - doh, harder than I thought for something that's not yet a requirement
--	showPlaylist()
--	Framework:pushAction( "go")
	return EVENT_CONSUME
end

-- _globalActions
-- provides a function for default button behaviour, called outside of the context of the browser
--TRANSITIONING from old _globalAction style to new system wide action event model, will rename this when old one is eliminated
--not sure yet how to deal with things like rew and vol which need up/down/press considerations
local _globalActionsNEW = {

	["go_now_playing"] = _goNowPlayingAction,
	["go_playlist"] = _goPlaylistAction,
	["go_search"] = _goSearchAction,
	["go_favorites"] = _goFavoritesAction,
	["go_playlists"] = _goPlaylistsAction,
	["go_music_library"] = _goMusicLibraryAction,
	["go_rhapsody"] = _goRhapsodyAction,
	["go_current_track_details"] = _goCurrentTrackDetailsAction,
	["repeat_toggle"] = _goRepeatToggleAction,
	["shuffle_toggle"] = _goShuffleToggleAction,
	["sleep"] = _goSleepAction,
	["play_favorite_0"] = _goPlayFavoriteAction,
	["play_favorite_1"] = _goPlayFavoriteAction,
	["play_favorite_2"] = _goPlayFavoriteAction,
	["play_favorite_3"] = _goPlayFavoriteAction,
	["play_favorite_4"] = _goPlayFavoriteAction,
	["play_favorite_5"] = _goPlayFavoriteAction,
	["play_favorite_6"] = _goPlayFavoriteAction,
	["play_favorite_7"] = _goPlayFavoriteAction,
	["play_favorite_8"] = _goPlayFavoriteAction,
	["play_favorite_9"] = _goPlayFavoriteAction,
	
	["go_home_or_now_playing"] = function()
		local windowStack = Framework.windowStack

		-- are we in home?
		if #windowStack > 1 then
			_goNow('home')
		else
			_goNow('nowPlaying', Window.transitionPushLeft)
		end

		return EVENT_CONSUME
	end,

	["go_home"] = function()
		_goNow('home')
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

	["stop"] = function()
	        Framework:playSound("PLAYBACK")
		_player:stop()
		return EVENT_CONSUME
	end,

	["volume_up"] = function(self, event)
		return self.volume:event(event)
	end,

	["volume_down"] = function(self, event)
		return self.volume:event(event)
	end,

	["jump_rew"] = function()
	        Framework:playSound("PLAYBACK")
		_player:rew()
		return EVENT_CONSUME
	end,
	["jump_fwd"] = function()
	        Framework:playSound("PLAYBACK")
		_player:fwd()
		return EVENT_CONSUME
	end,


	["scanner_rew"] = function(self, event)
		return self.scanner:event(event)
	end,

	["scanner_fwd"] = function(self, event)
		return self.scanner:event(event)
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
_actionHandler = function(menu, menuItem, db, dbIndex, event, actionName, item, selectedIndex)
	log:debug("_actionHandler(", actionName, ")")

	if logd:isDebug() then
		debug.dump(item, 4)
	end

	local choiceAction

	-- some actions work (f.e. pause) even with no item around
	if item then
		local chunk = db:chunk()
		local bAction
		local iAction
		local onAction
		local offAction
		
		-- we handle no action in the case of an item telling us not to
		if item['action'] == 'none' then
			return EVENT_UNUSED
		end

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

		choiceAction = _safeDeref(item, 'actions', 'do', 'choices')
		
		-- now check for a run-of-the mill action
		if not (iAction or bAction or onAction or offAction or choiceAction) then
			bAction = _safeDeref(chunk, 'base', 'actions', actionName)
			iAction = _safeDeref(item, 'actions', actionName)
		else
			-- if we reach here, it's a DO action...
			-- okay to call on or off this, as they are just special cases of 'do'
			actionName = 'do'
		end
		
		-- XXX: Fred: After an input box is used, chunk is nil, so base can't be used
	
		if iAction or bAction or choiceAction then
			-- the resulting action, if any
			local jsonAction
	
			-- special case, handling a choice item action
			if choiceAction and selectedIndex then
				jsonAction = _safeDeref(item, 'actions', actionName, 'choices', selectedIndex)
			-- process an item action first
			elseif iAction then
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
				local from, qty
				-- cover all our "special cases" first, custom navigation, artwork popup, etc.
				if item['nextWindow'] == 'nowPlaying' then
					sink = _goNowPlaying
				elseif item['nextWindow'] == 'playlist' then
					sink = _goPlaylist
				elseif item['nextWindow'] == 'home' then
					sink = goHome
				elseif item['nextWindow'] == 'parent' then
					sink = _hideMe(_curStep)
				elseif item['nextWindow'] == 'grandparent' then
					sink = _hideMeAndMyDad(_curStep)
				elseif item['nextWindow'] == 'refreshOrigin' then
					sink = _refreshOrigin(_curStep)
				elseif item['nextWindow'] == 'refresh' then
					sink = _refreshMe(_curStep)
				elseif item["showBigArtwork"] then
					sink = _bigArtworkPopup
				elseif actionName == 'go' 
					-- when we want play or add action to do the same thing as 'go', and give us a new window
					or ( item['playAction'] == 'go' and actionName == 'play' ) 
					or ( item['playHoldAction'] == 'go' and actionName == 'play-hold' ) 
					or ( item['addAction'] == 'go' and actionName == 'add' ) then
					step, sink = _newDestination(_curStep, item, _newWindowSpec(db, item), _browseSink, jsonAction)
					if step.menu then
						from, qty = _decideFirstChunk(step.db, jsonAction)
					end
				end

				_pushToNewWindow(step)
			
				-- send the command
				 _performJSONAction(jsonAction, from, qty, step, sink)
			
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



-- map from a key to an actionName
local _keycodeActionName = {
	[KEY_VOLUME_UP] = 'volup', 
	[KEY_VOLUME_DOWN] = 'voldown', 
	[KEY_FWD]   = 'fwd',
	[KEY_REW]   = 'rew',
}

-- map from a key to an actionName
local _actionToActionName = {
	["go_home_or_now_playing"] = 'home',
	["pause"]   = 'pause',
	["stop"]   = 'pause-hold',
	["play"]    = 'play',
	["custom_mix"]    = 'play-hold',
	["add"]     = 'add',
	["add_next"]     = 'add-hold',
	["go"]      = 'go',
	["go_hold"]      = 'go-hold',

}

-- internal actionNames:
--				  'inputDone'

-- _browseMenuListener
-- called 
local function _browseMenuListener(menu, db, menuItem, dbIndex, event)
	log:debug("_browseMenuListener(", event:tostring(), ", " , index, ")")
	

	-- ok so joe did press a key while in our menu...
	-- figure out the item action...
	local evtType = event:getType()

	local currentlySelectedIndex = _curStep.menu:getSelectedIndex()
	if _player.lastKeyTable and evtType == EVENT_FOCUS_GAINED then
		if currentlySelectedIndex then
			_player.lastKeyTable.index = currentlySelectedIndex 
		else
			_player.lastKeyTable.index = 1
		end
	end


	-- we don't care about focus: we get one everytime we change current item
	-- and it just pollutes our logging.
	if evtType == EVENT_FOCUS_GAINED
		or evtType == EVENT_FOCUS_LOST
		or evtType == EVENT_HIDE
		or evtType == EVENT_SHOW then
		return EVENT_UNUSED
	end

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
	if item and item["_jive_button"] then
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

	elseif evtType == ACTION then
		log:debug("_browseMenuListener: ACTION")
		local action = event:getAction()
		local actionName = _actionToActionName[action]

		if actionName then
			return _actionHandler(menu, menuItem, db, dbIndex, event, actionName, item)
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
local function _browseMenuRenderer(menu, db, widgets, toRenderIndexes, toRenderSize)
	--	log:debug("_browseMenuRenderer(", toRenderSize, ", ", db, ")")
	-- we must create or update the widgets for the indexes in toRenderIndexes.
	-- this last list can contain null, so we iterate from 1 to toRenderSize

	local labelItemStyle = db:labelItemStyle()
	
	local menuAccel, dir = menu:isAccelerated()
	if menuAccel then
		_server:cancelAllArtwork()
	end

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

			if style == 'item' then
				local chunk = db:chunk()
			end
			
			if current then
				style = "albumcurrent"
			elseif item and item["style"] then
				style = item["style"]
			end

			-- support legacy styles for play and add
			if styleMap[style] then
				style = styleMap[style]
			end
			if item['checkbox'] or item['radio'] or item['selectedIndex'] then
				style = 'item_choice'
			end
			widgets[widgetIndex] = _decoratedLabel(widget, style, item, db, menuAccel)
		end
	end

	if menuAccel or toRenderSize == 0 then
		return
	end

	-- preload artwork in the direction of scrolling
	-- FIXME wrap around cases
	local startIndex
	if dir > 0 then
		startIndex = toRenderIndexes[toRenderSize]
	else
		startIndex = toRenderIndexes[1] - toRenderSize
	end

	for dbIndex = startIndex, startIndex + toRenderSize do
		local item = db:item(dbIndex)
		if item then
			_artworkItem(item, nil, false)
		end
	end
end


-- _browseMenuAvailable
-- renders a basic menu
local function _browseMenuAvailable(menu, db, dbIndex, dbVisible)
	-- check range
	local minIndex = math.max(1, dbIndex)
	local maxIndex = math.min(dbIndex + dbVisible, db:size())

	-- only check first and last item, this assumes that the middle
	-- items are available
	return (db:item(minIndex) ~= nil) and (db:item(maxIndex) ~= nil)
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
	local window = Window(windowSpec.windowStyle or 'text_list')
	window:setTitleWidget(_decoratedLabel(nil, 'title', windowSpec, db, false))
	
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
			if inputSpec._kbType == 'qwertyLower' then
				inputSpec.allowedChars = _string("ALLOWEDCHARS_WITHCAPS")
			else
				inputSpec.allowedChars = _string("ALLOWEDCHARS_CAPS")
			end
		end
		local v = ""
		local initialText = _safeDeref(item, 'input', 'initialText')
                local inputStyle  = _safeDeref(item, 'input', '_inputStyle')

		if initialText then
			v = tostring(initialText)
		end

		if inputStyle == 'time' then
			if not initialText then
				initialText = '0'
			end
			local timeFormat = _getTimeFormat()
			local _v = DateTime:timeFromSFM(v, timeFormat)
			v = Textinput.timeValue(_v, timeFormat)
		elseif inputStyle == 'ip' then
			if not initialText then
				initialText = '0.0.0.0'
			end
			v = Textinput.ipAddressValue(initialText)
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
				
				-- popup time
				local displayPopup = _safeDeref(item, 'input', 'processingPopup')
				local displayPopupText = _safeDeref(item, 'input', 'processingPopup', 'text')
				if displayPopup then
					_inputInProgress(self, displayPopupText)
				end
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

		--[[ FIXME: removing help (all platforms) for purposes of Fab4.
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
		--]]
		
		local kbType = inputSpec._kbType or 'qwerty'
		local keyboard = Keyboard("keyboard", kbType)
		local backspace = Button(
			Icon('button_keyboard_back'),
			function()
				local e = Event:new(EVENT_CHAR_PRESS, string.byte("\b"))
				Framework:dispatchEvent(nil, e)
				return EVENT_CONSUME
			end
		)
		local group = Group('keyboard_textinput', { textinput = input, backspace = backspace } )

		window:addWidget(group)
		window:addWidget(keyboard)
		window:focusWidget(group)

	-- special case for sending over textArea
	elseif item and item['textArea'] then
		local textArea = Textarea("text", item['textArea'])
		window:addWidget(textArea)
	else
	
		-- create a cozy place for our items...
		-- a db above
	
		-- a menu. We manage closing ourselves to guide our path
		menu = Menu(db:menuStyle(), _browseMenuRenderer, _browseMenuListener, _browseMenuAvailable)
		
		-- alltogether now
		menu:setItems(db:menuItems())
		window:addWidget(menu)

		-- add support for help text on a regular menu
		local helpText
		if windowSpec.help then
			helpText = windowSpec.help
			if helpText then
				local help = Textarea('help', helpText)
				window:addWidget(help)
			end
		end

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
	window:addListener(EVENT_WINDOW_POP,
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


local function _installPlayerKeyHandler(self)
	if _playerKeyHandler then
		return
	end

	_playerKeyHandler = Framework:addListener(EVENT_KEY_DOWN | EVENT_KEY_PRESS | EVENT_KEY_HOLD,
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
			return func(self, event)
		end,
		false
	)
end


local function _removePlayerKeyHandler(self)
	if not _playerKeyHandler then
		return
	end

	Framework:removeListener(_playerKeyHandler)
	_playerKeyHandler = false
end

local function _installActionListeners(self)
	if _actionListenerHandles  then
		return
	end
	
	_actionListenerHandles = {}
	
	for action, func in pairs( _globalActionsNEW ) do
		local handle = Framework:addActionListener(action, self, func, false)
		table.insert(_actionListenerHandles, handle)
	end
	
end

local function _removeActionListeners(self)
	if not _actionListenerHandles then
		return
	end

	for i, handle in ipairs( _actionListenerHandles ) do
		Framework:removeListener(handle)
	end

	_actionListenerHandles = false
end


--==============================================================================
-- SlimBrowserApplet public methods
--==============================================================================

-- goHome
-- pushes the home window to the top
function goHome(self, transition)
	local windowStack = Framework.windowStack
	Framework:playSound("JUMP")
	while #windowStack > 1 do
		windowStack[#windowStack - 1]:hide(transition)
	end
end


-- showTrackOne
--
-- pushes the song info window for track one on stage
-- this method is used solely by NowPlaying Applet for
-- skipping the playlist screen when the playlist size == 1
function showTrackOne()
	local playerStatus = _player:getPlayerStatus()
	local item = playerStatus and playerStatus.item_loop and playerStatus.item_loop[1]
	local iWindow = _safeDeref(item, 'window')

	local baseData = playerStatus and playerStatus.base
	local bWindow = _safeDeref(baseData, 'window')

	local bAction = _safeDeref(baseData, 'actions', 'go')
	local iAction = _safeDeref(item, 'actions', 'go')

	local jsonAction

	-- if the action is defined in the item, then do that
	if iAction then
		jsonAction = iAction
	-- bAction contains (possibly) the start of the songinfo command for track 1
	else
		jsonAction = bAction
		local params = jsonAction["params"]
                if not params then
			params = {}
		end
		-- but also get params in the item
		if item["params"] then
			for k,v in pairs(item['params']) do
				params[k] = v
			end
		end
		jsonAction["params"] = params
	end

	-- determine style
	local newWindowSpec = {
		["windowStyle"]      = "trackinfo",
		["menuStyle"]        = "menu",
		["labelItemStyle"]   = "item",
		["text"]             = _priorityAssign('text',       item["text"],    iWindow, bWindow),
		["icon-id"]          = _priorityAssign('icon-id',    item["icon-id"], iWindow, bWindow),
		["icon"]             = _priorityAssign('icon',       item["icon"],    iWindow, bWindow),
	}		

	local step, sink = _newDestination(nil, item, newWindowSpec, _browseSink)
	step.window:addActionListener("back", step, _goNowPlayingAction)
	step.window:show()
	_curStep = step

	-- send the command
	local from, qty
	_performJSONAction(jsonAction, 0, 200, step, sink)
end


function findLocalPlayer(self)
	-- get local player object
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			log:debug("found local player")
			return player
		end
	end
	log:error('no local player found')
	return nil
end


function findSqueezeNetwork(self)
	-- get squeezenetwork object
        for mac, server in appletManager:callService("iterateSqueezeCenters") do
		if server:isSqueezeNetwork() then
                        log:debug("found SN")
                        return server
                end
        end
	log:error('SN not found')
	return nil
end


function squeezeNetworkRequest(self, request)
	local squeezenetwork = findSqueezeNetwork()
	local localPlayer    = findLocalPlayer()

	_string = function(token) return self:string(token) end

	if not squeezenetwork or not localPlayer or not request then
		return
	end
	_server = squeezenetwork
	_player = localPlayer

	-- create a window for SN signup
	local step, sink = _newDestination(
		nil,
		nil,
		{
			text = self:string("SN_SIGNUP"),
			menuStyle = 'menu',
			labelItemStyle   = "item",
			windowStyle = 'text_list',
		},
		_browseSink
	)

	_pushToNewWindow(step)
        squeezenetwork:userRequest( sink, nil, request )

end


-- showEmptyPlaylist
-- if the player playlist is empty, we replace _statusStep with this window
function showEmptyPlaylist(token)

	local window = Window("icon_list", _string(modeTokens['play']), 'currentplaylisttitle')
	local menu = SimpleMenu("menu")
	menu:addItem({
		     text = _string(token),
			style = 'item_no_arrow'
	})
	window:addWidget(menu)

	_emptyStep = {}
	_emptyStep.window = window

	return window

end

function _leavePlayListAction()
	local windowStack = Framework.windowStack
	-- if this window is #2 on the stack there is no NowPlaying window
	-- (e.g., when playlist is empty)
	if #windowStack == 2 then
		_goNow('home')
	else
		_goNow('nowPlaying')
	end
	return EVENT_CONSUME
end


-- showPlaylist
--
function showPlaylist()
	if _statusStep then

		-- arrange so that menuListener works
		_curStep = _statusStep

		-- current playlist should select currently playing item 
		-- if there is only one item in the playlist, bring the selected item to top
		local playerStatus = _player:getPlayerStatus()
		local playlistSize = _player:getPlaylistSize() 

		if not _player:isPowerOn() then
			_statusStep.window:setTitle(_string(modeTokens['off']))
		end

		if playlistSize == 0 then
			local customWindow = showEmptyPlaylist('SLIMBROWSER_NOTHING') 
			customWindow:show()
			return EVENT_CONSUME
		end


		if playlistSize == nil or (playlistSize and playlistSize <= 1) then
			_statusStep.menu:setSelectedIndex(1)
		-- where we are in the playlist is stored in the item list as currentIndex
		elseif _statusStep.menu:getItems() and _statusStep.menu:getItems().currentIndex then
			_statusStep.menu:setSelectedIndex(_statusStep.menu:getItems().currentIndex)
		end

		_statusStep.window:addActionListener("back", _statusStep, _leavePlayListAction)

		_statusStep.window:show()


		return EVENT_CONSUME
	end
	return EVENT_UNUSED

end

function notify_playerPower(self, player, power)
	log:debug('SlimBrowser.notify_playerPower')
	if _player ~= player then
		return
	end
	local playerStatus = player:getPlayerStatus()
	if not playerStatus then
		log:info('no player status')
		return
	end

	local playlistSize = playerStatus.playlist_tracks
	local mode = player:getPlayMode()

	-- when player goes off, user should get single item styled 'Off' playlist
	local step = _statusStep
	local emptyStep = _emptyStep

	if step and step.menu then
		-- show 'OFF' in playlist window title when the player is off
		if not power then
			if step.window then
				step.window:setTitle(_string("SLIMBROWSER_OFF"))
			end
		else
			if step.window then
				if emptyStep then
					step.window:replace(emptyStep.window, Window.transitionFadeIn)
				end
				step.window:setTitle(_string(modeTokens[mode]))
			end
		end
	end
end

function notify_playerModeChange(self, player, mode)
	log:debug('SlimBrowser.notify_playerModeChange')
	if _player ~= player then
		return
	end

	local step = _statusStep
	local token = mode
	if mode != 'play' and not player:isPowerOn() then
		token = 'off'
	end

	step.window:setTitle(_string(modeTokens[token]))

end

function notify_playerPlaylistChange(self, player)
	log:debug('SlimBrowser.notify_playerPlaylistChange')
	if _player ~= player then
		return
	end

	local playerStatus = player:getPlayerStatus()
	local playlistSize = _player:getPlaylistSize()
	local step         = _statusStep
	local emptyStep    = _emptyStep

	-- display 'NOTHING' if the player is on and there aren't any tracks in the playlist
	if _player:isPowerOn() and playlistSize == 0 then
		local customWindow = showEmptyPlaylist('SLIMBROWSER_NOTHING') 
		if emptyStep then
			customWindow:replace(emptyStep.window, Window.transitionFadeIn)
		end
		if step.window then
			customWindow:replace(step.window, Window.transitionFadeIn)
		end
		-- we've done all we need to when the playlist is 0, so let's get outta here
		return
	-- make sure we have step.window replace emptyStep.window when there are tracks and emptyStep exists
	elseif playlistSize and emptyStep then
		if step.window then
			step.window:replace(emptyStep.window, Window.transitionFadeIn)
		end
	
	end

	-- update the window
	step.db:updateStatus(playerStatus)
	step.menu:reLayout()

	-- does the playlist need loading?
	_requestStatus()

end

function notify_playerTrackChange(self, player, nowplaying)
	log:debug('SlimBrowser.notify_playerTrackChange')

	if _player ~= player then
		return
	end

	if not player:isPowerOn() then
		return
	end

	local playerStatus = player:getPlayerStatus()
	local step = _statusStep

	step.db:updateStatus(playerStatus)
	if step.db:playlistIndex() then
		step.menu:setSelectedIndex(step.db:playlistIndex())
	else
		step.menu:setSelectedIndex(1)
	end
	step.menu:reLayout()

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
		log:info("Player gone while browsing it ! -- packing home!")
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

	-- clear any errors, we may have changed servers
	iconbar:setServerError("OK")

	-- update the volume object
	if self.volume then
		self.volume:setPlayer(player)
	end

	-- update the scanner object
	self.scanner:setPlayer(player)

	-- nothing to do if we don't have a player or server
	-- NOTE don't move this, the code above needs to run when disconnecting
	-- for all players.
	if not player or not player:getSlimServer() then
		return
	end

	-- assign our locals
	_player = player
	_server = player:getSlimServer()
	_string = function(token) return self:string(token) end
	local _playerId = _player:getId()

	log:info('Subscribing to /slim/menustatus/', _playerId)
	local cmd = { 'menustatus' }
	_player:subscribe(
		'/slim/menustatus/' .. _playerId,
		_menuSink(sink, cmd),
		_playerId,
		cmd
	)

	-- create a window for the current playlist, this is our _statusStep
	local step, sink = _newDestination(
		nil,
		nil,
		_newWindowSpec(
			nil, 
			{
				text = _string("SLIMBROWSER_PLAYLIST"),
				window = { 
					["menuStyle"] = "album", 
				}
			},
			'currentplaylist'
		),
		_statusSink
	)
	_statusStep = step
	
	-- make sure it has our modifier (so that we use different default action in Now Playing)
	_statusStep.actionModifier = "-status"

	-- showtime for the player
	_server.comet:startBatch()
	_server:userRequest(sink, _playerId, { 'menu', 0, 100 })
	_player:onStage()
	_requestStatus()
	_server.comet:endBatch()

	-- look to see if the playlist has size and the state of player power
	-- if playlistSize is 0 or power is off, we show and empty playlist
	if not _player:isPowerOn() then
		if _statusStep.window then
			_statusStep.window:setTitle(_string("SLIMBROWSER_OFF"))
		end
	end

	if _player:isNeedsUpgrade() then
		if _player:isUpgrading() then
			_updatingPlayer(self)
		else
			_userTriggeredUpdate(self)
		end
	else
		_hidePlayerUpdating()
	end

	-- add a fullscreen popup that waits for the _menuSink to load
	_menuReceived = false
	_connectingToPlayer(self)

	jiveMain:setTitle(_player:getName())
	_installActionListeners(self)
	_installPlayerKeyHandler(self)
	
end

function notify_playerNeedsUpgrade(self, player, needsUpgrade, isUpgrading)
	log:debug("SlimBrowserApplet:notify_playerNeedsUpgrade(", player, ")")

	if _player ~= player then
		return
	end

	if isUpgrading then
		log:info('Show upgradingPlayer popup')
		_updatingPlayer(self)
	elseif needsUpgrade then
		log:info('Show userUpdate popup')
		_userTriggeredUpdate(self)
	else
		_hideUserUpdatePopup()
		_hidePlayerUpdating()
	end

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


function notify_serverDisconnected(self, server, numUserRequests)
	if _server ~= server then
		return
	end

	iconbar:setServerError("ERROR")

	if numUserRequests == 0 or self.serverErrorWindow then
		return
	end

	self:_problemConnectingPopup(server)
end


function _problemConnectingPopup(self, server)
	-- attempt to reconnect, this may send WOL
	server:wakeOnLan()
	server:connect()

	-- popup
	local popup = Popup("waiting_popup")
	popup:addWidget(Icon("icon_connecting"))
	popup:addWidget(Label("text", self:string("SLIMBROWSER_CONNECTING_TO", server:getName())))

	local count = 0
	popup:addTimer(1000,
		function()
			count = count + 1
			if count == 20 then
				self:_problemConnecting(server)
			end
		end)

	-- once the server is connected the popup is closed in
	-- notify_serverConnected
	self.serverErrorWindow = popup
	popup:show()
end


function _problemConnecting(self, server)
	-- open connection error window
	local window = Window("text_list", self:string("SLIMBROWSER_PROBLEM_CONNECTING"), 'settingstitle')

	local menu = SimpleMenu("menu")

	local player = _player

	-- try again, reconnect to server
	menu:addItem({
			     text = self:string("SLIMBROWSER_TRY_AGAIN"),
			     callback = function()
						window:hide()

						self:_problemConnectingPopup(server)
						appletManager:callService("setCurrentPlayer", player)
					end,
			     sound = "WINDOWSHOW",
		     })

	if server:isPasswordProtected() then
		-- password protection has been enabled
		menu:addItem({
			text = self:string("SLIMBROWSER_ENTER_PASSWORD"),
			callback = function()
				appletManager:callService('squeezeCenterPassword', server)
			end,
			sound = "WINDOWSHOW",
		})
	end

	-- change music source, only for udap players
	if player and player:canUdap() and appletManager:hasApplet("SetupSqueezebox") then
		menu:addItem({
				     text = self:string("SLIMBROWSER_CHOOSE_MUSIC_SOURCE"),
				     callback = function()
							appletManager:callService("setCurrentPlayer", nil)
							appletManager:callService('startSqueezeboxSetup', player:getMacAddress(), nil)
						end,
				     sound = "WINDOWSHOW",
			     })
	end

	-- change player, only if multiple players
	local numPlayers = appletManager:callService("countPlayers")
	if numPlayers > 1 and appletManager:hasApplet("SelectPlayer") then
		menu:addItem({
				     text = self:string("SLIMBROWSER_CHOOSE_PLAYER"),
				     callback = function()
							appletManager:callService("setCurrentPlayer", nil)
							appletManager:callService("setupShowSelectPlayer")
						end,
				     sound = "WINDOWSHOW",
			     })
	end

	window:addWidget(Textarea("help_text", self:string("SLIMBROWSER_PROBLEM_CONNECTING_HELP", tostring(_server:getName()))))
	window:addWidget(menu)

	self.serverErrorWindow = window
	window:addListener(EVENT_WINDOW_POP,
			   function()
				   self.serverErrorWindow = false
			   end)

	window:show()
end

-- hideConnectingToPlayer
-- hide the full screen popup that appears until menus are loaded
function hideConnectingToPlayer()
	if _connectingPopup then
		log:info("_connectingToPlayer popup hide")
		_connectingPopup:hide()
		_connectingPopup = nil

		jnt:notify("playerLoaded", _player)
	end
end

--[[

=head2 applets.SlimBrowser.SlimBrowserApplet:free()

Overridden to close our player.

=cut
--]]
function free(self)
	log:debug("SlimBrowserApplet:free()")

	-- unsubscribe from this player's menustatus
	log:info("Unsubscribe /slim/menustatus/", _player:getId())
	if _player then
		_player:unsubscribe('/slim/menustatus/' .. _player:getId())
	end

	if _player then
		_player:offStage()
	end

	_removePlayerKeyHandler(self)
	_removeActionListeners(self)
	
	-- remove player menus
	jiveMain:setTitle(nil)
	for id, v in pairs(_playerMenus) do
		jiveMain:removeItem(v)
	end
	_playerMenus = {}

	-- remove connecting popup
	hideConnectingToPlayer()
	_hidePlayerUpdating()
	_hideUserUpdatePopup()

	_player = false
	_server = false
	_string = false

	-- make sure any home menu itema are unlocked
	if _lockedItem then
		jiveMain:unlockItem(_lockedItem)
		_lockedItem = false
	end

	-- walk down our path and close...
	local step = _curStep

	-- Note, we guard against circular references here
	while step do
		step.window:hide()

		if step == step.origin then
			log:error("Loop detected in _curStep")
			step = nil
		else
			step = step.origin
		end
	end
	
	local step = _statusStep
	
	while step do
		step.window:hide()

		if step == step.origin then
			log:error("Loop detected in _statusStep")
			step = nil
		else
			step = step.origin
		end
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

	self.volume = Volume(self)
	self.scanner = Scanner(self)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

