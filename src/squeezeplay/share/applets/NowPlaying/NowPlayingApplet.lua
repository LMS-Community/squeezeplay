local pairs, ipairs, tostring, type, setmetatable, tonumber = pairs, ipairs, tostring, type, setmetatable, tonumber

local math             = require("math")
local table            = require("jive.utils.table")
local string	       = require("jive.utils.string")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
local Event            = require("jive.ui.Event")
local Framework        = require("jive.ui.Framework")
local Icon             = require("jive.ui.Icon")
local Button           = require("jive.ui.Button")
local Choice           = require("jive.ui.Choice")
local Label            = require("jive.ui.Label")
local Group            = require("jive.ui.Group")
local Slider	       = require("jive.ui.Slider")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
local Tile             = require("jive.ui.Tile")
local Timer            = require("jive.ui.Timer")
                       
local debug            = require("jive.utils.debug")
local datetime         = require("jive.utils.datetime")

local appletManager    = appletManager

local jiveMain               = jiveMain
local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

local showProgressBar = true
local modeTokens = {
	off   = "SCREENSAVER_OFF",
	play  = "SCREENSAVER_NOWPLAYING",
	pause = "SCREENSAVER_PAUSED",
	stop  = "SCREENSAVER_STOPPED"
}

local repeatModes = {
	mode0 = 'repeatOff',
	mode1 = 'repeatSong',
	mode2 = 'repeatPlaylist',
}

local shuffleModes = {
	mode0 = 'shuffleOff',
	mode1 = 'shuffleSong',
	mode2 = 'shuffleAlbum',
}
	
----------------------------------------------------------------------------------------
-- Helper Functions
--

-- defines a new style that inherits from an existing style
local function _uses(parent, value)
        local style = {}
        setmetatable(style, { __index = parent })

        for k,v in pairs(value or {}) do
                if type(v) == "table" and type(parent[k]) == "table" then
                        -- recursively inherit from parent style
                        style[k] = _uses(parent[k], v)
                else
                        style[k] = v
                end
        end

        return style
end

local function _secondsToString(seconds)
	local hrs = math.floor(seconds / 3600)
	local min = math.floor((seconds / 60) - (hrs*60))
	local sec = math.floor( seconds - (hrs*3600) - (min*60) )

	if hrs > 0 then
		return string.format("%d:%02d:%02d", hrs, min, sec)
	else
		return string.format("%d:%02d", min, sec)
	end
end

local function _getIcon(self, item, icon, remote)
	local server = self.player:getSlimServer()

	-- FIXME, need to fix this for all styles of window including when NP artwork size set to 'large'
	ARTWORK_SIZE = jiveMain:getSkinParam("nowPlayingBrowseArtworkSize")
	
	local iconId
	if item then
		iconId = item["icon-id"] or item["icon"]
	end

	if iconId then
		-- Fetch an image from SlimServer
		server:fetchArtwork(iconId, icon, ARTWORK_SIZE) 
	elseif item and item["params"] and item["params"]["track_id"] then
		-- this is for placeholder artwork, either for local tracks or radio streams with no art
		server:fetchArtwork(item["params"]["track_id"], icon, ARTWORK_SIZE, 'png') 
	elseif icon then
		icon:setValue(nil)
	end
end


function init(self)

	jnt:subscribe(self)
	self.player = false
	self.lastVolumeSliderAdjustT = 0
end

function notify_playerShuffleModeChange(self, player, shuffleMode)
	log:debug("shuffle mode change notification")
	self:_updateShuffle(shuffleMode)
end

function notify_playerRepeatModeChange(self, player, repeatMode)
	log:debug("repeat mode change notification")
	self:_updateRepeat(repeatMode)
end

function notify_playerPower(self, player, power)
	if player ~= self.player then
		return
	end

	local mode = self.player:getPlayMode()

	-- hide this window if the player is turned off
	if not power then
		if self.titleGroup then
			self.titleGroup:setWidgetValue("text", self:_titleText(self:string(modeTokens['off'])))
		end
	else
		if self.titleGroup then
			self.titleGroup:setWidgetValue("text", self:_titleText(self:string(modeTokens[mode])))
		end
	end
end


function notify_playerTrackChange(self, player, nowPlaying)
	log:debug("Notification received that track has changed")

	local thisPlayer = _isThisPlayer(self, player)
	if not thisPlayer then return end

	self.player = player
	local playerStatus = player:getPlayerStatus()

	-- create the window to display
	local window = _createUI(self)
	if self.window then
		window:replace(self.window, Window.transitionFadeIn)
		self.window = window

	        if playerStatus and playerStatus.item_loop
			and self.nowPlaying ~= nowPlaying
		then
			-- for remote streams, nowPlaying = text
			-- for local music, nowPlaying = track_id
			self.nowPlaying = nowPlaying
	
			--update everything
			self:_updateAll(self)
		end
	end
end

function notify_playerModeChange(self, player, mode)

	if not self.player then
		return
	end

	log:debug("Player mode has been changed to: ", mode)
	self:_updateMode(mode)
end

-- players gone, close now playing
function notify_playerDelete(self, player)
	if player ~= self.player then
		return
	end

	self:freeAndClear()
end

-- players changed, add playing menu
function notify_playerCurrent(self, player)

	if self.player ~= player then
		self:freeAndClear()
	end

	self.player = player
	if not self.player then
		return
	end

	if jiveMain:getSkinParam("NOWPLAYING_MENU") then
		jiveMain:addItem({
			id = 'appletNowPlaying',
			iconStyle = 'hm_appletNowPlaying',
			node = 'home',
                        text = self:string('SCREENSAVER_NOWPLAYING'),
			sound = 'WINDOWSHOW',
			weight = 1,
			callback = function(event, menuItem)
				self:goNowPlaying(Window.transitionPushLeft)
			end
		})
        else
                jiveMain:removeItemById('appletNowPlaying')
        end
end


function notify_skinSelected(self)
	-- update menu
	notify_playerCurrent(self, self.player)
end


function _titleText(self, title)
	self.mainTitle = tostring(title)

	local usexofy = true
	if not self.player:isPowerOn() then
		usexofy = false
	end

	if self.xofy and usexofy then
		local returnVal = self.mainTitle .. " " .. self.xofy
		return returnVal
	else
		return self.mainTitle
	end
end


function _isThisPlayer(self, player)

	if not self.player and not self.player:getId() then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	if player:getId() ~= self.player:getId() then
		log:debug("notification was not for this player")
		log:debug("notification: ", player:getId(), "your player: ", self.player:getId())
		return false
	else
		return true
	end
	
end

function _updateAll(self)

	local playerStatus = self.player:getPlayerStatus()

	if playerStatus.item_loop then
		local trackInfo = self:_extractTrackInfo(playerStatus.item_loop[1])
		local showProgressBar = true
		-- XXX: current_title of null is a function value??
		if playerStatus.remote == 1 and type(playerStatus.current_title) == 'string' and type(trackInfo) == 'string' then 
			trackInfo = trackInfo .. "\n" .. playerStatus.current_title
		end
		if playerStatus.time == 0 then
			showProgressBar = false
		end

		local item = playerStatus.item_loop[1]
	
		if self.window then
			_getIcon(self, item, self.artwork, playerStatus.remote)

			self:_updateTrack(trackInfo)
			self:_updateProgress(playerStatus)
			self:_updateButtons(playerStatus)
			self:_updatePlaylist(true, playerStatus.playlist_cur_index, playerStatus.playlist_tracks)
		
			-- preload artwork for next track
			if playerStatus.item_loop[2] then
				_getIcon(self, playerStatus.item_loop[2], Icon("artwork"), playerStatus.remote)
			end
		end
	else
		if self.window then
			_getIcon(self, nil, self.artwork, nil)
			self:_updateTrack("\n\n\n")
			self:_updatePlaylist(false, 0, 0)
		end
	end
	self:_updateVolume()
end

function _updateButtons(self, playerStatus)
	-- no sense updating the transport buttons unless
	-- we are connected to a player and have buttons initialized
	if not self.player and self.controlsGroup then
		return
	end

	local remoteMeta = playerStatus.remoteMeta

	local shuffleIcon = self.controlsGroup:getWidget('shuffleMode')
	local repeatIcon  = self.controlsGroup:getWidget('repeatMode')

	local buttons = remoteMeta and remoteMeta.buttons
	-- if we have buttons data, the remoteMeta is remapping some buttons
	if buttons then
		-- disable rew or fw as needed
		if buttons.rew and buttons.rew == 0 then
			self:_remapButton('rew', 'rewDisabled', function() return EVENT_CONSUME end)
		else
			self.controlsGroup:setWidget('rew', self.rewButton)
		end

		if buttons.fwd and buttons.fwd == 0 then
			self:_remapButton('fwd', 'fwdDisabled', function() return EVENT_CONSUME end)
		else
			self.controlsGroup:setWidget('fwd', self.fwdButton)
		end

		if buttons.shuffle then
			local callback = function()
				local id      = self.player:getId()
				local server  = self.player:getSlimServer()
				local command = buttons.shuffle.command or function() return EVENT_CONSUME end
				server:userRequest(nil, id, command)
			end
			self:_remapButton('shuffleMode', buttons.shuffle.jiveStyle, callback)
		end

		if buttons['repeat'] then
			local callback = function()
				local id      = self.player:getId()
				local server  = self.player:getSlimServer()
				local command = buttons['repeat'].command or function() return EVENT_CONSUME end
				server:userRequest(nil, id, command)
			end
			self:_remapButton('repeatMode', buttons['repeat'].jiveStyle, callback)
		end

	-- if we don't have remoteMeta and button remapping, go back to defaults
	else
		self.controlsGroup:setWidget('rew', self.rewButton)
		self.controlsGroup:setWidget('fwd', self.fwdButton)
	end
end
	

function _remapButton(self, key, newStyle, newCallback)
	if not self.controlsGroup then
		return
	end
	-- set callback
	local newWidget = Button(Icon(key), newCallback)
	self.controlsGroup:setWidget(key, newWidget)
	-- set style
	local widget = self.controlsGroup:getWidget(key)
	if newStyle then
		widget:setStyle(newStyle)
	end

end


function _updateTrack(self, trackinfo, pos, length)
	if self.trackTitle then
		local trackTable
		-- SC is sending separate track/album/artist blocks
		if type(trackinfo) == 'table' then
			trackTable = trackinfo
		-- legacy SC support for all data coming in string 'text'
		else
			trackTable = string.split("\n", trackinfo)
		end

		local track     = trackTable[1]
		local artist    = trackTable[2]
		local album     = trackTable[3]
		
		--[[ FIXME, reformat trackinfo to one line in certain cases
		if customStyle == 'large' and windowStyle == 'ss' and 
			(jiveMain:getSelectedSkin() == 'QVGAportraitSkin') then
				trackinfo = string.gsub(trackinfo, "\n", " - ")
		end
		--]]

		self.trackTitle:setValue(track)
		self.albumTitle:setValue(album)
		self.artistTitle:setValue(artist)
	end
end

function _updateProgress(self, data)

	if not self.player then
		return
	end

	local elapsed, duration = self.player:getTrackElapsed()

	if duration and tonumber(duration) > 0 then
		self.progressSlider:setRange(0, tonumber(duration), tonumber(elapsed))
	else 
	-- If 0 just set it to 100
		self.progressSlider:setRange(0, 100, 0)
	end

	-- http streams show duration of 0 before starting, so update to a progress bar on the fly
	if duration and not showProgresBar then
		-- swap out progressBar
		self.window:removeWidget(self.progressNBGroup)
		self.window:addWidget(self.progressBarGroup)

		--temp hack until we resolve focus/missing widgets on skin switch issues
		self.window:focusWidget(self.trackTitle)

		self.progressGroup = self.progressBarGroup
		showProgressBar = true
	end

	_updatePosition(self)

end

function _updatePosition(self)
	if not self.player then
		return
	end

	local strElapsed = ""
	local strRemain = ""
	local pos = 0

	local elapsed, duration = self.player:getTrackElapsed()

	if elapsed then
		strElapsed = _secondsToString(elapsed)
	end
	if duration and duration > 0 then
		strRemain = "-" .. _secondsToString(duration - elapsed)
	end

	if self.progressGroup then
		self.progressGroup:setWidgetValue("elapsed", strElapsed)
		if showProgressBar then
			self.progressGroup:setWidgetValue("remain", strRemain)
			self.progressSlider:setValue(elapsed)
		end
	end
end

function _updateVolume(self)
	if not self.player then
		return
	end

	local volume       = tonumber(self.player:getVolume())
	local sliderVolume = self.volSlider:getValue()
	if sliderVolume ~= volume then
		log:debug("new volume from player: ", volume)
		self.volumeOld = volume
		self.volSlider:setValue(volume)
	end
end


function _updatePlaylist(self, enabled, nr, count)
	if enabled == true and count and tonumber(count) > 1 then
		nr = nr + 1
		self.xofy = self:string("SCREENSAVER_NOWPLAYING_OF", nr, count)
		self.titleGroup:setWidgetValue("text", self:_titleText(self.mainTitle))
	else 
		self.titleGroup:setWidgetValue("text", self:_titleText(self.mainTitle))
	end
end


function _updateShuffle(self, mode)
	-- don't update this if SC/SN has remapped shuffle button
	if self.player then
		local playerStatus = self.player:getPlayerStatus()
		if playerStatus and 
			playerStatus.remoteMeta and 
			playerStatus.remoteMeta.buttons and 
			playerStatus.remoteMeta.shuffle then
			return
		end
	end
	local token = 'mode' .. mode
	if not shuffleModes[token] then
		log:error('not a valid shuffle mode: ', token)
		return
	end
	if self.controlsGroup then
		local shuffleIcon = self.controlsGroup:getWidget('shuffleMode')
		shuffleIcon:setStyle(shuffleModes[token])
	end
end


function _updateRepeat(self, mode)
	-- don't update this if SC/SN has remapped repeat button
	if self.player then
		local playerStatus = self.player:getPlayerStatus()
		if playerStatus and 
			playerStatus.remoteMeta and 
			playerStatus.remoteMeta.buttons and 
			playerStatus.remoteMeta['repeat'] then
			return
		end
	end
	local token = 'mode' .. mode
	if not repeatModes[token] then
		log:error('not a valid repeat mode: ', token)
		return
	end
	if self.controlsGroup then
		local repeatIcon = self.controlsGroup:getWidget('repeatMode')
		repeatIcon:setStyle(repeatModes[token])
	end
end


function _updateMode(self, mode)
	local token = mode
	-- sometimes there is a race condition here between updating player mode and power, 
	-- so only set the title to 'off' if the mode is also not 'play'
	if token != 'play' and not self.player:isPowerOn() then
		token = 'off'
	end
	if self.titleGroup then
		self.titleGroup:setWidgetValue("text", self:_titleText(self:string(modeTokens[token])))
	end
	if self.controlsGroup then
		local playIcon = self.controlsGroup:getWidget('play')
		if token == 'play' then
			playIcon:setStyle('pause')
		else
			playIcon:setStyle('play')
		end
	end
end


-----------------------------------------------------------------------------------------
-- Settings
--

function _goHomeAction(self)
	appletManager:callService("goHome")
	return EVENT_CONSUME
end


function _installListeners(self, window)

	window:addListener(EVENT_WINDOW_ACTIVE,
		function(event)
			self:_updateAll(self)
			return EVENT_UNUSED
		end
	)

	local playlistSize = self.player and self.player:getPlaylistSize()

	local showPlaylistAction = function (self)
		window:playSound("WINDOWSHOW")
	
		if playlistSize == 1 then
			-- use special showTrackOne method from SlimBrowser
			appletManager:callService("showTrackOne")
		else
			-- show playlist
			appletManager:callService("showPlaylist")
		end
		
		return EVENT_CONSUME
	
	end

	window:addActionListener("go", self, showPlaylistAction)
	window:addActionListener("go_home", self, _goHomeAction)
	--also, no longer listening for hold in this situation, Ben and I felt that was a bug
	
end

function _setPlayerVolume(self, value)
	self.lastVolumeSliderAdjustT = Framework:getTicks()
	if value ~= self.volumeOld then
		self.player:volume(value, true)
		self.volumeOld = value
	end
end


function adjustVolume(self, value, useRateLimit)
	--volumeRateLimitTimer catches stops in fast slides, so that the "stopped on" value is not missed
	if not self.volumeRateLimitTimer then
		self.volumeRateLimitTimer = Timer(100,
						function()
							if not self.player then
								return
							end
							if self.volumeAfterRateLimit then
								self:_setPlayerVolume(self.volumeAfterRateLimit)
							end

						end, true)
	end
	if self.player then
		--rate limiting since these are serial networks calls
		local now = Framework:getTicks()
		if not useRateLimit or now > 350 + self.lastVolumeSliderAdjustT then
			self.volumeRateLimitTimer:restart()
			self:_setPlayerVolume(value)
			self.volumeAfterRateLimit = nil
		else
			--save value
			self.volumeAfterRateLimit = value

		end
	end
end

----------------------------------------------------------------------------------------
-- Screen Saver Display 
--

function _createUI(self)
	--local window = Window("text_list")
	if not self.windowStyle then
		self.windowStyle = 'nowplaying'
	end
	local window = Window(self.windowStyle)

       	local customStyle = self:getSettings()["screensaverArtworkSize"]

	local playerStatus = self.player:getPlayerStatus()
	if playerStatus then
		if not playerStatus.duration then
			showProgressBar = false
		else
			showProgressBar = true
		end
	end

	self.mainTitle = self:string("SCREENSAVER_NOWPLAYING")

	self.titleGroup = Group('title', {
		lbutton = window:createDefaultLeftButton(),

		text = Label("text", self:_titleText(self.mainTitle)),

		rbutton = Button(
				Group("button_playlist", { Icon("icon") }), 
				function() 
					Framework:pushAction("go") -- go action must work (as ir right and controller go must work also) 
					return EVENT_CONSUME 
				end,
				function()
					Framework:pushAction("title_right_hold")
					return EVENT_CONSUME
				end,
				function()
					Framework:pushAction("soft_reset")
					return EVENT_CONSUME
				end

		),
	   })
	

		self.trackTitle  = Label('nptrack', "")
		self.albumTitle  = Label('npalbum', "")
		self.artistTitle = Label('npartist', "")

	if not self.gotoTimer then
		self.gotoTimer = Timer(400,
			function()
				if self.gotoElapsed then
					self.player:gototime(self.gotoElapsed)
					self.gotoElapsed = nil
				end
			end,
			true)
	end
	
	self.progressSlider = Slider('npprogressB', 0, 100, 0,
		function(slider, value, done)
			self.gotoElapsed = value
			self.gotoTimer:restart()
		end)
	self.progressSlider:addTimer(1000, function() self:_updatePosition() end)

	self.progressBarGroup = Group('npprogress', {
			      elapsed = Label("elapsed", ""),
			      slider = self.progressSlider,
			      remain = Label("remain", "")
		      })
	self.progressBarGroup:addTimer(1000, function() self:_updatePosition() end)

	self.progressNBGroup = Group('npprogressNB', {
		      elapsed = Label("elapsed", "")
	})
	self.progressNBGroup:addTimer(1000, function() self:_updatePosition() end)

	if showProgressBar then
		self.progressGroup = self.progressBarGroup
	else
		self.progressGroup = self.progressNBGroup
	end

	self.artwork = Icon("artwork")

	self.artworkGroup = Group('npartwork', {
			artwork = self.artwork,
	})

	local playIcon = Button(Icon('play'),
				function() 
					Framework:pushAction("pause")
					return EVENT_CONSUME
				end,
				function()
					Framework:pushAction("stop")
					return EVENT_CONSUME
				end
			)
	if playerStatus and playerStatus.mode == 'play' then
		playIcon:setStyle('pause')
	end

	local repeatIcon = Button(Icon('repeatMode'),
				function() 
					Framework:pushAction("repeat_toggle")
				return EVENT_CONSUME 
			end
			)
	local shuffleIcon = Button(Icon('shuffleMode'),
				function() 
					Framework:pushAction("shuffle_toggle")
				return EVENT_CONSUME 
			end
			)

	--todo: this slider is not applicable for Jive, how do we handle this when on the controller
	self.volSlider = Slider('npvolumeB', 0, 100, 0,
			function(slider, value, done)
				--rate limiting since these are serial networks calls
				adjustVolume(self, value, true)
				self.volumeSliderDragInProgress = true
			end,
			function(slider, value, done)
				--called after a drag completes to insure final value not missed by rate limiting
				self.volumeSliderDragInProgress = false

				adjustVolume(self, value, false)
			end)
	self.volSlider.jumpOnDown = false
	self.volSlider.dragThreshold = 5
	window:addActionListener("page_down", self,
				function()
					local e = Event:new(EVENT_SCROLL, 1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)
	window:addActionListener("page_up", self,
				function()
					local e = Event:new(EVENT_SCROLL, -1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)
	self.volSlider:addTimer(1000,
				function()
					if not self.volumeSliderDragInProgress then
						self:_updateVolume()
					end
				end)

	self.rewButton = Button(
			Icon('rew'),
			function()
				Framework:pushAction("jump_rew")
				return EVENT_CONSUME 
			end
	)
	self.fwdButton = Button(
			Icon('fwd'),
			function() 
				Framework:pushAction("jump_fwd")
				return EVENT_CONSUME
			end
	)
	
	self.controlsGroup = Group('npcontrols', {
			div1 = Icon('div1'),
			div2 = Icon('div2'),
			div3 = Icon('div3'),
			div4 = Icon('div4'),
			div5 = Icon('div5'),
			div6 = Icon('div6'),
			div7 = Icon('div7'),

		  	rew  = self.rewButton,
		  	play = playIcon,
			fwd  = self.fwdButton,

			repeatMode  = repeatIcon,
			shuffleMode = shuffleIcon,

		  	volDown  = Button(
				Icon('volDown'),
				function()
					local e = Event:new(EVENT_SCROLL, -3)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end
			),
 		  	volUp  = Button(
				Icon('volUp'),
				function() 
					local e = Event:new(EVENT_SCROLL, 3)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end
			),
 			volSlider = self.volSlider,
	})

	self.preartwork = Icon("artwork") -- not disabled, used for preloading

	window:addWidget(self.titleGroup)
	window:addWidget(self.trackTitle)
	window:addWidget(self.albumTitle)
	window:addWidget(self.artistTitle)
	window:addWidget(self.artworkGroup)
	window:addWidget(self.controlsGroup)
	window:addWidget(self.progressGroup)

	window:focusWidget(self.trackTitle)

	-- register window as a screensaver, unless we are explicitly not in that mode
	if self.isScreensaver then
		local manager = appletManager:getAppletInstance("ScreenSavers")
		manager:screensaverWindow(window)
	end

	-- install some listeners to the window
	self:_installListeners(window)

	return window
end

-- wrapper method to allow showNowPlaying to remain as named so the "screensaver" 
-- can be found by the Screensaver applet correctly,
-- while allowing the method to be called via the service API
function goNowPlaying(self, transition)

	if not self.player then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	if self.player then
		self.isScreensaver = false
		self:showNowPlaying(transition)
		return true
	else
		return false

	end
end

function openScreensaver(self)
	--bug 12002 - don't really go into SS mode with NP ever. TODO: if this idea stickes, remove SS vs NON-SS mode code
	appletManager:callService("deactivateScreensaver") -- not needed currently, but is defensive if other cleanup gets added to deactivateScreensaver
	appletManager:callService("restartScreenSaverTimer")

	self:showNowPlaying()

	return false
end

function displaySizeSetting(self, menuItem)

	local window  = Window("text_list", menuItem.text, 'settingstitle')
        local group   = RadioGroup()
        local current = self:getSettings()["screensaverArtworkSize"]

	window:addWidget(
		SimpleMenu(
			"menu",
				{
					{
						text  = self:string("SCREENSAVER_ARTWORK_SMALL"),
						sound = "WINDOWSHOW",
						style = 'item_choice',
						check = RadioButton(
								"radio", 
								group, 
								function(event, menuItem)
									self:setArtworkSize("browse")
								end,
								current == 'browse')
					},
					{
						text  = self:string("SCREENSAVER_ARTWORK_MEDIUM"),
						sound = "WINDOWSHOW",
						style = 'item_choice',
						check = RadioButton(
								"radio", 
								group, 
								function(event, menuItem)
									self:setArtworkSize("ss")
								end,
								current == 'ss')
					},
					{
						text  = self:string("SCREENSAVER_ARTWORK_LARGE"),
						sound = "WINDOWSHOW",
						style = 'item_choice',
						check = RadioButton(
								"radio", 
								group, 
								function(event, menuItem)
									self:setArtworkSize("large")
								end,
								current == 'large')
					},
				}
		)
	)

        self:tieAndShowWindow(window)
        return window
end

function setArtworkSize(self, size)
	self:getSettings()['screensaverArtworkSize'] = size
	self:storeSettings()
end

function showNowPlaying(self, transition)

	local windowStyle
	if Framework:isCurrentWindow(self.window) then
		log:debug('NP already on screen')

		-- restart the screensaver timer if we hit this clause
		appletManager:callService("restartScreenSaverTimer")

		if appletManager:callService("isScreensaverActive") then
			--In rare circumstances, SS might not have been deactivated yet, so we force it closed
			log:debug("SS was active")
			appletManager:callService("deactivateScreensaver")
			--SS window removed, so continue with building a new window
			windowStyle = 'nowplaying'
		else
			--no need to switch to SS window
			windowStyle = 'nowplayingSS'
			return
		end
	end

	-- if we're opening this after freeing the applet, grab the player again
	if not self.player then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	local playerStatus = self.player and self.player:getPlayerStatus()

	log:debug("player=", self.player, " status=", playerStatus)

	-- playlist_tracks needs to be > 0 or else defer back to SlimBrowser
	if not self.player or not playerStatus 
			or not playerStatus.playlist_tracks then
		local browser = appletManager:getAppletInstance("SlimBrowser")
		browser:showPlaylist()
		return
	end


	-- this is to show the window to be opened in one of three modes: 
	-- browse, ss, and large (i.e., small med & large)

	--convenience
	local _thisTrack
	if playerStatus.item_loop then
		_thisTrack = playerStatus.item_loop[1]
	end

	if not transition then
		transition = Window.transitionFadeIn
	end

	self.window = _createUI(self)

	self.player = appletManager:callService("getCurrentPlayer")

	local transitionOn = transition

	if not self.player then
		-- No current player - don't start screensaver
		return
	end

	-- if we have data, then update and display it
	if _thisTrack then
		local trackInfo = self:_extractTrackInfo(_thisTrack)

		if playerStatus.remote == 1 and type(playerStatus.current_title) == 'string' and type(trackInfo) == 'string' then
			trackInfo = trackInfo .. "\n" .. playerStatus.current_title
		end

		_getIcon(self, _thisTrack, self.artwork, playerStatus.remote)
		self:_updateMode(playerStatus.mode)
		self:_updateTrack(trackInfo)
		self:_updateProgress(playerStatus)
		self:_updatePlaylist(true, playerStatus.playlist_cur_index, playerStatus.playlist_tracks)

		-- preload artwork for next track
		if playerStatus.item_loop[2] then
			_getIcon(self, playerStatus.item_loop[2], Icon("artwork"), playerStatus.remote)
		end

	-- otherwise punt
	else
		-- FIXME: we should probably exit the window when there's no track to display
		_getIcon(self, nil, playerStatus.artwork, nil) 
		self:_updateTrack("\n\n\n")
		self:_updateMode(playerStatus.mode)
		self:_updatePlaylist(false, 0, 0)	
	end

	self:_updateVolume()
	self:_updateRepeat(playerStatus['playlist repeat'])
	self:_updateShuffle(playerStatus['playlist shuffle'])
	self.volumeOld = tonumber(self.player:getVolume())

	-- Initialize with current data from Player
	self.window:show(transitionOn)
	self:_updateAll(self)

end


-- internal method to decide if track information is from the 'text' field or from 'track', 'artist', and 'album'
-- if it has the three fields, return a table
-- otherwise return a string
function _extractTrackInfo(self, _track)
	if _track.track then
		local returnTable = {}
		table.insert(returnTable, _track.track)
		table.insert(returnTable, _track.artist)
		table.insert(returnTable, _track.album)
		return returnTable
	else
		return _track.text or "\n\n\n"
	end
end

function freeAndClear(self)
	self.player = false
	jiveMain:removeItemById('appletNowPlaying')
	self:free()

end

function free(self)
	-- when we leave NowPlaying, ditch the window
	-- the screen can get loaded with two layouts, and by doing this
	-- we force the recreation of the UI when re-entering the screen, possibly in a different mode
	log:debug(self.player)

	-- player has left the building, close Now Playing browse window
	if self.window then
		self.window:hide()
	end

	return true
end


