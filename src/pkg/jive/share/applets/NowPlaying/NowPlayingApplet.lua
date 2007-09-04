local pairs, ipairs, tostring = pairs, ipairs, tostring
local tonumber = tonumber

local math             = require("math")
local table            = require("table")
local os	       = require("os")	
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
local Tile	       = require("jive.ui.Tile")
local Timer	       = require("jive.ui.Timer")
                       
local log              = require("jive.utils.log").logger("applets.screensavers")
local datetime         = require("jive.utils.datetime")

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local FRAME_RATE       = jive.ui.FRAME_RATE
local LAYER_FRAME      = jive.ui.LAYER_FRAME
local LAYER_CONTENT    = jive.ui.LAYER_CONTENT
local LAYER_ALL	       = jive.ui.JIVE_LAYER_ALL
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE
local KEY_BACK         = jive.ui.KEY_BACK

local LAYOUT_NORTH            = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST             = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH            = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST             = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER           = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE             = jive.ui.LAYOUT_NONE


local appletManager	= appletManager

module(...)
oo.class(_M, Applet)


function displayName(self)
	return "Now Playing"
end

----------------------------------------------------------------------------------------
-- Globals
--

local theWindow = nil
local thePlayer = nil
local theItem = nil
local theIconId = nil

local tTimer = nil

local lWTitle = nil

local lArtist = nil
local lTitle = nil
local lAlbum = nil
local iArt = nil
local sPos = nil
local lPos = nil
local lRemain = nil

local iTrackPos = 0
local iTrackLen = 0

----------------------------------------------------------------------------------------
-- Helper Functions
--

local function _nowPlayingArtworkThumbUri(iconId)
        return '/music/' .. iconId .. '/cover_50x50_f_000000.jpg'
end

local function _getSink(self, cmd)
	return function(chunk, err)

		if err then
			log:debug(err)
					
		elseif chunk then
			--log:info(chunk)
						
			local proc = "_process_" .. cmd[1]
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
		server:fetchArtworkThumb(item["icon-id"], icon, _nowPlayingArtworkThumbUri)
	elseif item["icon"] then
		-- Fetch a remote image URL, sized to 100x100
		icon = Icon("icon")
		server:fetchArtworkURL(item["icon"], icon, 100)
	end
	return icon
end

local function updatePosition()

	if iTrackLen > 0 then
		local strPos = SecondsToString(iTrackPos)
		local strRemain = "-" .. SecondsToString(iTrackLen - iTrackPos)
		
		lPos:setValue(strPos)
		lRemain:setValue(strRemain)

		sPos:setValue(iTrackPos)

	else 
	
		lPos:setValue("n/a")
		lRemain:setValue("n/a")
		sPos:setValue(0)

	end

end

local function setAlbum(value)
	lAlbum:setValue(value)
end

local function setArtist(value)
	lArtist:setValue(value)
end

local function setTitle(value)
	lTitle:setValue(value)
end

local function setTime(trackpos, tracklen)
	iTrackPos = trackpos
	iTrackLen = tracklen	

	if tracklen > 0 then
		sPos:setRange(0, tracklen, trackpos)
	else 
		-- If 0 just set it to 100
		sPos:setRange(0, 100, 0)
	end

	updatePosition()
end

local function setArtwork(icon)
	log:error("Set Artwork")
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


local function updateTrack(album, artist, track, pos, length)
	setAlbum(album)
	setArtist(artist)
	setTitle(track)
	setTime(pos, length)
end

local function tick()
	if iTrackLen > 0 then
		iTrackPos = iTrackPos + 1
		if iTrackPos > iTrackLen then iTrackPos = iTrackLen end

		updatePosition()
	end
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

	if data.item_loop ~= nil then

		local text = data.item_loop[1].text
		theItem = data.item_loop[1]

		local icon = _getIcon(theItem)

		-- Split Text Up into the three infos
		--
		local x = string.gfind(text, "([^\n]*)")
		local i = 0
		local split = {}
		for v in x do
			if string.len(v) > 0 then
				i = i + 1
				split[i] = v
			end
		end

		updateTrack(split[2], split[3], split[1], data.time, data.duration)
		setArtwork(icon)
	else
		theItem = nil
		updateTrack("", "(Nothing Playing)", "", 0, 0)
		setArtwork(nil)
	end
	
end

function free(self)
	if thePlayer then
		thePlayer.slimServer.comet:unsubscribe( '/slim/displaystatus/' .. thePlayer:getId(), self.displaySink )
		thePlayer.slimServer.comet:unsubscribe( '/slim/playerstatus/' .. thePlayer:getId(), self.statusSink )
	end

	tTimer:stop()
end

function _createUI(self)
	local window = Window("nowplaying")

	local sw, sh = Framework:getScreenSize()

	lWTitle = Label("title", "Now Playing")
	lWTitle:setPosition(5, 5)
	lWTitle:setSize(sw-10, 35)

	lTitle = Label("label", "#TRACK NAME#")
	lTitle:setPosition(10, 45)
	lTitle:setSize(sw-10, 20)

	lAlbum = Label("label", "#ALBUM#")
	lAlbum:setPosition(10, 65)
	lAlbum:setSize(sw-10, 20)

	lArtist = Label("label", "#ARTIST#")
	lArtist:setPosition(10, 85)
	lArtist:setSize(sw-10, 20) 

	lPos = Label("label", "n/a")
	lPos:setPosition(10, sh-65)
	lPos:setSize(sw/2, 10)

	lRemain = Label("rlabel", "n/a")
	lRemain:setPosition(sw/2, sh-65)
	lRemain:setSize(sw/2-10, 10)

	iArt = Icon("artwork")
	iArt:setSize(100, 100)
	iArt:setPosition(sw/2-50, 115)

	local bg = Label("background", "")
	bg:setSize(sw-10, 70)
	bg:setPosition(5, 40)

	sPos = Slider("slider", 0, 100, 0, function(slider, value) log:warn("slider: " .. value) end)
	sPos:setPosition(10, sh-80)
	sPos:setSize(sw-20, 10)
	
	window:addWidget(bg)
	window:addWidget(lWTitle)
	window:addWidget(lAlbum)
	window:addWidget(lArtist)
	window:addWidget(lTitle)
	window:addWidget(sPos)
	window:addWidget(lPos)
	window:addWidget(lRemain)
	window:addWidget(iArt)

	theWindow = window

	return window
end

function openScreensaver(self, menuItem)

	local window = _createUI()

	local discovery = appletManager:getAppletInstance("SlimDiscovery")
	thePlayer = discovery:getCurrentPlayer()

	if thePlayer then
	
		local playerid = thePlayer:getId()
	
		local cmd =  { 'status', '-', 10, 'menu:menu', 'subscribe:30' }
		self.statusSink = _getSink(self, cmd)
		thePlayer.slimServer.comet:subscribe(
			'/slim/playerstatus/' .. playerid,
			self.statusSink,
			playerid,
			cmd
		)

		local cmd = { 'displaystatus', 'subscribe:showbriefly' }
		self.displaySink = _getSink(self, cmd)
		thePlayer.slimServer.comet:subscribe(
			'/slim/displaystatus/' .. playerid,
			self.displaySink,
			playerid,
			cmd
		)

		tTimer = Timer(1000, function() tick() end)
		tTimer:start()

		self:tieAndShowWindow(window)
		return window

	else
		-- No current player - don't start screensaver
		return nil
	end
end

function skin(self, s)
	local imgpath = "applets/DefaultSkin/images/"
	local fontpath = "fonts/"

	s.nowplaying.layout = Window.noLayout

        local titleBox =
                Tile:loadTiles({
                                       imgpath .. "titlebox.png",
                                       imgpath .. "titlebox_tl.png",
                                       imgpath .. "titlebox_t.png",
                                       imgpath .. "titlebox_tr.png",
                                       imgpath .. "titlebox_r.png",
                                       imgpath .. "titlebox_br.png",
                                       imgpath .. "titlebox_b.png",
                                       imgpath .. "titlebox_bl.png",
                                       imgpath .. "titlebox_l.png"
                               })

        local highlightBox =
                Tile:loadTiles({
                                       imgpath .. "menu_selection_box.png",
                                       imgpath .. "menu_selection_box_tl.png",
                                       imgpath .. "menu_selection_box_t.png",
                                       imgpath .. "menu_selection_box_tr.png",
                                       imgpath .. "menu_selection_box_r.png",
                                       imgpath .. "menu_selection_box_br.png",
                                       imgpath .. "menu_selection_box_b.png",
                                       imgpath .. "menu_selection_box_bl.png",
                                       imgpath .. "menu_selection_box_l.png"
                               })

        s.title.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
        s.title.fg = { 0x37, 0x37, 0x37 }
        s.title.bgImg = titleBox

	s.rlabel.textAlign = "top-right"

	s.artwork.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.artwork.x = 50
	s.artwork.y = 100
	
	s.background.bgImg = highlightBox
end
