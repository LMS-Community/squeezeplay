local pairs, ipairs, tostring, type, setmetatable, tonumber = pairs, ipairs, tostring, type, setmetatable, tonumber

local math             = require("math")
local table            = require("table")
local string	       = require("string")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
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
                       
local log              = require("jive.utils.log").logger("applets.screensavers")
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
	
----------------------------------------------------------------------------------------
-- Helper Functions
--

local windowStyle
local customStyle = 'ss'

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

	if windowStyle == 'browse' or ( windowStyle == 'ss' and customStyle == 'browse' ) then
		ARTWORK_SIZE = jiveMain:getSkinParam("nowPlayingBrowseArtworkSize")
	else
		if customStyle == 'ss' then
			ARTWORK_SIZE = jiveMain:getSkinParam("nowPlayingSSArtworkSize")
		elseif customStyle == 'large' then
			ARTWORK_SIZE = jiveMain:getSkinParam("nowPlayingLargeArtworkSize")
		end
	end

	if item and item["icon-id"] then
		-- Fetch an image from SlimServer
		server:fetchArtworkThumb(item["icon-id"], icon, ARTWORK_SIZE) 
	elseif item and item["icon"] then
		-- Fetch a remote image URL, sized to ARTWORK_SIZE x ARTWORK_SIZE
		local remoteContent = string.find(item['icon'], 'http://')
		-- sometimes this is static content
		if remoteContent then
			server:fetchArtworkURL(item["icon"], icon, ARTWORK_SIZE)
		else
			if server:isSqueezeNetwork() then
				-- Artwork on SN must be fetched as a normal URL
				local ip, port = server:getIpPort()
				
				-- Bug 7123, Add a leading slash if needed
				if not string.find(item["icon"], "^/") then
					item["icon"] = "/" .. item["icon"]
				end
				
				item["icon"] = 'http://' .. ip .. ':' .. port .. item["icon"]
				server:fetchArtworkURL(item["icon"], icon, ARTWORK_SIZE)
			else
				server:fetchArtworkThumb(item["icon"], icon, ARTWORK_SIZE)
			end
		end
	elseif item and item["params"] and item["params"]["track_id"] then
		-- this is for placeholder artwork, either for local tracks or radio streams with no art
		server:fetchArtworkThumb(item["params"]["track_id"], icon, ARTWORK_SIZE, 'png') 
	elseif icon then
		icon:setValue(nil)
	end
end


function init(self)

	jnt:subscribe(self)
	self.player = false
	self['browse'] = {}
	self['ss'] = {}

end

function notify_playerPower(self, player, power)
	if player ~= self.player then
		return
	end

	local mode = self.player:getPlayMode()

	-- hide this window if the player is turned off
	if not power then
		if self['browse'] and self['browse'].window then
			self['browse'].titleGroup:setWidgetValue("text", self:string(modeTokens['off']))
		end
		if self['ss'] and self['ss'].window then
			self['ss'].titleGroup:setWidgetValue("text", self:string(modeTokens['off']))
		end
	else
		if self['browse'] and self['browse'].window then
			self['browse'].titleGroup:setWidgetValue("text", self:string(modeTokens[mode]))
		end
		if self['ss'] and self['ss'].window then
			self['ss'].titleGroup:setWidgetValue("text", self:string(modeTokens[mode]))
		end
	end
end


function notify_playerTrackChange(self, player, nowPlaying)
	log:info("Notification received that track has changed")

	local thisPlayer = _isThisPlayer(self, player)
	if not thisPlayer then return end

	self.player = player
	local playerStatus = player:getPlayerStatus()

	-- if windowStyle hasn't been initialized yet, skip this
	if windowStyle then
		if not self[windowStyle] then self[windowStyle] = {} end

		-- create the window to display
		local window = _createUI(self)
		if self[windowStyle].window then
			window:replace(self[windowStyle].window, Window.transitionFadeIn)
		end
		self[windowStyle].window = window

	        if playerStatus and playerStatus.item_loop
			and self.nowPlaying ~= nowPlaying
		then
			-- for remote streams, nowPlaying = text
			-- for local music, nowPlaying = track_id
			self.nowPlaying = nowPlaying
	
			--update everything
			self:_updateAll(self[windowStyle])

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

	windowStyle = 'ss'

	jiveMain:addItem( 
		{
			id = 'appletNowPlaying',
			node = 'home',
			text = self:string('SCREENSAVER_NOWPLAYING'),
			sound = 'WINDOWSHOW',
			weight = 1,
			callback = function(event, menuItem)
				self:openScreensaver('browse')
			end
		}
	)

end

function _isThisPlayer(self, player)

	if not self.player and not self.player:getId() then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	if player:getId() ~= self.player:getId() then
		log:info("notification was not for this player")
		log:info("notification: ", player:getId(), "your player: ", self.player:getId())
		return false
	else
		return true
	end
	
end

function _updateAll(self, ws)

	if not ws then ws = self[windowStyle] end
	if not ws then return end

	local playerStatus = self.player:getPlayerStatus()

	if playerStatus.item_loop then
		local text = playerStatus.item_loop[1].text
		local showProgressBar = true
		-- XXX: current_title of null is a function value??
		if playerStatus.remote == 1 and type(playerStatus.current_title) == 'string' then 
			text = text .. "\n" .. playerStatus.current_title
		end
		if playerStatus.time == 0 then
			showProgressBar = false
		end

		local item = playerStatus.item_loop[1]
	
		if ws and ws.window then
			_getIcon(self, item, ws.artwork, playerStatus.remote)

			self:_updateTrack(text, ws)
			self:_updateProgress(playerStatus, ws)
			self:_updatePlaylist(true, playerStatus.playlist_cur_index, playerStatus.playlist_tracks, ws)
		
			-- preload artwork for next track
			if playerStatus.item_loop[2] then
				_getIcon(self, playerStatus.item_loop[2], Icon("artwork"), playerStatus.remote)
			end
		end
	else
		if ws and ws.window then
			_getIcon(self, nil, ws.artwork, nil)
			self:_updateTrack("\n\n\n", ws)
			self:_updatePlaylist(false, 0, 0, ws)
		end
	end
end


function _updateTrack(self, trackinfo, pos, length, ws)
	if not ws then ws = self[windowStyle] end
	if ws.trackGroup then
		if customStyle == 'large' and 
			windowStyle == 'ss' and 
			jiveMain:getSelectedSkin() == 'DefaultSkin' then
				trackinfo = string.gsub(trackinfo, "\n", " - ")
		end
		ws.trackGroup:setWidgetValue("text", trackinfo);
	end
end

function _updateProgress(self, data, ws)
	if not ws then ws = self[windowStyle] end

	if not self.player then
		return
	end

	local elapsed, duration = self.player:getTrackElapsed()

	if ws.progressSlider then
		if duration and tonumber(duration) > 0 then
			ws.progressSlider:setRange(0, tonumber(duration), tonumber(elapsed))
		else 
			-- If 0 just set it to 100
			ws.progressSlider:setRange(0, 100, 0)
		end
	end

	_updatePosition(self, ws)

end

function _updatePosition(self)
	if not ws then ws = self[windowStyle] end
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

	if self[windowStyle].progressGroup then
		self[windowStyle].progressGroup:setWidgetValue("elapsed", strElapsed)
		if showProgressBar then
			self[windowStyle].progressGroup:setWidgetValue("remain", strRemain)
			self[windowStyle].progressSlider:setValue(elapsed)
		end
	end
end


function _updatePlaylist(self, enabled, nr, count, ws)
	if not ws then ws = self[windowStyle] end
	if enabled == true and count and tonumber(count) > 1 then
		nr = nr + 1
		ws.titleGroup:setWidgetValue("playlist", self:string("SCREENSAVER_NOWPLAYING_OF", nr, count))
	else 
		ws.titleGroup:setWidgetValue("playlist", "")
	end
end

function _updateMode(self, mode, ws)
	if not ws then 
		ws = self[windowStyle] 
	end

	if not ws then 
		return 
	end

	local token = mode
	-- sometimes there is a race condition here between updating player mode and power, 
	-- so only set the title to 'off' if the mode is also not 'play'
	if token != 'play' and not self.player:isPowerOn() then
		token = 'off'
	end
	if ws.titleGroup then
		ws.titleGroup:setWidgetValue("text", self:string(modeTokens[token]))
	end
	if ws.controlsGroup then
		local playIcon = ws.controlsGroup:getWidget('play')
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

	if windowStyle == 'browse' then
		window:addListener(EVENT_WINDOW_ACTIVE,
			function(event)
				windowStyle = 'browse'
				self:_updateAll(self[windowStyle])
				return EVENT_UNUSED
			end
		)
	end

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

----------------------------------------------------------------------------------------
-- Screen Saver Display 
--

function _createUI(self)
	local window = Window("window")

	customStyle = windowStyle
	if windowStyle == 'ss' then
        	customStyle = self:getSettings()["screensaverArtworkSize"]
		if customStyle ~= 'browse' then
			window:setShowFrameworkWidgets(false)
		end
	end

	local playerStatus = self.player:getPlayerStatus()
	if playerStatus then
		if not playerStatus.duration then
			showProgressBar = false
		else
			showProgressBar = true
		end
	end

	local components = { 
		nptitle = "nptitle", 
		nptrack = "nptrack", 
		progressB = "progressB", 
		progress = "progress", 
		progressNB = "progressNB",
		npartwork = "npartwork",
		npcontrols = 'npcontrols',
	}	

	for k, v in pairs(components) do
		local new = customStyle .. v
		components[k] = new
	end

	self[windowStyle].titleGroup = Group(components.nptitle, {
		back = Button(
				Icon("back"), 
				function() 
					Framework:pushAction("back")
					return EVENT_CONSUME 
					end,
					function()
						Framework:pushAction("go_home")
						return EVENT_CONSUME
				end
		),

		text = Label("text", self:string("SCREENSAVER_NOWPLAYING")),

		playlist = Button(
				Label("playlist", ""), 
				function() 
					Framework:pushAction("go")
					return EVENT_CONSUME 
				end
		),
	   })
	


	if customStyle == 'large' then

		self[windowStyle].trackGroup = Group(components.nptrack, {
			   text = Label("text", "")
		})
	else
		self[windowStyle].trackGroup = Group(components.nptrack, {
			   text = Label("text", "\n\n\n")
		})
	end

	if showProgressBar then
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
	
		self[windowStyle].progressSlider = Slider(components.progressB, 0, 100, 0,
			function(slider, value, done)
				self.gotoElapsed = value
				self.gotoTimer:restart()
			end)
		self[windowStyle].progressSlider:addTimer(1000, function() self:_updatePosition() end)

		self[windowStyle].progressGroup = Group(components.progress, {
				      elapsed = Label("elapsed", ""),
				      slider = self[windowStyle].progressSlider,
				      remain = Label("remain", "")
			      })
	else
		self[windowStyle].progressGroup = Group(components.progressNB, {
			      elapsed = Label("elapsed", "")
		})
		self[windowStyle].progressGroup:addTimer(1000, function() self:_updatePosition() end)
	end

	self[windowStyle].artwork = Icon("artwork")

	self[windowStyle].artworkGroup = Group(components.npartwork, {
			artwork = self[windowStyle].artwork,
	})

	local playIcon = Button(Icon('play'),
				function() 
					Framework:pushAction("pause")
				return EVENT_CONSUME 
			end
			)
	if playerStatus and playerStatus.mode == 'play' then
		playIcon:setStyle('pause')
	end

	self[windowStyle].controlsGroup = Group(components.npcontrols, {
		  	rew = Button(
				Icon('rew'),
				function()
					Framework:pushAction("jump_rew")
					return EVENT_CONSUME 
				end
			),
		  	play = playIcon,
		  	fwd  = Button(
				Icon('fwd'),
				function() 
					Framework:pushAction("jump_fwd")
					return EVENT_CONSUME
				end
			),
 	})

	self.preartwork = Icon("artwork") -- not disabled, used for preloading

	window:addWidget(self[windowStyle].titleGroup)
	window:addWidget(self[windowStyle].trackGroup)
	window:addWidget(self[windowStyle].artworkGroup)
	window:addWidget(self[windowStyle].controlsGroup)
	window:addWidget(self[windowStyle].progressGroup)

	window:focusWidget(self[windowStyle].trackGroup)

	-- register window as a screensaver, unless we are explicitly not in that mode
	if windowStyle == 'ss' then
		local manager = appletManager:getAppletInstance("ScreenSavers")
		manager:screensaverWindow(window)
	end

	-- install some listeners to the window
	self:_installListeners(window)

	return window
end

-- wrapper method to allow openScreensaver to remain as named so the "screensaver" 
-- can be found by the Screensaver applet correctly,
-- while allowing the method to be called via the service API
function goNowPlaying(self, style, transition)

	if not self.player then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	if self.player then
		self:openScreensaver(style, transition)
		return true
	else
		return false

	end
end

function displaySizeSetting(self, menuItem)

	local window  = Window("window", menuItem.text, 'settingstitle')
        local group   = RadioGroup()
        local current = self:getSettings()["screensaverArtworkSize"]

	window:addWidget(
		SimpleMenu(
			"menu",
				{
					{
						text  = self:string("SCREENSAVER_ARTWORK_SMALL"),
						sound = "WINDOWSHOW",
						icon = RadioButton(
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
						icon = RadioButton(
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
						icon = RadioButton(
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

function openScreensaver(self, style, transition)

	-- if we're opening this after freeing the applet, grab the player again
	if not self.player then
		self.player = appletManager:callService("getCurrentPlayer")
	end

	local playerStatus = self.player and self.player:getPlayerStatus()

	log:info("style=", style)
	log:info("player=", self.player, " status=", playerStatus)

	-- playlist_tracks needs to be > 0 or else defer back to SlimBrowser
	if not self.player or not playerStatus 
			or not playerStatus.playlist_tracks 
			or playerStatus.playlist_tracks == 0 then
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

	if not style then style = 'ss' end

	-- if opening the screensaver, then use the setting for screensaverArtworkSize
	if style == 'ss' then
		transition = Window.transitionFadeIn
	end

	windowStyle = style
	if not self[windowStyle] then self[windowStyle] = {} end

	self[windowStyle].window = _createUI(self)

	self.player = appletManager:callService("getCurrentPlayer")

	local transitionOn
	if transition then
		transitionOn = transition
	elseif style == 'ss' then
		transitionOn = Window.transitionFadeIn
	elseif style == 'browse' then
		transitionOn = Window.transitionPushLeft
	end

	if not self.player then
		-- No current player - don't start screensaver
		return
	end

	-- if we have data, then update and display it
	if _thisTrack then
		local text = _thisTrack.text
		if playerStatus.remote == 1 and type(playerStatus.current_title) == 'string' then
			text = text .. "\n" .. playerStatus.current_title
		end

		_getIcon(self, _thisTrack, self[windowStyle].artwork, playerStatus.remote)
		self:_updateMode(playerStatus.mode)
		self:_updateTrack(text)
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

	-- Initialize with current data from Player
	self[windowStyle].window:show(transitionOn)
	self:_updateAll(self[windowStyle])

end

function freeAndClear(self)
	self.player = false
	self['ss'] = nil
	self['browse'] = nil
	jiveMain:removeItemById('appletNowPlaying')
	self:free()

end

function free(self)
	-- when we leave NowPlaying, ditch the window
	-- the screen can get loaded with two layouts, and by doing this
	-- we force the recreation of the UI when re-entering the screen, possibly in a different mode
	log:info("NowPlaying.free()")
	log:info(self.player)

	-- player has left the building, close Now Playing browse window
	if self['browse'] and self['browse'].window then
		self['browse'].window:hide()
	end

	if self['ss'] and self['ss'].window then
		self['ss'].window:hide()
	end

	return true
end


