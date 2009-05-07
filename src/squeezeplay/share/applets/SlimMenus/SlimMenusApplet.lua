
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


local _player = false
local _server = false

-- connectingToPlayer and _upgradingPlayer popup handlers
local _updatingPlayerPopup = false
local _updatingPromptPopup = false
local _connectingPopup = false

local _lockedItem = false

local _playerMenus = {}


-- legacy map of item styles to new item style names
-- WARNING - duplicated in SlimBrowserApplet
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


function init(self)
	jnt:subscribe(self)
end


-- _safeDeref
-- safely derefence a structure in depth
-- doing a.b.c.d will fail if b or c are not defined
-- _safeDeref(a, "b", "c", "d") will always work (of course, it returns nil if b or c are not defined!)
local function _safeDeref(struct, ...)
	local res = struct
	for i=1, select('#', ...) do
		local v = select(i, ...)
		if type(res) != 'table' then return nil end
		if v then
			res = res[v]
			if not res then return nil end
		end
	end
	return res
end


-- goHome
-- pushes the home window to the top
function goHome(self, transition)
	local windowStack = Framework.windowStack
	Framework:playSound("JUMP")
	while #windowStack > 1 do
		windowStack[#windowStack - 1]:hide(transition)
	end
end

-- _connectingToPlayer
-- full screen popup that appears until menus are loaded
function _connectingToPlayer(self)
	log:info("_connectingToPlayer popup show")

	if _connectingPopup or _updatingPromptPopup or _updatingPlayerPopup then
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


-- _updatingPlayer
-- full screen popup that appears until menus are loaded
function _updatingPlayer(self)
	log:warn("_updatingPlayer popup show")

	if _updatingPromptPopup then
		_hidePlayerUpdating()
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


-- _userTriggeredUpdate
-- full screen popup that appears until user hits brightness on player to start upgrade
function _userTriggeredUpdate(self)
	log:warn("_userTriggeredUpdate popup show")


	if _updatingPromptPopup then
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

	_updatingPlayerPopup = false
end


-- _hidePlayerUpdating
-- hide the full screen popup that appears until player is updated
function _hidePlayerUpdating()
	if _updatingPlayerPopup then
		_updatingPlayerPopup:hide()
		_updatingPlayerPopup = false
	end

	if _updatingPromptPopup then
		_updatingPromptPopup:hide()
		_updatingPromptPopup = false
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
				--item["icon-id"] = itemIcon

				local _size = jiveMain:getSkinParam('THUMB_SIZE')
				item.icon = Icon('icon')
				_server:fetchArtworkThumb(itemIcon, item.icon, _size)

				-- Hack alert: redefine the checkSkin function
				-- to reload images when the skin changes. We
				-- should replace this with resizable icons.
				local _style = item.icon.checkSkin
				item.icon.checkSkin = function(...)
					local s = jiveMain:getSkinParam('THUMB_SIZE')
					if s ~= _size then
						_size = s
						_server:fetchArtworkThumb(itemIcon, item.icon, _size)						
					end

					_style(...)
				end
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
						appletManager:callService("browserJsonRequest", _server, jsonAction)
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
					local step = appletManager:callService("browserActionRequest", _server, v,
						function()
							jiveMain:unlockItem(item)
							_lockedItem = false
						end)

					_lockedItem = item
					jiveMain:lockItem(item, function()
						appletManager:callService("browserCancel", step)
					end)
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

	-- nothing to do if we don't have a player or server
	-- NOTE don't move this, the code above needs to run when disconnecting
	-- for all players.
	if not player or not player:getSlimServer() then
		return
	end

	_player = player
	_server = player:getSlimServer()

	local _playerId = _player:getId()

	log:info('Subscribing to /slim/menustatus/', _playerId)
	local cmd = { 'menustatus' }
	_player:subscribe(
		'/slim/menustatus/' .. _playerId,
		_menuSink(sink, cmd),
		_playerId,
		cmd
	)

	-- XXXX why is this needed?
	_server:userRequest(nil, _playerId, { 'menu', 0, 100 })

	-- add a fullscreen popup that waits for the _menuSink to load
	_menuReceived = false
	_connectingToPlayer(self)

	jiveMain:setTitle(_player:getName())

	-- display upgrade pops (if needed)
	self:notify_playerNeedsUpgrade(player)
end


function notify_playerNeedsUpgrade(self, player, needsUpgrade, isUpgrading)
	if _player ~= player then
		return
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
end


function free(self)
	-- unsubscribe from this player's menustatus
	log:info("Unsubscribe /slim/menustatus/", _player:getId())
	if _player then
		_player:unsubscribe('/slim/menustatus/' .. _player:getId())
	end

	-- remove player menus
	jiveMain:setTitle(nil)
	for id, v in pairs(_playerMenus) do
		jiveMain:removeItem(v)
	end
	_playerMenus = {}

	-- remove connecting popup
	hideConnectingToPlayer()

	-- make sure any home menu itema are unlocked
	if _lockedItem then
		jiveMain:unlockItem(_lockedItem)
		_lockedItem = false
	end

	_hidePlayerUpdating()

	_player = false
	_server = false
end
