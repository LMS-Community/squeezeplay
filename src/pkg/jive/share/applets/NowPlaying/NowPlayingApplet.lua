local pairs, ipairs, tostring, type = pairs, ipairs, tostring, type

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
local datetime         = require("jive.utils.datetime")

local appletManager    = appletManager


local WH_FILL                = jive.ui.WH_FILL
local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE


module(...)
oo.class(_M, Applet)


function displayName(self)
	return "Now Playing"
end

----------------------------------------------------------------------------------------
-- Globals
--

local ARTWORK_SIZE = 154

local thePlayer = nil
local theItem = nil

local titleGroup = nil

local trackGroup = nil
local lTrackArtist = nil
local lTrackAlbum = nil
local lPlaylist = nil
local iArt = nil
local progressSlider = nil
local lPos = nil
local lRemain = nil

local iTrackPos = 0
local iTrackLen = 0

--local noArtworkImage = nil
--local shadowArtworkImage = nil


----------------------------------------------------------------------------------------
-- Helper Functions
--

local function _nowPlayingArtworkThumbUri(iconId)
        return '/music/' .. iconId .. '/cover_' .. ARTWORK_SIZE .. 'x' .. ARTWORK_SIZE .. '_p.png'
end

local function _getSink(self, cmd)
	return function(chunk, err)

		if err then
			log:debug(err)
					
		elseif chunk then
			--log:info(chunk)
						
			local proc = "_process_" .. cmd
			if self[proc] then
				self[proc](self, chunk)
			else
				log:error("No Such Method: " .. proc)
			end
		end
	end
end

local function SecondsToString(seconds)
	local min = math.floor(seconds / 60)
	local sec = math.floor(seconds - (min*60))

	return string.format("%d:%02d", min, sec)
end

local function _getIcon(item)
	local icon = nil
	local server = thePlayer:getSlimServer()

	if item["icon-id"] then
		-- Fetch an image from SlimServer
		icon = iArt --Icon("icon")
		server:fetchArtworkThumb(item["icon-id"], icon, _nowPlayingArtworkThumbUri, ARTWORK_SIZE) 
	elseif item["icon"] then
		-- Fetch a remote image URL, sized to ARTWORK_SIZE x ARTWORK_SIZE
		icon = iArt --Icon("icon")
		server:fetchArtworkURL(item["icon"], icon, ARTWORK_SIZE)
	else
		iArt:setValue(nil)
	end
	return icon
end

local function updatePosition()
	local strElapsed = ""
	local strRemain = ""
	local pos = 0

	if iTrackPos then 
		strElapsed = SecondsToString(iTrackPos)
	end

	if iTrackLen and iTrackLen > 0 then
		strRemain = "-" .. SecondsToString(iTrackLen - iTrackPos)
		pos = iTrackPos
	end

	progressGroup:setWidgetValue("elapsed", strElapsed)
	progressGroup:setWidgetValue("remain", strRemain)
	progressSlider:setValue(pos)
end

function updateTrack(self, trackinfo, pos, length)
	trackGroup:setWidgetValue("text", trackinfo);
end

function updateProgress(self, trackpos, tracklen)
	iTrackPos = trackpos
	iTrackLen = tracklen	

	if tracklen and tracklen > 0 then
		progressSlider:setRange(0, tracklen, trackpos)
	else 
		-- If 0 just set it to 100
		progressSlider:setRange(0, 100, 0)
	end

	updatePosition()

end

function updatePlaylist(self, enabled, nr, count)
	if enabled == true and count > 1 then
		nr = nr + 1
		titleGroup:setWidgetValue("playlist", self:string("SCREENSAVER_NOWPLAYING_OF", nr, count))
	else 
		titleGroup:setWidgetValue("playlist", "")
	end
end

function tick(self)
	if self.mode ~= "play" then
		return
	end

	iTrackPos = iTrackPos + 1
	if iTrackLen and iTrackLen > 0 then
		if iTrackPos > iTrackLen then iTrackPos = iTrackLen end
	end

	updatePosition()
end

-----------------------------------------------------------------------------------------
-- Settings
--
function openSettings(self, menuItem)
	local window = Window("Now Playing Settings")

	self:tieAndShowWindow(window)
	return window
end

----------------------------------------------------------------------------------------
-- Screen Saver Display 
--


function _process_status(self, event)
	log:debug("_process_status")

	local data = event.data;

	self.mode = data.mode
	if self.mode == "play" then
		titleGroup:setWidgetValue("title", self:string("SCREENSAVER_NOWPLAYING"))
	elseif self.mode == "pause" then
		titleGroup:setWidgetValue("title", self:string("SCREENSAVER_PAUSED"))
	elseif self.mode == "stop" then
		titleGroup:setWidgetValue("title", self:string("SCREENSAVER_STOPPED"))
	end

	if data.item_loop ~= nil then

		local text = data.item_loop[1].text
		-- XXX: current_title of null is a function value??
		if data.remote == 1 and type(data.current_title) == 'string' then 
			text = text .. "\n" .. data.current_title
		end

		theItem = data.item_loop[1]

		_getIcon(theItem)
		self:updateTrack(text)
		self:updateProgress(data.time, data.duration)
		self:updatePlaylist(true, data.playlist_cur_index, data.playlist_tracks)
	else
		theItem = nil

		_getIcon(theItem)
		self:updateTrack("") -- FIXME what string?
		self:updateProgress(0, 0)
		self:updatePlaylist(false, 0, 0)
	end
end

function free(self)
	if thePlayer then
		thePlayer.slimServer.comet:removeCallback( '/slim/playerstatus/' .. thePlayer:getId(), self.statusSink )
	end
end

function _createUI(self)
	local window = Window("window")

	local sw, sh = Framework:getScreenSize()

	titleGroup = Group("nptitle", {
				   title = Label("text", self:string("SCREENSAVER_NOWPLAYING")),
				   playlist = Label("playlist", "")
			   })
	

	trackGroup = Group("nptrack", {
				   text = Label("text", "\n\n\n")
			   })
	
	
	progressSlider = Slider("slider", 0, 100, 0)
	progressSlider:addTimer(1000, function() self:tick() end)

	progressGroup = Group("progress", {
				      elapsed = Label("text", ""),
				      slider = progressSlider,
				      remain = Label("text", "")
			      })

	iArt = Icon("artwork")
	artworkGroup = Group("npartwork166", {
				     artwork = iArt     
			     })
	
	window:addWidget(titleGroup)
	window:addWidget(trackGroup)
	window:addWidget(artworkGroup)
	window:addWidget(progressGroup)

	window:focusWidget(trackGroup)

	return window
end

function openScreensaver(self, menuItem, mode)

	-- this is to allow the screensaver to be opened in two modes: 
	-- Screensaver and notScreensaver
	-- default to Screensaver
	if not mode then mode = 'Screensaver' end
	log:warn(mode)

	local window = _createUI(self)

	local discovery = appletManager:getAppletInstance("SlimDiscovery")
	thePlayer = discovery:getCurrentPlayer()

	if thePlayer then
		local playerid = thePlayer:getId()

		-- FIXME this callback should come from the Player object
		-- is this why the playlist screen stops updating?
	
		-- Register our own functions to be called when we receive data
		self.statusSink = _getSink(self, 'status')
		thePlayer.slimServer.comet:addCallback(
			'/slim/playerstatus/' .. playerid,
			self.statusSink
		)

		-- Initialize with current data from Player
		local event = { data = thePlayer.state }
		self:_process_status(event)

		self:tieAndShowWindow(window)
		return window

	else
		-- No current player - don't start screensaver
		return nil
	end
end

function skin(self, s)
	local imgpath = "applets/DefaultSkin/images/"
	local npimgpath = "applets/NowPlaying/images/"
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
	s.nptitle = {}
	s.nptitle.border = { 4, 4, 4, 0 }
	s.nptitle.position = LAYOUT_NORTH
	s.nptitle.bgImg = titleBox
	s.nptitle.order = { "title", "playlist" }
	s.nptitle.text = {}
	s.nptitle.text.w = WH_FILL
	s.nptitle.text.padding = { 10, 7, 8, 9 }
	s.nptitle.text.align = "top-left"
	s.nptitle.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	s.nptitle.text.fg = { 0x00, 0x00, 0x00 }
	s.nptitle.playlist = {}
	s.nptitle.playlist.padding = { 10, 7, 8, 9 }
	s.nptitle.playlist.font = Font:load(fontpath .. "FreeSans.ttf", 15)
	s.nptitle.playlist.fg = { 0x00, 0x00, 0x00 }
	s.nptitle.playlist.textAlign = "top-right"

	-- Song
	s.nptrack = {}
	s.nptrack.border = { 4, 0, 4, 0 }
        s.nptrack.bgImg = highlightBox
	s.nptrack.text = {}
	s.nptrack.text.w = WH_FILL
	s.nptrack.text.padding = { 10, 7, 8, 9 }
	s.nptrack.text.align = "top-left"
        s.nptrack.text.font = Font:load(fontpath .. "FreeSans.ttf", 14)
	s.nptrack.text.lineHeight = 17
        s.nptrack.text.line = {
		{
			font = Font:load(fontpath .. "FreeSansBold.ttf", 14),
			height = 17
		}
	}
	s.nptrack.text.fg = { 0x00, 0x00, 0x00 }

	-- Artwork
	local noartwork166offset = (screenWidth - 166) / 2
	s.npartwork166 = {}
	s.npartwork166.w = 166
	s.npartwork166.border = { noartwork166offset, 4, onoartwork166offset, 6 }
	s.npartwork166.align = "center"
	s.npartwork166.bgImg = Tile:loadImage(imgpath .. "album_shadow_166.png")
	s.npartwork166.artwork = {}
	s.npartwork166.artwork.padding = 3
	s.npartwork166.artwork.img = Surface:loadImage(imgpath .. "album_noartwork_166.png")

	-- Progress bar
	s.progress = {}
	s.progress.order = { "elapsed", "slider", "remain" }
	s.progress.text = {}
	s.progress.text.w = 45
	s.progress.text.padding = { 8, 0, 8, 0 }
	s.progress.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.progress.text.fg = { 0xe7,0xe7, 0xe7 }
	s.progress.text.sh = { 0x37, 0x37, 0x37 }
end
