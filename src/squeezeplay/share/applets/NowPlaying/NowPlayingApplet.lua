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

local jiveMain               = jiveMain
local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

local ARTWORK_SIZE = 350

--local showProgressBar = true
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
	self.player = {}
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
			self['browse'].titleGroup:setWidgetValue("title", self:string(modeTokens['off']))
		end
		if self['ss'] and self['ss'].window then
			self['ss'].titleGroup:setWidgetValue("title", self:string(modeTokens['off']))
		end
	else
		if self['browse'] and self['browse'].window then
			self['browse'].titleGroup:setWidgetValue("title", self:string(modeTokens[mode]))
		end
		if self['ss'] and self['ss'].window then
			self['ss'].titleGroup:setWidgetValue("title", self:string(modeTokens[mode]))
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
			self:_installListeners(window)
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

	self:free()
end

-- players changed, add playing menu
function notify_playerCurrent(self, player)

	if self.player ~= player then
		self:free()
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
		log:warn("notification was not for this player")
		log:warn("notification: ", player:getId(), "your player: ", self.player:getId())
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
--		local showProgressBar = true
		-- XXX: current_title of null is a function value??
		if playerStatus.remote == 1 and type(playerStatus.current_title) == 'string' then 
			text = text .. "\n" .. playerStatus.current_title
		end
		if playerStatus.time == 0 then
--			showProgressBar = false
		end

		local item = playerStatus.item_loop[1]
	
		if ws and ws.window then
			_getIcon(self, item, ws.artwork, playerStatus.remote)

			self:_updateTrack(text, ws)
--			self:_updateProgress(playerStatus, ws)
		
			-- preload artwork for next track
			if playerStatus.item_loop[2] then
				_getIcon(self, playerStatus.item_loop[2], Icon("artwork"), playerStatus.remote)
			end
		end
	else
		if ws and ws.window then
			_getIcon(self, nil, ws.artwork, nil)
			self:_updateTrack("\n\n\n", ws)
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

--[[
	self[windowStyle].progressGroup:setWidgetValue("elapsed", strElapsed)
	if showProgressBar then
		self[windowStyle].progressGroup:setWidgetValue("remain", strRemain)
		self[windowStyle].progressSlider:setValue(elapsed)
	end
--]]
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
		ws.titleGroup:setWidgetValue("title", self:string(modeTokens[token]))
	end
end


-----------------------------------------------------------------------------------------
-- Settings
--
		
function _installListeners(self, window)

	self[windowStyle].listeners = {}
	self[windowStyle].listeners[1] = window:addListener(
		EVENT_WINDOW_ACTIVE,
		function(event)
			local stack = Framework.windowStack
			if self['browse'] and self['browse'].window == stack[1] then
				windowStyle = 'browse'
			elseif self['ss'] and self['ss'].window == stack[1] then
				windowStyle = 'ss'
			end

			self:_updateAll(self[windowStyle])

			return EVENT_UNUSED
		end
	)

	local playlistSize = self.player and self.player:getPlaylistSize()

	self[windowStyle].listeners[2] = window:addListener(
		EVENT_KEY_PRESS,
		function(event)
			local type = event:getType()
			local keyPress = event:getKeycode()
			if (keyPress == KEY_BACK and windowStyle == 'browse') then
				-- back to Home
				appletManager:callService("goHome")
				return EVENT_CONSUME

			elseif (keyPress == KEY_GO) then
				if playlistSize == 1 then
					-- use special showTrackOne method from SlimBrowser
					appletManager:callService("showTrackOne")
				else
					-- show playlist
					appletManager:callService("showPlaylist")
				end
				return EVENT_CONSUME
			end
			return EVENT_UNUSED
		end
	)
end

----------------------------------------------------------------------------------------
-- Screen Saver Display 
--

function _createUI(self)
	local window = Window("window")

	if windowStyle == 'ss' then
		window:setShowFrameworkWidgets(false)
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
		leftarrow = 'leftarrow',
		rightarrow = 'rightarrow',
--		progressB = "progressB", 
--		progress = "progress", 
--		progressNB = "progressNB",
		npartwork = "npartwork",
	}
	for k, v in pairs(components) do
		local new = windowStyle .. v
		components[k] = new
	end
	self[windowStyle].titleGroup = Group(components.nptitle, {
				   title = Label("text", self:string("SCREENSAVER_NOWPLAYING")),
			   })
	

	self[windowStyle].trackGroup = Group(components.nptrack, {
				   text = Label("text", "\n\n\n")
			   })
	
	self[windowStyle].leftArrow = Icon(components.leftarrow)
	self[windowStyle].rightArrow = Icon(components.rightarrow)


--[[
	if showProgressBar then
		self[windowStyle].progressSlider = Slider(components.progressB, 0, 100, 0)
		self[windowStyle].progressSlider:addTimer(1000, function() self:_updatePosition() end)

		self[windowStyle].progressGroup = Group(components.progress, {
					      elapsed = Label("text", ""),
					      slider = self[windowStyle].progressSlider,
					      remain = Label("text", "")
				      })
	else
		self[windowStyle].progressGroup = Group(components.progressNB, {
					      elapsed = Label("text", "")
				      })
	end

--]]
	self[windowStyle].artwork = Icon("artwork")
	self[windowStyle].artworkGroup = Group(components.npartwork, {
				     artwork = self[windowStyle].artwork    
			     })
	
	self.preartwork = Icon("artwork") -- not disabled, used for preloading

	window:addWidget(self[windowStyle].titleGroup)
	window:addWidget(self[windowStyle].trackGroup)
	window:addWidget(self[windowStyle].artworkGroup)
	window:addWidget(self[windowStyle].leftArrow)
	window:addWidget(self[windowStyle].rightArrow)
--	window:addWidget(self[windowStyle].progressGroup)

	window:focusWidget(self[windowStyle].trackGroup)
	-- register window as a screensaver, unless we are explicitly not in that mode
	if windowStyle == 'ss' then
		local manager = appletManager:getAppletInstance("ScreenSavers")
		manager:screensaverWindow(window)
	end

	return window
end


function openScreensaver(self, style, transition)

	local playerStatus = self.player and self.player:getPlayerStatus()

	log:info("player=", self.player, " status=", playerStatus)

	-- playlist_tracks needs to be > 0 or else defer back to SlimBrowser
	if not self.player or not playerStatus 
			or not playerStatus.playlist_tracks 
			or playerStatus.playlist_tracks == 0 then
		local browser = appletManager:getAppletInstance("SlimBrowser")
		browser:showPlaylist()
		return
	end
	-- this is to show the window to be opened in two modes: 
	-- ss and browse

	--convenience
	local _thisTrack
	if playerStatus.item_loop then
		_thisTrack = playerStatus.item_loop[1]
	end

	if not style then style = 'ss' end

	windowStyle = style
	if not self[windowStyle] then self[windowStyle] = {} end

	log:debug("CREATING UI FOR NOWPLAYING")
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
--		self:_updateProgress(playerStatus)

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
	end

	-- Initialize with current data from Player
	self[windowStyle].window:show(transitionOn)
	-- install some listeners to the window after it's shown
	self:_installListeners(self[windowStyle].window)
	self:_updateAll(self[windowStyle])

end

function free(self)
	-- when we leave NowPlaying, ditch the window
	-- the screen can get loaded with two layouts, and by doing this
	-- we force the recreation of the UI when re-entering the screen, possibly in a different mode
	log:info("NowPlaying.free()")

	-- player has left the building, close Now Playing browse window
	if self['browse'] and self['browse'].window then
		self['browse'].window:hide()
	end

	if self['ss'] and self['ss'].window then
		self['ss'].window:hide()
	end

	self.player = false
	self['ss'] = nil
	self['browse'] = nil
	jiveMain:removeItemById('appletNowPlaying')
end


