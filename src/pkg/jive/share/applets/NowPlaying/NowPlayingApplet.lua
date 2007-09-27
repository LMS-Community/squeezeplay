local pairs, ipairs, tostring, type = pairs, ipairs, tostring, type
local tonumber = tonumber

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
local Slider	       = require("jive.ui.Slider")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
local Tile	           = require("jive.ui.Tile")
local Timer	           = require("jive.ui.Timer")
                       
local log              = require("jive.utils.log").logger("applets.screensavers")
local datetime         = require("jive.utils.datetime")

local appletManager	= appletManager

module(...)
oo.class(_M, Applet)


function displayName(self)
	return "Now Playing"
end

----------------------------------------------------------------------------------------
-- Globals
--

local ARTWORK_SIZE = 114

local theWindow = nil
local thePlayer = nil
local theItem = nil
local theTimer = nil

local lWTitle = nil

local lTrackName = nil
local lTrackArtist = nil
local lTrackAlbum = nil
local lPlaylist = nil
local iArt = nil
local sPos = nil
local lPos = nil
local lRemain = nil

local iTrackPos = 0
local iTrackLen = 0

local strOf = " of "

----------------------------------------------------------------------------------------
-- Helper Functions
--

local function _nowPlayingArtworkThumbUri(iconId)
        return '/music/' .. iconId .. '/cover_' .. ARTWORK_SIZE .. 'x' .. ARTWORK_SIZE .. '_f_000000.jpg'
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

	-- Fix when below 10
	if sec < 10 then 
		sec = "0" .. sec
	end

	return min .. ":" .. sec
end

local function _getCurrentIconId()
	if theItem == nil then
		return nil 
	end

	if theItem["icon-id"] then
		return "icon-id:" .. theItem["icon-id"]
	elseif theItem["icon"] then
		return "icon:" .. theItem["icon"]
	end

	return nil
end

local function _getIcon(item)
	local icon = nil
	local server = thePlayer:getSlimServer()

	if item["icon-id"] then
		-- Fetch an image from SlimServer
		icon = Icon("icon")
		server:fetchArtworkThumb(item["icon-id"], icon, _nowPlayingArtworkThumbUri, ARTWORK_SIZE) 
	elseif item["icon"] then
		-- Fetch a remote image URL, sized to ARTWORK_SIZE x ARTWORK_SIZE
		icon = Icon("icon")
		server:fetchArtworkURL(item["icon"], icon, ARTWORK_SIZE)
	end
	return icon
end

local function updatePosition()

	if iTrackLen and iTrackLen > 0 then
		local strPos = SecondsToString(iTrackPos)
		local strRemain = "-" .. SecondsToString(iTrackLen - iTrackPos)
		
		lPos:setValue(strPos)
		lRemain:setValue(strRemain)

		sPos:setValue(iTrackPos)

	else 
		if iTrackPos then 
			lPos:setValue(SecondsToString(iTrackPos))
		else 
			lPos:setValue("n/a")
		end
	
		lRemain:setValue("")
		sPos:setValue(0)
	end

end

local function setTrackInfo(value)
	-- Split Text Up into the three infos
	--
	local x = string.gfind(value, "([^\n]*)")
	local i = 0
	local split = {}
	for v in x do
		if string.len(v) > 0 then
			i = i + 1
			split[i] = v
		end
	end

	if i == 3 then
		lTrackName:setValue(split[1]);
		lTrackArtist:setValue(split[3]);
		lTrackAlbum:setValue(split[2]);
	else 
		lTrackName:setValue("")
		lTrackArtist:setValue(value)
		lTrackAlbum:setValue("")
	end
end

local function setTime(trackpos, tracklen)
	iTrackPos = trackpos
	iTrackLen = tracklen	

	if tracklen and tracklen > 0 then
		sPos:setRange(0, tracklen, trackpos)
	else 
		-- If 0 just set it to 100
		sPos:setRange(0, 100, 0)
	end

	updatePosition()
end

local function setArtwork(icon)
	if icon ~= nil then
		theWindow:removeWidget(iArt)

		local sw, sh = iArt:getSize()
		local x, y = iArt:getPosition()

		iArt = icon
		iArt:setSize(sw, sh)
		iArt:setPosition(x,y)
		theWindow:addWidget(iArt)
	else
		log:debug("No Icon")
	end
end


local function updateTrack(trackinfo, pos, length)
	setTrackInfo(trackinfo)
	setTime(pos, length)
end

local function updatePlaylist(enabled, nr, count)
	log:error(nr .. " - " .. count)
	if enabled == true then
		nr = nr + 1
		lPlaylist:setValue(nr .. strOf .. count)
	else 
		lPlaylist:setValue("")
	end
end

local function tick()
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

function _process_displaystatus(self, event)
	log:debug("Display Status")

	local data = event.data;
	if data.display then 
		local display = data.display;
		log:debug(display)
	else 
		log:debug("No Display")
	end
end

function _process_status(self, event)
	log:debug("_process_status")

	local data = event.data;

	if data.mode == "play" then
		theTimer:start()	
	elseif data.mode == "pause" then
		theTimer:stop()
	else
		log:debug("Unknown Mode: " .. data.mode)
	end

	if data.item_loop ~= nil then

		local text = data.item_loop[1].text
		-- XXX: current_title of null is a function value??
		if data.remote == 1 and type(data.current_title) == 'string' then 
			text = text .. "\n" .. data.current_title
		end
			
		theItem = data.item_loop[1]

		local icon = _getIcon(theItem)

		updateTrack(text, data.time, data.duration)
		updatePlaylist(true, data.playlist_cur_index, data.playlist_tracks)
		setArtwork(icon)
	else
		theItem = nil
		updateTrack("(Nothing Playing)", 0, 0)
		updatePlaylist(false, 0, 0)
		setArtwork(nil)
	end
end

function free(self)
	if thePlayer then
		thePlayer.slimServer.comet:removeCallback( '/slim/displaystatus/' .. thePlayer:getId(), self.displaySink )
		thePlayer.slimServer.comet:removeCallback( '/slim/playerstatus/' .. thePlayer:getId(), self.statusSink )
	end

	theTimer:stop()
end

function _createUI(self)
	-- Retrieve " of " string
	strOf = " " .. tostring(self:string("SCREENSAVER_NOWPLAYING_OF")) .. " "

	local window = Window("nowplaying")

	local sw, sh = Framework:getScreenSize()

	lWTitle = Label("nptitle", "Now Playing")
	lWTitle:setPosition(5, 5)
	lWTitle:setSize(sw-10, 35)

	lPlaylist = Label("playlist", "")
	lPlaylist:setPosition(sw-70, 15)
	lPlaylist:setSize(55, 10)

	lTrackName = Label("labelbold", "")
	lTrackName:setPosition(10, 45)
	lTrackName:setSize(sw-20, 15)

	lTrackArtist = Label("label", "")
	lTrackArtist:setPosition(10, 60)
	lTrackArtist:setSize(sw-20, 15)

	lTrackAlbum = Label("label", "")
	lTrackAlbum:setPosition(10, 75)
	lTrackAlbum:setSize(sw-20, 15)

	lPos = Label("wlabel", "n/a")
	lPos:setPosition(10, sh-59)
	lPos:setSize(20, 10)

	lRemain = Label("wrlabel", "n/a")
	lRemain:setPosition(sw-30, sh-59)
	lRemain:setSize(25, 10)

	iArt = Icon("artwork")
	iArt:setSize(ARTWORK_SIZE, ARTWORK_SIZE)
	iArt:setPosition(sw/2-(ARTWORK_SIZE/2), 115)

	local bg = Label("background", "")
	bg:setSize(sw-11, 65)
	bg:setPosition(6, 38)

	sPos = Slider("slider", 0, 100, 0, function(slider, value) log:warn("slider: " .. value) end)
	sPos:setPosition(35, sh-60)
	sPos:setSize(sw-70, 10)
	
	window:addWidget(bg)
	window:addWidget(lWTitle)
	window:addWidget(lPlaylist)
	window:addWidget(lTrackName)
	window:addWidget(lTrackArtist)
	window:addWidget(lTrackAlbum)
	window:addWidget(sPos)
	window:addWidget(lPos)
	window:addWidget(lRemain)
	window:addWidget(iArt)

	--window:focusWidget(lTrackInfo)

	theWindow = window

	return window
end

function openScreensaver(self, menuItem)

	local window = _createUI(self)

	local discovery = appletManager:getAppletInstance("SlimDiscovery")
	thePlayer = discovery:getCurrentPlayer()

	if thePlayer then
	
		local playerid = thePlayer:getId()
	
		-- Register our own functions to be called when we receive data
		self.statusSink = _getSink(self, 'status')
		thePlayer.slimServer.comet:addCallback(
			'/slim/playerstatus/' .. playerid,
			self.statusSink
		)

		self.displaySink = _getSink(self, 'displaystatus')
		thePlayer.slimServer.comet:addCallback(
			'/slim/displaystatus/' .. playerid,
			self.displaySink
		)

		theTimer = Timer(1000, function() tick() end)
		theTimer:start()
		
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

	s.nowplaying.layout = Window.noLayout

        local titleBox =
                Tile:loadTiles({
                                       imgpath .. "titlebox.png",
                                       imgpath .. "titlebox_tl.png",
                                       imgpath .. "titlebox_t.png",
                                       imgpath .. "titlebox_tr.png",
                                       imgpath .. "titlebox_r.png",
                                       imgpath .. "titlebox_br_bghighlight.png",
                                       imgpath .. "titlebox_b.png",
                                       imgpath .. "titlebox_bl_bghighlight.png",
                                       imgpath .. "titlebox_l.png"
                               })

        local highlightBox =
                Tile:loadTiles({
                                       imgpath .. "bghighlight.png",
                                       imgpath .. "bghighlight_tl.png",
                                       imgpath .. "bghighlight_t.png",
                                       imgpath .. "bghighlight_tr.png",
                                       imgpath .. "bghighlight_r.png",
                                       imgpath .. "bghighlight_br.png",
                                       imgpath .. "bghighlight_b.png",
                                       imgpath .. "bghighlight_bl.png",
                                       imgpath .. "bghighlight_l.png"
                               })

	-- Title
        s.nptitle.font = Font:load(fontpath .. "FreeSansBold.ttf", 18)
        s.nptitle.fg = { 0x37, 0x37, 0x37 }
        s.nptitle.bgImg = titleBox
        s.nptitle.padding = { 10, 7, 8, 9 }
        s.nptitle.position = LAYOUT_NORTH

	-- Bold Font for song title
        s.labelbold.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)

	-- Normal font for artist and album name
	s.label.font = Font:load(fontpath .. "FreeSans.ttf", 13)

	-- Time Position Label
	s.wlabel.font = Font:load(fontpath .. "FreeSansBold.ttf", 11)
	s.wlabel.fg = { 0xE7, 0xE7, 0xE7 }
	
	-- Time Position Label (DropShadow)
	s.wlabel_ds.font = Font:load(fontpath .. "FreeSansBold.ttf", 11)
	s.wlabel_ds.fg = { 0x35, 0x35, 0x35 }

	-- Time Remaining Label
	s.wrlabel.font = Font:load(fontpath .. "FreeSansBold.ttf", 11)
	s.wrlabel.fg = { 0xE7, 0xE7, 0xE7 }
	s.wrlabel.textAlign = "top-right"

	-- Time Remaining Label (DropShadow)
	s.wrlabel_ds.font = Font:load(fontpath .. "FreeSansBold.ttf", 11)
	s.wrlabel_ds.fg = { 0x35, 0x35, 0x35 }
	s.wrlabel_ds.textAlign = "top-right"

	-- Playlist display
	s.playlist.font = Font:load(fontpath .. "FreeSans.ttf", 14)
	s.playlist.fg = { 0x0, 0x0, 0x0 }
	s.playlist.textAlign = "top-right"

	-- Artwork
	s.artwork.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.artwork.x = 50
	s.artwork.y = 100
	
	-- Label Background 
	s.background.bgImg = highlightBox
end
