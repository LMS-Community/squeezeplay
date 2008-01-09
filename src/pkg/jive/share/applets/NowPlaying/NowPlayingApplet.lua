local pairs, ipairs, tostring, type, setmetatable, tonumber = pairs, ipairs, tostring, type, setmetatable, tonumber

local math             = require("math")
local table            = require("table")
local string	       = require("string")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
local Framework        = require("jive.ui.Framework")
local Icon             = require("jive.ui.Icon")
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


local WH_FILL                = jive.ui.WH_FILL
local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

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
local KEY_GO                 = jive.ui.KEY_GO
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
local jnt                    = jnt

module(...)
oo.class(_M, Applet)

-- with drop shadow
--local ARTWORK_SIZE = 154
-- without drop shadow
local ARTWORK_SIZE = 166

local showProgressBar = true

----------------------------------------------------------------------------------------
-- Helper Functions
--

local windowStyle

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

local function _nowPlayingArtworkThumbUri(iconId)
        return '/music/' .. iconId .. '/cover_' .. ARTWORK_SIZE .. 'x' .. ARTWORK_SIZE .. '_p.png'
end

local function _staticArtworkThumbUri(path)
	local resizedImg = path
	-- 'p' is for padded, png gives us transparency
	local resizeFrag = '_' .. ARTWORK_SIZE .. 'x' .. ARTWORK_SIZE .. '_p.png' 
	local artworkUri = path
	-- replace .png with the resize params
	if string.match(path, '.png') then
                artworkUri = string.gsub(path, '.png', resizeFrag)
	end
	return artworkUri
end

local function SecondsToString(seconds)
	local min = math.floor(seconds / 60)
	local sec = math.floor(seconds - (min*60))

	return string.format("%d:%02d", min, sec)
end

local function _getIcon(self, item, icon, remote)
	local server = self.player:getSlimServer()

	if windowStyle == 'ss' then
		-- without drop shadow
		ARTWORK_SIZE = 186
		-- with drop shadow
		--ARTWORK_SIZE = 172
	else
		-- without drop shadow
		ARTWORK_SIZE = 166
		-- with drop shadow
		--ARTWORK_SIZE = 154
	end

	if item and item["icon-id"] then
		-- Fetch an image from SlimServer
		server:fetchArtworkThumb(item["icon-id"], icon, _nowPlayingArtworkThumbUri, ARTWORK_SIZE) 
	elseif item and item["icon"] then
		-- Fetch a remote image URL, sized to ARTWORK_SIZE x ARTWORK_SIZE
		local remoteContent = string.find(item['icon'], 'http://')
		-- sometimes this is static content
		if remoteContent then
			server:fetchArtworkURL(item["icon"], icon, ARTWORK_SIZE)
		else
			server:fetchArtworkThumb(item["icon"], icon, _staticArtworkThumbUri, ARTWORK_SIZE) 
		end
	elseif item and item["params"] and item["params"]["track_id"] then
		-- this is for the radio image-- remote URLs with no icon (Bug 6087)
		server:fetchArtworkThumb(item["params"]["track_id"], icon, _nowPlayingArtworkThumbUri, ARTWORK_SIZE) 
	elseif icon then
		icon:setValue(nil)
	end
end


function init(self)

	jnt:subscribe(self)
	self.player = {}
	self.player.playerStatus = {}
	self['browse'] = {}
	self['ss'] = {}

end

function notify_playerTrackChange(self, player, nowPlaying)
	log:warn("PLAYER TRACK NOTIFICATION RECEIVED")

	local thisPlayer = _isThisPlayer(self, player)
	if not thisPlayer then return end

	self.player = player
	-- make sure we've got the playerStatus data
	self.player.playerStatus = player:getPlayerStatus()

	-- if windowStyle hasn't been initialized yet, skip this
	if windowStyle then
		if not self[windowStyle] then self[windowStyle] = {} end

		-- create the window to display
		local window = _createUI(self)
		if self[windowStyle].window then
			window:replace(self[windowStyle].window, Window.transitionFadeIn)
		end
		self[windowStyle].window = window

	        if player.playerStatus and player.playerStatus.item_loop
			and self.nowPlaying ~= nowPlaying
		then
			-- for remote streams, nowPlaying = text
			-- for local music, nowPlaying = track_id
			self.nowPlaying = nowPlaying
	
			--update everything
			self:_updateAll(player.playerStatus, self[windowStyle])

		end
	end
end

function notify_playerModeChange(self, player, mode)

	if not self.player then return end

	log:debug("Player mode has been changed to: ", mode)

	self.player.mode = mode
	self.player.playerStatus = self.player:getPlayerStatus()

	self:_updateMode(mode)

end

function notify_playerCurrent(self, player)

	if self.player ~= player then
		self:free()
	end

	self.player = player
	self.player.playerStatus = self.player:getPlayerStatus()

	windowStyle = 'ss'

	jiveMain:addItem( 
		{
			id = 'appletNowPlaying',
			node = 'home',
			text = self:string('SCREENSAVER_NOWPLAYING'),
			sound = 'WINDOWSHOW',
			weight = 1,
			callback = function(event, menuItem)
				self:showNowPlaying('browse')
			end
		}
	)

end

function _isThisPlayer(self, player)

	if not self.player then
		local discovery = appletManager:getAppletInstance("SlimDiscovery")
		self.player = discovery:getCurrentPlayer()
	end

	if player.id ~= self.player.id then
		log:warn("notification was not for this player")
		log:warn("notification: ", player.id, "your player: ", self.player.id)
		return false
	else
		return true
	end
	
end

function _updateAll(self, playerStatus, ws)

	if not ws then ws = self[windowStyle] end
	if not ws then return end

	if not playerStatus then 
		playerStatus = self.player.playerStatus 
	end
	-- unlikely we'll ever hit this, but it can't hurt
	if self.player and not playerStatus then
		playerStatus = self.player:getPlayerStatus()
	end

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
	ws.trackGroup:setWidgetValue("text", trackinfo);
end

function _updateProgress(self, data, ws)
	if not ws then ws = self[windowStyle] end

	if not self.player then
		return
	end
	if not self.player.playerStatus then
		self.player.playerStatus = self.player:getPlayerStatus()
	end

	self.player.trackPos = tonumber(data.time)
	self.player.trackLen = tonumber(data.duration)

	if self.player and self.player.playerStatus and self.player.mode == 'play' then
		self.player.trackPos = self.player:getTrackElapsed(data)
	end

	if ws.progressSlider then
		if self.player.trackLen and self.player.trackLen > 0 then
			ws.progressSlider:setRange(0, self.player.trackLen, self.player.trackPos)
		else 
			-- If 0 just set it to 100
			ws.progressSlider:setRange(0, 100, 0)
		end
	end

	_updatePosition(self, ws)

end

function _updatePosition(self)

	if not ws then ws = self[windowStyle] end
	if not self.player then return end

	local strElapsed = ""
	local strRemain = ""
	local pos = 0

	if self.player.trackPos then
		strElapsed = SecondsToString(self.player.trackPos)
	end

	if self.player.trackLen and self.player.trackLen > 0 then
		strRemain = "-" .. SecondsToString(self.player.trackLen - self.player.trackPos)
		pos = self.player.trackPos
	end

	self[windowStyle].progressGroup:setWidgetValue("elapsed", strElapsed)
	if showProgressBar then
		self[windowStyle].progressGroup:setWidgetValue("remain", strRemain)
		self[windowStyle].progressSlider:setValue(pos)
	end
end


function _updatePlaylist(self, enabled, nr, count, ws)
	if not ws then ws = self[windowStyle] end
	if enabled == true and count > 1 then
		nr = nr + 1
		ws.titleGroup:setWidgetValue("playlist", self:string("SCREENSAVER_NOWPLAYING_OF", nr, count))
	else 
		ws.titleGroup:setWidgetValue("playlist", "")
	end
end

function _updateMode(self, mode, ws)
	if not ws then ws = self[windowStyle] end
	if not ws then return end
	if ws.titleGroup then
		if mode == "play" then
			ws.titleGroup:setWidgetValue("title", self:string("SCREENSAVER_NOWPLAYING"))
		elseif mode == "pause" then
			ws.titleGroup:setWidgetValue("title", self:string("SCREENSAVER_PAUSED"))
		else
			ws.titleGroup:setWidgetValue("title", self:string("SCREENSAVER_STOPPED"))
		end
	end
end

function tick(self)
	if self.player.mode ~= "play" then
		return
	end

	self.player.trackPos = self.player.trackPos + 1
	if self.player.trackLen and self.player.trackLen > 0 then
		if self.player.trackPos > self.player.trackLen then self.player.trackPos = self.player.trackLen end
	end

	_updatePosition(self)
end

-----------------------------------------------------------------------------------------
-- Settings
--
function openSettings(self, menuItem)
	local window = Window("Now Playing Settings")

	self:tieAndShowWindow(window)
	return window
end


function _installListeners(self, window)

	self[windowStyle].windowActiveListener = window:addListener(
		EVENT_WINDOW_ACTIVE,
		function(event)
			local stack = Framework.windowStack
			if self['browse'].window == stack[1] then
				windowStyle = 'browse'
			elseif self['ss'].window == stack[1] then
				windowStyle = 'ss'
			end

			self:_updateAll(self.player.playerStatus, self[windowStyle])

			return EVENT_UNUSED
		end
	)

	if windowStyle == 'browse' then
		local browser = appletManager:getAppletInstance("SlimBrowser")
		window:addListener(
			EVENT_KEY_PRESS | EVENT_KEY_HOLD,
			function(event)
				local type = event:getType()
				local keyPress = event:getKeycode()
				if (keyPress == KEY_BACK) then
					-- back to Home
					window:hide(Window.transitionPushRight)
					return EVENT_CONSUME
				elseif (keyPress == KEY_GO) then
					browser:showPlaylist()
					return EVENT_CONSUME
				end
				return EVENT_UNUSED
			end
		)
	end
end

----------------------------------------------------------------------------------------
-- Screen Saver Display 
--

function _createUI(self)
	local window = Window("window")

	if windowStyle == 'ss' then
		local sw, sh = Framework:getScreenSize()
		local newBg = Framework:getBackground()
		local srf = Surface:newRGBA(sw, sh)
		newBg:blit(srf, 0, 0, sw, sh)
		window:addWidget(Icon("iconbg", srf))
	end

	if self.player.playerStatus then
		if not self.player.playerStatus.duration then
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
		npartwork = "npartwork" 
	}
	for k, v in pairs(components) do
		local new = windowStyle .. v
		components[k] = new
	end
	self[windowStyle].titleGroup = Group(components.nptitle, {
				   title = Label("text", self:string("SCREENSAVER_NOWPLAYING")),
				   playlist = Label("playlist", "")
			   })
	

	self[windowStyle].trackGroup = Group(components.nptrack, {
				   text = Label("text", "\n\n\n")
			   })
	
	
	if showProgressBar then
		self[windowStyle].progressSlider = Slider(components.progressB, 0, 100, 0)
		self[windowStyle].progressSlider:addTimer(1000, function() self:tick() end)

		self[windowStyle].progressGroup = Group(components.progress, {
					      elapsed = Label("text", ""),
					      slider = self[windowStyle].progressSlider,
					      remain = Label("text", "")
				      })
	else
		self[windowStyle].progressGroup = Group(components.progressNB, {
					      elapsed = Label("text", "")
				      })
		self[windowStyle].progressGroup:addTimer(1000, function() self:tick() end)
	end

	self[windowStyle].artwork = Icon("artwork")
	self[windowStyle].artworkGroup = Group(components.npartwork, {
				     artwork = self[windowStyle].artwork    
			     })
	
	self.preartwork = Icon("artwork") -- not disabled, used for preloading

	window:addWidget(self[windowStyle].titleGroup)
	window:addWidget(self[windowStyle].trackGroup)
	window:addWidget(self[windowStyle].artworkGroup)
	window:addWidget(self[windowStyle].progressGroup)

	window:focusWidget(self[windowStyle].trackGroup)
	-- register window as a screensaver, unless we are explicitly not in that mode
	if windowStyle == 'ss' then
		local manager = appletManager:getAppletInstance("ScreenSavers")
		manager:screensaverWindow(window)
	end

	self:tieWindow(window)
	return window
end


function showNowPlaying(self, style)

	-- an empty item_loop means an empty playlist
	if not self.player 
		or not self.player.playerStatus 
			or not self.player.playerStatus.item_loop then
		local browser = appletManager:getAppletInstance("SlimBrowser")
		browser:showPlaylist()
		self:free()
		return
	end
	-- this is to show the window to be opened in two modes: 
	-- ss and browse

	--convenience
	local _statusData = self.player.playerStatus
	local _thisTrack
	if _statusData.item_loop then
		_thisTrack = _statusData.item_loop[1]
	end

	if not style then style = 'ss' end

	windowStyle = style
	if not self[windowStyle] then self[windowStyle] = {} end

	log:debug("CREATING UI FOR NOWPLAYING")
	self[windowStyle].window = _createUI(self)

	local discovery = appletManager:getAppletInstance("SlimDiscovery")
	self.player = discovery:getCurrentPlayer()

	local transitionOn
	if style == 'ss' then
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
		if _statusData.remote == 1 and type(_statusData.current_title) == 'string' then
			text = text .. "\n" .. _statusData.current_title
		end

		_getIcon(self, _thisTrack, self[windowStyle].artwork, _statusData.remote)
		self:_updateMode(_statusData.mode)
		self:_updateTrack(text)
		self:_updateProgress(_statusData)
		self:_updatePlaylist(true, self.player.playerStatus.playlist_cur_index, self.player.playerStatus.playlist_tracks)

		-- preload artwork for next track
		if _statusData.item_loop[2] then
			_getIcon(self, _statusData.item_loop[2], Icon("artwork"), _statusData.remote)
		end

	-- otherwise punt
	else
		-- FIXME: we should probably exit the window when there's no track to display
		_getIcon(self, nil, self.player.playerStatus.artwork, nil) 
		self:_updateTrack("\n\n\n")
		self:_updateMode(_statusData.mode)
		self:_updatePlaylist(false, 0, 0)	
	end

	-- Initialize with current data from Player
	self[windowStyle].window:show(transitionOn)
	-- install some listeners to the window after it's shown
	self:_installListeners(self[windowStyle].window)
	self:_updateAll(self.player.playerStatus, self[windowStyle])

end

function free(self)
	-- when we leave NowPlaying, ditch the window
	-- the screen can get loaded with two layouts, and by doing this
	-- we force the recreation of the UI when re-entering the screen, possibly in a different mode
	log:warn("NowPlaying.free()")
	self.player = false
	if self['ss'] then
		self['ss'] = nil
	end
	if self['browse'] then
		self['browse'] = nil
	end
end


function skin(self, s)

	-- this skin is established in two forms,
	-- one for the Screensaver windowStyle (ss), one for the browse windowStyle (browse)
	-- a lot of it can be recycled from one to the other

	local imgpath = "applets/DefaultSkin/images/"
	local npimgpath = "applets/NowPlaying/"
	local fontpath = "fonts/"

	local screenWidth, screenHeight = Framework:getScreenSize()

        local titleBox =
                Tile:loadTiles({
                                       imgpath .. "titlebox.png",
                                       imgpath .. "titlebox_tl.png",
                                       imgpath .. "titlebox_t.png",
                                       imgpath .. "titlebox_tr.png",
                                       imgpath .. "titlebox_r.png",
                                       imgpath .. "bghighlight_tr.png",
                                       imgpath .. "titlebox_b.png",
                                       imgpath .. "bghighlight_tl.png",
                                       imgpath .. "titlebox_l.png"
                               })

        local highlightBox =
                Tile:loadTiles({
                                       imgpath .. "bghighlight.png",
                                       nil,
                                       nil,
                                       nil,
                                       imgpath .. "bghighlight_r.png",
                                       imgpath .. "bghighlight_br.png",
                                       imgpath .. "bghighlight_b.png",
                                       imgpath .. "bghighlight_bl.png",
                                       imgpath .. "bghighlight_l.png"
                               })

	-- Title
	s.ssnptitle = {}
	s.ssnptitle.border = { 4, 4, 4, 0 }
	s.ssnptitle.position = LAYOUT_NORTH
	s.ssnptitle.bgImg = titleBox
	s.ssnptitle.order = { "title", "playlist" }
	s.ssnptitle.text = {}
	s.ssnptitle.text.w = WH_FILL
	s.ssnptitle.text.padding = { 10, 7, 8, 9 }
	s.ssnptitle.text.align = "top-left"
	s.ssnptitle.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	s.ssnptitle.text.fg = { 0x00, 0x00, 0x00 }
	s.ssnptitle.playlist = {}
	s.ssnptitle.playlist.padding = { 10, 7, 8, 9 }
	s.ssnptitle.playlist.font = Font:load(fontpath .. "FreeSans.ttf", 15)
	s.ssnptitle.playlist.fg = { 0x00, 0x00, 0x00 }
	s.ssnptitle.playlist.textAlign = "top-right"


	-- nptitle style is the same for both windowStyles
	s.browsenptitle = _uses(s.ssnptitle, browsenptitle)

	-- Song
	s.ssnptrack = {}
	s.ssnptrack.border = { 4, 0, 4, 0 }
        s.ssnptrack.bgImg = highlightBox
	s.ssnptrack.text = {}
	s.ssnptrack.text.w = WH_FILL
	s.ssnptrack.text.padding = { 8, 7, 8, 2 }
	s.ssnptrack.text.align = "top-left"
        s.ssnptrack.text.font = Font:load(fontpath .. "FreeSans.ttf", 14)
	s.ssnptrack.text.lineHeight = 17
        s.ssnptrack.text.line = {
		{
			font = Font:load(fontpath .. "FreeSansBold.ttf", 14),
			height = 17
		}
	}
	s.ssnptrack.text.fg = { 0x00, 0x00, 0x00 }

	-- nptrack is identical between the two windowStyles
	s.browsenptrack = _uses(s.ssnptrack)

	-- Artwork
	local browseArtWidth = 166
	local ssArtWidth = 186

	local ssnoartworkoffset = (screenWidth - ssArtWidth) / 2
	s.ssnpartwork = {}
	s.ssnpartwork.w = ssArtWidth
	s.ssnpartwork.border = { ssnoartworkoffset, 4, ssnoartworkoffset, 6 }
	s.ssnpartwork.align = "bottom-right"
--	s.ssnpartwork.bgImg = Tile:loadImage(imgpath .. "album_shadow_" .. ssArtWidth .. ".png")
	s.ssnpartwork.artwork = {}
	s.ssnpartwork.artwork.padding = 1 
	s.ssnpartwork.artwork.img = Surface:loadImage(imgpath .. "album_noartwork_" .. ssArtWidth .. ".png")

	-- artwork layout is not the same between the two windowStyles
	local browsenoartworkoffset = (screenWidth - browseArtWidth) / 2
	local browsenpartwork = {
		w = browseArtWidth,
		border = { browsenoartworkoffset, 4, browsenoartworkoffset, 6 },
		--bgImg = Tile:loadImage(imgpath .. "album_shadow_" .. browseArtWidth .. ".png"),
		artwork = { padding = 1, img = Surface:loadImage(imgpath .. "album_noartwork_" .. browseArtWidth .. ".png") }
	}
	s.browsenpartwork = _uses(s.ssnpartwork, browsenpartwork)

	-- Progress bar
        local progressBackground =
                Tile:loadHTiles({
                                        npimgpath .. "progressbar_bkgrd_l.png",
                                        npimgpath .. "progressbar_bkgrd.png",
                                        npimgpath .. "progressbar_bkgrd_r.png",
                               })

        local progressBar =
                Tile:loadHTiles({
                                        npimgpath .. "progressbar_fill_l.png",
                                        npimgpath .. "progressbar_fill.png",
                                        npimgpath .. "progressbar_fill_r.png",
                               })

	s.ssprogress = {}
	s.ssprogress.order = { "elapsed", "slider", "remain" }
	s.ssprogress.text = {}
	s.ssprogress.text.w = 50
	s.ssprogress.padding = { 0, 0, 0, 0 }
	s.ssprogress.text.padding = { 8, 0, 8, 0 }
	s.ssprogress.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.ssprogress.text.fg = { 0xe7,0xe7, 0xe7 }
	s.ssprogress.text.sh = { 0x37, 0x37, 0x37 }

	-- browse has different positioning than ss windowStyle
	local browseprogress = {
		padding = { 0, 0, 0, 0 } 
	}
	s.browseprogress = _uses(s.ssprogress)

	s.ssprogressB             = {}
        s.ssprogressB.horizontal  = 1
        s.ssprogressB.bgImg       = progressBackground
        s.ssprogressB.img         = progressBar

	s.browseprogressB = _uses(s.ssprogressB)

	-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
	s.ssprogressNB = {}
	s.ssprogressNB.order = { "elapsed" }
	s.ssprogressNB.text = {}
	s.ssprogressNB.text.w = WH_FILL
	s.ssprogressNB.text.align = "center"
	s.ssprogressNB.padding = { 0, 0, 0, 0 }
	s.ssprogressNB.text.padding = { 0, 0, 0, 0 }
	s.ssprogressNB.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.ssprogressNB.text.fg = { 0xe7, 0xe7, 0xe7 }
	s.ssprogressNB.text.sh = { 0x37, 0x37, 0x37 }

	s.browseprogressNB = _uses(s.ssprogressNB)

-- background style should start at x,y = 0,0
        s.iconbg = {}
        s.iconbg.x = 0
        s.iconbg.y = 0
        s.iconbg.h = screenHeight
        s.iconbg.w = screenWidth
	s.iconbg.border = { 0, 0, 0, 0 }
	s.iconbg.position = LAYOUT_NONE
end


