local oo               = require("loop.simple")
local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("audio.decode")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Timer            = require("jive.ui.Timer")
local json             = require("json")
local mime             = require("mime")

local hasDecode, decode = pcall(require, "squeezeplay.decode")

local appletManager    = appletManager
local jnt              = jnt
local require          = require
local string           = string

local DECODE_RUNNING   = (1 << 0)
local IDLE_CHECK       = 1 * 60 * 1000 -- 1 minute

module(..., Framework.constants)
oo.class(_M, Applet)

local decode_spotify
local idleTimer

function spotify(self, playback, data, decode)
	if not decode_spotify then
		-- Have to load decode_spotify here because it is not available when
		-- the applet is loaded
		decode_spotify = require("squeezeplay.decode.spotify")
	end

	local cmdstr = playback.header .. "&"
	
	local uri = string.match(cmdstr, "spotify://(.-)%&")
	uri = "spotify:" .. uri
	log:info("uri: ", uri)
	decode_spotify:setTrackURI(uri)

	-- Seek if requested with a start param
	local start = string.match(cmdstr, "start%=(.-)%&")
	if start then
		start = mime.unb64("", start)
		log:info("start: ", start)
		decode_spotify:setSeekTo(start)
	else
		-- Avoid any global variable issues by always setting this value
		decode_spotify:setSeekTo(0)
	end
	
	-- XXX libspotify knows replaygain data, get it somehow

	decode:start(
		string.byte("t"),
		string.byte(data.transitionType),
		data.transitionPeriod,
		data.replayGain,
		data.outputThreshold,
		data.flags & 0x03,	-- polarity inversion
		data.flags & 0x0C,	-- output channels
		string.byte(data.pcmSampleSize),
		string.byte(data.pcmSampleRate),
		string.byte(data.pcmChannels),
		string.byte(data.pcmEndianness)
	)

	-- There is no streambuf for Spotify, so we have to signal connection directly
	playback.slimproto:sendStatus('STMc')

	-- Force the decoder to start as soon as possible
	playback:setDecodeThreshold(-1)
	
	-- Indicate to playback that we don't have a stream connection
	playback.ignoreStream = true

	playback.autostart = (playback.autostart == '2') and '0' or '1'
	-- or maybe playback:_cont({})
	
	-- Start a timer to detect idleness so we can logout of Spotify
	if not idleTimer then
		idleTimer = Timer(IDLE_CHECK, function()
			if decode_spotify:checkIdle() then
				idleTimer:stop()
				idleTimer = nil
			end
		end)
		idleTimer:start()
	end	
end


