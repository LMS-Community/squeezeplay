
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

local jiveMain               = jiveMain
local appletManager          = appletManager
local iconbar                = iconbar
local jnt                    = jnt


module(..., Framework.constants)
oo.class(_M, Applet)


local _player = false
local _server = false

local _updatingPlayerPopup = false
local _updatingPromptPopup = false

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
	myMusic = { "_myMusic", "hidden" , nil, true},
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

local idMismatchMap = {
	ondemand = "music_services",
--	radio = "radios" - commented out until we resolve difference between SC and SN regarding Internet radio (SC has as node and items, SN has as single item)

}


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


function init(self)
	jnt:subscribe(self)

	self.serverHomeMenuChunks = {}
end


function notify_serverLinked(self, server)
	log:debug("***linked\t", server)
	--linked seems to be the best status to indicate serverstatus is complete (and thus version info, etc is now known)
	if server:isCompatible() and server:isSqueezeNetwork() then
		log:info("***linked SN\t", server)
		self:_fetchServerMenu(server)
	end
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
		if _player:isLocal() then
			_player:disconnectServerAndPreserveLocalPlayer()
		else
			appletManager:callService("setCurrentPlayer", nil)

		end
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
		if _player:isLocal() then
			_player:disconnectServerAndPreserveLocalPlayer()
		else
			appletManager:callService("setCurrentPlayer", nil)

		end
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


--
--add node to home menu only if this is a menustatusresponse or it doesn't exist. Only menustatus responses may replace existing items.
function  _addNode(self, node, isMenuStatusResponse)
	if isMenuStatusResponse then
		jiveMain:addNode(node)
	else
		if not jiveMain:exists(node.id) then
			jiveMain:addNode(node, true)
		else
			log:debug("node already present: ", node.id)
		end
	end
end
--add item to home menu only if this is a menustatusresponse or it doesn't exist. Only menustatus responses may replace existing items.
function  _addItem(self, item, isMenuStatusResponse)
	if isMenuStatusResponse or not _playerMenus[item.id] then
		 _playerMenus[item.id] = item
		 jiveMain:addItem(item)
	else
		log:debug("item already present: ", item.id)
	end
end


--various compatiblilty hacks
function _massageItem(item)
	if idMismatchMap[item.id] then
		log:debug("fixing mismatch item: ", item.id)

		item.id = idMismatchMap[item.id]
	end

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
		if itemMap[id][4] then
			item.isANode = itemMap[id][4]
		end
	end
	if itemMap[item.node] then
		local node = item.node
		item.node = itemMap[node][1]
	end


end


-- _menuSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _menuSink(self, cmd, server)
	return function(chunk, err)
		log:info("_menuSink() ", server)
		local isMenuStatusResponse = not server

		local menuItems, menuDirective, playerId
		if isMenuStatusResponse then
			--this is a menustatus response for the connected player
			if not _player then
				log:warn("catch race condition if we've switch player")
				return
			end

			-- process data from a menu notification
			-- each chunk.data[2] contains a table that needs insertion into the menu
			menuItems = chunk.data[2]
			-- directive for these items is in chunk.data[3]
			menuDirective = chunk.data[3]
			-- the player ID this notification is for is in chunk.data[4]
			playerId = chunk.data[4]

			if playerId ~= 'all' and playerId ~= _player:getId() then
				log:debug('This menu notification was not for this player')
				log:debug("Notification for: ", playerId)
				log:debug("This player is: ", _player:getId())
				return
			end
		else
			--this is a response from a "menu" command for a non-connected player
			menuItems = chunk.data.item_loop

		end
		-- if we get here, it was for this player. set menuReceived to true
		_menuReceived = true


if _menuReceived then
-- a problem, we lose the icons..
self:_addNode({
  sound = "WINDOWSHOW",
  weight = 20,
  id = "radios",
  text = "Internet Radio (SC)",
  node = "home",
}, isMenuStatusResponse)
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
--			if server and item.text then
--				--temp mark for debugging purposes
--				item.text = item.text .. "(SN!)"
--			end

			local itemIcon = v.window  and v.window['icon-id'] or v['icon-id']
			if itemIcon then
				if isMenuStatusResponse  then
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
				else
					log:debug("todo: how to handle fetching icons from disconnected servers!?")
				end
			end

			-- hack to modify styles from SC
			if item.style and styleMap[item.style] then
				item.style = styleMap[item.style]
			end
			local choiceAction = _safeDeref(v, 'actions', 'do', 'choices')

			_massageItem(item, item)

			-- a problem, we lose the icons..
			if item.id == "radios" then
				v.isANode = true
			end

			--temp hack until we resolve SN/SC radios discrepency, show both since we can't merge (SC uses node and subitem, SN uses single item)
			--BEGIN
			if item.id == "radio" then
				--temp mark for debugging purposes
				item.text = item.text .. " (SN)"
			end
			if item.id == "radios" then
				--temp mark for debugging purposes
				item.text = item.text .. " (SC)"
			end
			--END temp hack until we resolve SN/SC radios discrepency

			if v.isANode or item.isANode then
				self:_addNode(item, isMenuStatusResponse)
			elseif menuDirective == 'remove' then
				--todo: massage SN request to remove myMusicMusicFolder
				jiveMain:removeItemById(item.id)

			elseif isMenuStatusResponse and choiceAction then
--				debug.dump(choiceAction, 4)

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

				item.removeOnServerChange = true

				--add the item to the menu
				self:_addItem(item, isMenuStatusResponse)

			else
				local action = function ()
							log:debug("send browserActionRequest request")

							local step = appletManager:callService("browserActionRequest", nil, v,
								function()
									jiveMain:unlockItem(item)
									_lockedItem = false
								end)

							_lockedItem = item
							jiveMain:lockItem(item, function()
								appletManager:callService("browserCancel", step)
							end)
						end

				item.callback = function()
					--todo:
					 -- check: is server accesible
					 -- if not, can SN provide the content?
					 -- if so, switch server to SN and provide content


					--temp hack until we resolve SN/SC radios discrepency, show both since we can't merge (SC uses node and subitem, SN uses single item)
--					original: if (not _server or not _server:isConnected()) and self:_canSqueezeNetworkServe(item) then
					if ((not _server or not _server:isConnected()) and self:_canSqueezeNetworkServe(item))
					    or item.id == 'radio' then
						log:warn("switching to SN")
						log:warn("Do we want to try to reconnect to SC first here?")
						self:_selectMusicSource(action, self:_getSqueezeNetwork(),
						_player and _player:getLastSqueezeCenter() or nil)

					--temp hack until we resolve SN/SC radios discrepency, show both since we can't merge (SC uses node and subitem, SN uses single item)
--					original: elseif (not _server or _server:isSqueezeNetwork()) and not self:_canSqueezeNetworkServe(item) then
					elseif ((not _server or _server:isSqueezeNetwork()) and not self:_canSqueezeNetworkServe(item))
					        or item.node == 'radios' then
						log:warn("switching from SN to last SqueezeCenter")

						self:_selectMusicSource(action, _player:getLastSqueezeCenter())

--					elseif not either then
					else
						--current server is available, go direct
						action()
					end
				end
				self:_addItem(item, isMenuStatusResponse)
			end
		end
		if _menuReceived and isMenuStatusResponse and menuDirective ~= 'remove' then
			log:info("hiding any 'connecting to server' popup after 'add' menustatus response ")

			appletManager:callService("hideConnectingToServer")
		end
         end
end


function _canSqueezeNetworkServe(self, item)
	local sn, menuChunk = self:_getSqueezeNetwork()
	if not menuChunk then
		log:error("SN can not serve, SN menus not here (yet). item: ", item.id)

	        return false
	end

	local menuItems = menuChunk.data.item_loop
	for key, value in pairs(menuItems) do
		if value.id == item.id then
		log:debug("SN can serve item: ", item.id)
			return true
		end
	end

	--
	if item.node == 'radios' then
		log:error("probably broken hack to deal with radio discrepency (SN does server up individual subitem items as home menue items), returning SN can server for: ", item.id)
		return true
	end

	log:debug("SN can not serve item: ", item.id)


	return false
end

function _getSqueezeNetwork(self, item)
	for server, chunk in pairs(self.serverHomeMenuChunks) do
		if server:isSqueezeNetwork() then
			return server, chunk
		end
	end

	return nil
end

-- notify_playerNewName
-- this is called when the player name changes
-- we update our main window title
function notify_playerNewName(self, player, newName)
	log:debug("SlimMenusApplet:notify_playerNewName(", player, ",", newName, ")")

	newName = self:_addServerNameToHomeTitle(newName)

	-- if this concerns our player
	if _player == player then
		jiveMain:setTitle(newName)
	end
end

function _addServerNameToHomeTitle(self, name)
	log:debug("_addServerNameToHomeTitle:, ", _server)

	if _server then
		name = name .. "(" .. _server.name ..")"
	end

	return name
end

function _selectMusicSource(self, callback, specificServer, serverForRetry)
	local currentPlayer = appletManager:callService("getCurrentPlayer")
	if not currentPlayer then
		log:info("No player yet, first select player (which will trigger choose music soure, then go home")
		appletManager:callService("setupShowSelectPlayer")
		return
	end

	appletManager:callService("selectMusicSource",
							callback,
							nil,
							nil,
							specificServer,
							serverForRetry
						)
end

function myMusicSelector(self)
	if not _server then
		self:_selectMusicSource(function()
						jiveMain:goHome()
						jiveMain:openNodeById('_myMusic', true)
					end)

	elseif _server:isSqueezeNetwork() then
		--offer switch back to SC
		self:_selectMusicSource(function()
						jiveMain:goHome()
						jiveMain:openNodeById('_myMusic', true)
					end,
					_player:getLastSqueezeCenter())
	else
		if _server:isConnected() then
			log:info("Opening myMusic")
			jiveMain:openNodeById('_myMusic')
		else
			--todo: server not connected, try again??
			log:info("Opening myMusic")
			jiveMain:openNodeById('_myMusic')
		end
	end
end

function otherLibrarySelector(self)
	self:_selectMusicSource(function()
					jiveMain:goHome()
					jiveMain:openNodeById('_myMusic', true)
				end)
end


-- notify_playerCurrent
-- this is called when the current player changes (possibly from no player)
function notify_playerCurrent(self, player)
	log:info("SlimMenusApplet:notify_playerCurrent(", player, ")")

	-- has the player actually changed?
	if _player == player then
		if player then
			if _server == player:getSlimServer() then
				log:debug("player and server didn't change , not changing menus: ", player)
				return
			else
				log:error("server changed - todo here we should switch switch out server specific items like Choice, turn on/off")

				_server = player:getSlimServer()

				local playerName = _player:getName()
				playerName = self:_addServerNameToHomeTitle(playerName)
				jiveMain:setTitle(playerName)

			end
		else
			--no current or old player yet
			return
		end
	end

	if player and not player:getSlimServer() then
		log:info("player changed from:", _player, " to ", player, " but server not yet connected")
	end

	if _player ~= player then
		-- free current player, since it has changed from one player to another
		self:free()

		--recache homemenu items from disconnected server
		for _,server in appletManager:callService("iterateSqueezeCenters") do
			if server:isCompatible() then
				self:_fetchServerMenu(server)
			elseif not server:getVersion() then
				log:warn("Compatibility not yet known, menu data may be lost: ", server)
			else
				log:debug("not compatible: ", server)
			end
		end
		
	end

	-- nothing to do if we don't have a player or server
	-- NOTE don't move this, the code above needs to run when disconnecting
	-- for all players.
	if not player then
		return
	end

	--can't subscribe to menustatus until we have a server
	if not player:getSlimServer() then
		return
	end

	-- unsubscribe from this player's menustatus for previous server
	player:unsubscribe('/slim/menustatus/' .. player:getId())

	log:info("player changed from:", _player, " to ", player, " for server: ", player:getSlimServer(), " from server: ", _server)

	_player = player
	_server = player:getSlimServer()

	local _playerId = _player:getId()

	log:info('\nSubscribing to /slim/menustatus/\n', _playerId)
	local cmd = { 'menustatus' }
	_player:subscribe(
		'/slim/menustatus/' .. _playerId,
		_menuSink(self, cmd),
		_playerId,
		cmd
	)

	-- XXXX why is this needed? Answer:menustatus won't send anything by default
	_server:userRequest(nil, _playerId, { 'menu', 0, 100 })
	
	-- add a fullscreen popup that waits for the _menuSink to load
	_menuReceived = false

	if player:isLocal() and not _server:isSqueezeNetwork() then
		--local player keep track of previous SC connected to so "return to SC" can occur when re-attempting local content after being on SN
		player:setLastSqueezeCenter(_server)
	end

	if player:getSlimServer() then

		local playerName = _player:getName()
		playerName = self:_addServerNameToHomeTitle(playerName)
		jiveMain:setTitle(playerName)

		-- display upgrade pops (if needed)
		self:notify_playerNeedsUpgrade(player)
	end

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


function _fetchServerMenu(self, server)
	log:debug("Fetching menu for server: ", server)

	server:userRequest(_sinkSetServerMenuChunk(self, server) , nil, { 'menu', 0, 100 })

end

function _sinkSetServerMenuChunk(self, server)
	return function(chunk, err)
		for _, item in pairs(chunk.data.item_loop) do
			local oldId = item.id

			_massageItem(item)
		end

		self.serverHomeMenuChunks[server] = chunk
		self:_mergeServerMenuToHomeMenu(server, chunk)
	end
end




function _mergeServerMenuToHomeMenu(self, server, chunk)
	--this might be the current server so handle that gracefully
--	log:warn("TODO - MERGE: ", server)

	if server:isSqueezeNetwork() then
		log:warn("MERGE SN menus")
		_menuSink(self, nil, server)(chunk)
	end

end


function free(self)

	self.serverHomeMenuChunks = {}

	-- unsubscribe from this player's menustatus
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
	appletManager:callService("hideConnectingToServer")

	-- make sure any home menu itema are unlocked
	if _lockedItem then
		jiveMain:unlockItem(_lockedItem)
		_lockedItem = false
	end

	_hidePlayerUpdating()

	_player = false
	_server = false
end
