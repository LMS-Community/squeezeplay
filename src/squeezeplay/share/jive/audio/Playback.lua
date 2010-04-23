
local assert, tostring, type, pairs, ipairs, getmetatable = assert, tostring, type, pairs, ipairs, getmetatable


local oo                     = require("loop.base")

local string                 = require("string")
local table                  = require("table")

local hasDecode, decode      = pcall(require, "squeezeplay.decode")
local hasSprivate, spprivate = pcall(require, "spprivate")
local Stream                 = require("squeezeplay.stream")
local Rtmp                   = require("jive.audio.Rtmp")
local SlimProto              = require("jive.net.SlimProto")
local Player                 = require("jive.slim.Player")

local Task                   = require("jive.ui.Task")
local Timer                  = require("jive.ui.Timer")
local Framework              = require("jive.ui.Framework")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("audio.decode")

local iconbar = iconbar


module(..., oo.class)


-- decode and audio states
local DECODE_RUNNING        = (1 << 0)
local DECODE_UNDERRUN       = (1 << 1)
local DECODE_ERROR          = (1 << 2)
local DECODE_NOT_SUPPORTED  = (1 << 3)
local DECODE_STOPPING       = (1 << 5)

-- disconnect codes
local TCP_CLOSE_FIN           = 0
local TCP_CLOSE_LOCAL_RST     = 1
local TCP_CLOSE_REMOTE_RST    = 2
local TCP_CLOSE_UNREACHABLE   = 3
local TCP_CLOSE_LOCAL_TIMEOUT = 4


-- Do NOT set a read timeout, the stream may be paused indefinately
local STREAM_READ_TIMEOUT = 0
local STREAM_WRITE_TIMEOUT = 5

local LOCAL_PAUSE_STOP_TIMEOUT = 400

-- Handlers to allow applets to extend playback capabilties via spdr:// urls
local streamHandlers = {}


function __init(self, jnt, slimproto)
	assert(slimproto)

	local obj = oo.rawnew(self, {})

	obj.sequenceNumber = 1

	obj.jnt = jnt
	obj.slimproto = slimproto

	obj.slimproto:statusPacketCallback(function(_, event, serverTimestamp)
		local status = decode:status() or {}

		status.opcode = "STAT"
		status.event = event
		status.serverTimestamp = serverTimestamp
		status.isStreaming = (obj.stream ~= nil)
		status.isLooping = obj.isLooping
		status.signalStrength = obj.signalStrength

		return status
	end)

	obj.slimproto:subscribe("strm", function(_, data)
		return obj:_strm(data)
	end)

	obj.slimproto:subscribe("cont", function(_, data)
		return obj:_cont(data)
	end)

	obj.slimproto:subscribe("audg", function(_, data)
		return obj:_audg(data)
	end)

	obj.slimproto:subscribe("aude", function(_, data)
		return obj:_aude(data)
	end)

	obj.slimproto:subscribe("setd", function(_, data)
		return obj:_setd(data)
	end)
	
	obj.timer = Timer(100, function()
		obj:_timerCallback()
	end)
	obj.timer:start()

	if hasSprivate then
		spprivate:initAudio(slimproto)
	end
	decode:initAudio(slimproto)

	local cap
	for handler, _ in pairs(streamHandlers) do
		cap = (cap and (cap .. "|") or "") .. handler
	end
	if cap then
		slimproto:capability("spdr")
		slimproto:capability("Spdirect", cap)
	end

	Rtmp:init(slimproto)

	self.mode = 0
	self.threshold = 0
	self.tracksStarted = 0

	self.statusTimestamp = 0

	self.sentResume = false
	self.sentResumeDecoder = false
	self.sentDecoderFullEvent = false
	self.sentDecoderUnderrunEvent = false
	self.sentOutputUnderrunEvent = false
	self.sentAudioUnderrunEvent = false

	return obj
end


function stop(self)
	decode:stop()
	self.timer:stop()

	_setSource(self, "off")
end


function _setSource(self, source)
	if self.source == source then
		return
	end

	log:debug("source=", source)

	Framework.wakeup()

	-- switched from capture
	if self.source == "capture" then
		decode:capture(false)
	end

	self.source = source

	-- switched to capture
	if self.source == "capture" then
		decode:stop()
		decode:capture(true)
	end
end


-- Load a file and play it in a loop. This is for playing test tones.
-- Currently only works with mp3 files.
function playFileInLoop(self, file)
--	assert(string.match(file , ".mp3"), "Only mp3 files are supported")

	log:info("loop file ", file)

	Framework.wakeup()
	_setSource(self, "file")

	self:_streamDisconnect(nil, true)

	Stream:loadLoop(file)

	decode:start(string.byte('m'),
		     0, -- transition type
		     0, -- transition period
		     0, -- reply gain
		     0, -- output threshold
		     0, -- polartity inversion
		     0, 0, 0, 0 -- decode params
		     )

	decode:resumeDecoder()
	self.sentResumeDecoder = true

	self.autostart = '1'
	self.threshold = 0
	self.sentResume = false
end


function setSignalStrength(self, signalStrength)
	self.signalStrength = signalStrength
end


function sendStatus(self, status, event, serverTimestamp)
	status.opcode = "STAT"
	status.event = event
	status.serverTimestamp = serverTimestamp
	status.signalStrength = self.signalStrength

	self.slimproto:send(status)
	self.statusTimestamp = Framework:getTicks()
end


function _timerCallback(self)
	local status = decode:status()
	if status == nil then
		return
	end

--[[
	-- cpu power saving
	local outputFullness = status.outputFull / status.outputSize * 100
	if status.decodeSize > 0 then
		if outputFullness < 80 then
			self.jnt:cpuActive(self)
		elseif outputFullness > 99 then
			self.jnt:cpuInactive(self)
		end
	end

	-- cpu power saving
	-- note this won't enter power save for internet streams
	local decodeFullness = status.decodeFull / status.decodeSize * 100
	if self.stream and decodeFullness < 80 then
		self.jnt:networkActive(self)
	elseif not self.stream or decodeFullness > 99 then
		self.jnt:networkInactive(self)
	end
--]]

	if status.decodeState & DECODE_RUNNING ~= 0 then
		self.jnt:cpuActive(self)
		self.jnt:networkActive(self)
	else
		self.jnt:cpuInactive(self)
		self.jnt:networkInactive(self)
	end


	-- enable stream reads when decode buffer is not full
	if status.decodeFull < status.decodeSize and self.stream then
		self.jnt:t_addRead(self.stream, self.rtask, STREAM_READ_TIMEOUT)
	end

	if status.decodeState & DECODE_UNDERRUN ~= 0 or
		status.decodeState & DECODE_ERROR ~= 0 then

		-- decode underruns are used by the server to determine
		-- when a track has finished decoding (indicating that
		-- we could start decoding the next track).
		-- only send a decoder underrun if:
		-- 1) we haven't sent one before for this underrun
		-- 2) the connection to us has been closed (indicating
		-- that the stream is done) or we have an unrecoverable
		-- decoder error.

		if not self.sentDecoderUnderrunEvent and
			(not self.stream or status.decodeState & DECODE_ERROR ~= 0) then
			if status.decodeState & DECODE_NOT_SUPPORTED ~= 0 then
				self:sendStatus(status, "STMn")
			end

			log:debug("status DECODE UNDERRUN")
			self:sendStatus(status, "STMd")

			self.sentDecoderUnderrunEvent = true
			self.sentDecoderFullEvent = false

			decode:songEnded()
		end
	else
		self.sentDecoderUnderrunEvent = false
	end


	if status.audioState & DECODE_UNDERRUN ~= 0 then

		-- audio underruns are used by the server to determine
		-- whether a track has completed playback. we have to
		-- be careful to send audio underrun messages only when
		-- we know we've readed the end of a track.
		-- only send an audio underrun event if:
		-- 1) we haven't sent on before this underrun
		-- 2) the decoder has underrun

		-- output underruns are used by the server to detect
		-- when streaming (and decoding) is not able to keep up with playback,
		-- usualy for radio streams

		if not self.sentAudioUnderrunEvent and
			self.sentDecoderUnderrunEvent then

			log:debug("status AUDIO UNDERRUN")
			decode:stop()
			self:sendStatus(status, "STMu")

			self.sentAudioUnderrunEvent = true

		elseif not self.sentOutputUnderrunEvent and
			self.stream then

			log:info("output underrun")
			decode:pauseAudio(0) -- auto-pause to prevent glitches
			self:sendStatus(status, "STMo")

			self.sentOutputUnderrunEvent = true
		end
	else
		self.sentOutputUnderrunEvent = false
		self.sentAudioUnderrunEvent = false
	end


	-- Cannot test of stream is not nil because stream may be complete (and closed) before track start
	if status.decodeState & DECODE_RUNNING ~= 0
		and status.audioState & DECODE_STOPPING == 0
		and (self.tracksStarted < status.tracksStarted) then

		log:debug("status TRACK STARTED (elapsed: ", status.elapsed, ")")
		self:sendStatus(status, "STMs")

		self.tracksStarted = status.tracksStarted
	end

	-- We can begin decoding with 2K of data
	local decodeThreshold = 2048
	
	-- Except for Vorbis, where we should use the buffer threshold value
	-- Even this may not be enough for files with large comments...
	if self.mode == 'o' then
		decodeThreshold = self.threshold
	end

	-- Start the decoder if:
	-- 1) some encoded data is buffered
	-- 2) if we are auto-starting
	-- 3) decode is not already running
	-- 4) we have finished processing any strm-q command
	if status.decodeFull > decodeThreshold and
		(self.autostart == '0' or self.autostart == '1') and
		status.decodeState & DECODE_RUNNING == 0 and not self.sentResumeDecoder and
		status.audioState & DECODE_STOPPING == 0 then

		log:debug("resume decoder, ", status.decodeFull, " bytes buffered, decode threshold ", decodeThreshold)
		decode:resumeDecoder()
		self.sentResumeDecoder = true
	end

	-- Start the audio if:
	-- 1) this is the first track since the last strm-q
	-- 2) we have actually finished processing that strm-q
	-- 3) we have enough encoded data buffered or the stream is complete
	-- 4) we have a bit of output ready; actually this test is not necessary as such
	--		because the AUTOSTART mechanism for the audio startup performs the same function
	--		and would allow slightly quicker startup, but we still need the test as a way to
	--		determine that we have actually started to stream and decode a track as none
	--		of the other conditions are sufficient to guarantee that. It would probably
	--		better to introduce another local state variable such as 'isActive' (being the
	--		opposite of isStopped) but that would need more-careful review.

	if status.tracksStarted == 0 and
		status.audioState & DECODE_STOPPING == 0 and
		(status.bytesReceivedL > self.threshold or not self.stream) and
		status.outputTime > 50 then

--	FIXME in a future release we may change the the threshold to use
--	the amount of audio buffered, see Bug 6442
--		status.outputTime / 10 > self.threshold

		if self.autostart == '1' and not self.sentResume then
			log:debug("resume audio bytesReceivedL=", status.bytesReceivedL, " outputTime=", status.outputTime, " threshold=", self.threshold)
			decode:resumeAudio()
			self.sentResume = true
			self.sentDecoderFullEvent = true -- fake it so we don't send STMl with pause

		elseif not self.sentDecoderFullEvent then
			-- Tell SC decoder buffer is full
			log:debug("status FULL")
			self:sendStatus(status, "STMl")

			self.sentDecoderFullEvent = true
		end
	end

	if status.decodeState & DECODE_RUNNING ~= 0 and 
		Framework:getTicks() > self.statusTimestamp + 1000
	then
		self:sendStatus(status, "STMt")

		-- buffer fullness debugging
		if log:isDebug() then
			local dbuf = (status.decodeFull * 100) / status.decodeSize
			local obuf = (status.outputFull * 100) / status.outputSize

			log:info(string.format('%0.1f%%/%0.1f%%', dbuf, obuf))

			iconbar:showDebug(string.format('%0.1f%%/%0.1f%%', dbuf, obuf), 10)
		end
	end

	-- stream metadata or status codes
	local packet = decode:dequeuePacket()
	if packet then
		self.slimproto:send(packet)
	end
end


function _ipstring(ip)
	if (type(ip) == "string") then
		return ip
	end

	local str = {}
	for i = 4,1,-1 do
		str[i] = string.format("%d", ip & 0xFF)
		ip = ip >> 8
	end
	return table.concat(str, ".")
end


function _streamConnect(self, serverIp, serverPort, reader, writer)
	log:info("connect ", _ipstring(serverIp), ":", serverPort, " ", string.match(self.header, "(.-)\n"))

	if serverIp ~= self.slimproto:getServerIp() then
		log:info(self.header)
	end

	_setSource(self, "stream")

	self.stream = Stream:connect(serverIp, serverPort)

	-- The following manipluates the metatable for the stream object to allow Http and other streaming
	-- to use different read and write methods while using a common constructor which reuses the same
	-- C userdata for the object (and hence the same metatable)
	local m = getmetatable(self.stream)

	-- stash the location of the standard stream methods stream:read and stream:write on first use
	if m._streamRead == nil then
		m._streamRead  = m.read
		m._streamWrite = m.write
	end

	if reader and writer then
		-- use given stream methods
		m.read  = reader
		m.write = writer
	elseif self.flags & 0x20 == 0x20 then
		-- use Rtmp methods
		m.read  = Rtmp.read
		m.write = Rtmp.write
	else
		-- use standard stream methods
		m.read  = m._streamRead
		m.write = m._streamWrite
	end 

	local wtask = Task("streambufW", self, _streamWrite, nil, Task.PRIORITY_AUDIO)
	self.jnt:t_addWrite(self.stream, wtask, STREAM_WRITE_TIMEOUT)
	
	self.rtask = Task("streambufR", self, _streamRead, nil, Task.PRIORITY_AUDIO)
	self.jnt:t_addRead(self.stream, self.rtask, STREAM_READ_TIMEOUT)

	self.slimproto:sendStatus('STMc')
end


function _streamDisconnect(self, reason, flush)
	if not self.stream then
		if flush then
			log:debug("flush streambuf")
			Stream:flush()
			self.slimproto:sendStatus('STMf')
		end
		return
	end

	log:debug("disconnect streambuf")

	self.jnt:t_removeWrite(self.stream)
	self.jnt:t_removeRead(self.stream)

	self.stream:disconnect()
	self.stream = nil

	-- Notify SqueezeCenter the stream is closed
	if (flush) then
		Stream:flush()
		self.slimproto:sendStatus('STMf')
	else
		self.slimproto:send({
			opcode = "DSCO",
			reason = reason,
		})
	end
end


function _streamWrite(self, networkErr)
	if networkErr then
		log:warn("write error: ", networkErr)
		self:_streamDisconnect(TCP_CLOSE_LOCAL_RST)
		return
	end

	local status, err = self.stream:write(self, self.header)
	self.jnt:t_removeWrite(self.stream)

	if err then
		log:warn("write error: ", err)
	end
end


function _streamRead(self, networkErr)
	if networkErr then
		log:warn("read error: ", networkErr)
		self:_streamDisconnect(TCP_CLOSE_LOCAL_RST)
		return
	end

	local n = self.stream:read(self)
	while n do
		-- stop reading if the decoder is running. the socket will
		-- be added again by the status timer. this prevents the 
		-- streambuf starving the cpu
		if self.sentResumeDecoder then
			self.jnt:t_removeRead(self.stream)
		end

		_, networkErr = Task:yield(false)

		n = self.stream:read(self)
	end

	self:_streamDisconnect((n == false) and TCP_CLOSE_FIN or TCP_CLOSE_REMOTE_RST)
end


function _streamHttpHeaders(self, headers)
	-- send stream http headers to SqueezeCenter
	self.slimproto:send({
		opcode = "RESP",
		headers = headers,
	})
end


function _strm(self, data)
	if data.command ~= 't' then
		log:debug("strm ", data.command)
	end

	if data.command == 's' then
		-- start

		-- if we aborted the stream early, or there's any junk left 
		-- over, flush out whatever's left.
		self:_streamDisconnect(nil, true)

		-- reset stream state
		self.flags = data.flags
		self.mode = data.mode
		self.header = data.header
		self.autostart = data.autostart
		self.threshold = data.threshold * 1024

		self.sentResume = false
		self.sentResumeDecoder = false
		self.sentDecoderFullEvent = false
		self.sentDecoderUnderrunEvent = false
		self.sentOutputUnderrunEvent = false
		self.sentAudioUnderrunEvent = false
		self.isLooping = false

		local serverIp = data.serverIp == 0 and self.slimproto:getServerIp() or data.serverIp

		if self.flags == 0x10 then
			-- custom handler
			local handlerId = string.match(self.header, "spdr://(%w-)%?")

			-- Also support URLs of the format <protocol>://...
			if not handlerId then
				handlerId = string.match(self.header, "^(%w-)://")
			end

			if streamHandlers[handlerId] then
				log:info("using custom handler ", handlerId)
				streamHandlers[handlerId](self, data, decode)
			else
				log:warn("bad custom handler ", handlerId)
			end
		else
			-- standard stream - start the decoder and connect
			decode:start(string.byte(data.mode),
			     string.byte(data.transitionType),
			     data.transitionPeriod,
			     data.replayGain,
			     data.outputThreshold,
			     data.flags & 0x03,
			     string.byte(data.pcmSampleSize),
			     string.byte(data.pcmSampleRate),
			     string.byte(data.pcmChannels),
			     string.byte(data.pcmEndianness)
		    )
			self:_streamConnect(serverIp, data.serverPort)
		end

	elseif data.command == 'q' then
		-- quit
		-- XXXX check against ip3k
		self:_stopPauseAndStopTimers()
		self:stopInternal()

	elseif data.command == 'f' then
		-- flush
		decode:flush()
		self:_streamDisconnect(nil, true)

	elseif data.command == 'p' then
		-- pause
		self:_stopPauseAndStopTimers()
		local interval_ms = data.replayGain
		self:_pauseInternal(interval_ms)

	elseif data.command == 'a' then
		-- skip ahead
		local interval_ms = data.replayGain

		decode:skipAhead(interval_ms)

	elseif data.command == 'u' then
		-- unpause
		Framework.wakeup()
		local jiffies = data.replayGain

		log:debug("resume unpause")
		decode:resumeAudio(jiffies)
		self.sentResume = true
		self.sentDecoderFullEvent = true -- fake, as the strm-u means that the server is no longer waiting for STMl
		self.slimproto:sendStatus('STMr')

	elseif data.command == 't' then
		-- timestamp
		local server_ts = data.replayGain

		self.slimproto:sendStatus('STMt', server_ts)
	end

	return true
end


function stopInternal(self)
	if self.source ~= "capture" then
		-- don't call stop when using capture mode
		decode:stop()

		_setSource(self, "off")
	end
	self:_streamDisconnect(nil, true)

	self.tracksStarted = 0
end


function pause(self)
	self:_pauseInternal(nil)
end


function _pauseInternal(self, interval_ms)
	decode:pauseAudio(interval_ms)
	if interval_ms == 0 then
		self.slimproto:sendStatus('STMp')
	end
end


function _cont(self, data)
	log:debug("cont loop=", data.loop, " icy=", data.icyMetaInterval)

	if data.loop == 1 then
		self.isLooping = true
		Stream:markLoop()
	end

	-- icy metainterval
	if data.icyMetaInterval > 0 then
		Stream:icyMetaInterval(data.icyMetaInterval)
	end

	-- wma guid's
	if data.guid_len then
		decode:setGuid(data.guid_len, data.guid)
	end

	self.autostart = (self.autostart == '2') and '0' or '1'
end


function _aude(self, data)
	 decode:audioEnable(data.enable)
end

function _setd(self, data)
 
	-- only send response if we're queried (no additional data)
	if data.command == 0 and #data.packet <= 5 then

		-- get playername
		local player = Player:getLocalPlayer()

		self.slimproto:send({
			opcode = 'SETD',
			data = table.concat({
				string.sub(data.packet, 5, 5),
				player:getName()
			})
		})

	end
end


function incrementSequenceNumber(self)
	self.sequenceNumber = self.sequenceNumber + 1
	return self:getCurrentSequenceNumber()
end

function getCurrentSequenceNumber(self)
	return self.sequenceNumber
end

function isSequenceNumberInSync(self, serverSequenceNumber)
	if serverSequenceNumber ~= self.sequenceNumber then
		log:debug("server sequence # out of sync. server: ", serverSequenceNumber, " local: ", self.sequenceNumber)
		return false
	end
	return true
end

-- volumeMap has the correct gain settings for volume settings 1-100. Based on Boom volume curve
--todo when this becomes SP device specific move to service method and make it per-device 
local _defaultVolumeToGain = {
16, 18, 22, 26, 31, 36, 43, 51, 61, 72, 85, 101, 120, 142, 168, 200, 237, 281, 333, 395, 468, 555, 658, 781, 926, 980, 1037, 1098, 1162, 1230, 1302, 1378, 1458, 1543, 1634, 1729, 1830, 1937, 2050, 2048, 2304, 2304, 2560, 2816, 2816, 3072, 3328, 3328, 3584, 3840, 4096, 4352, 4608, 4864, 5120, 5376, 5632, 6144, 6400, 6656, 7168, 7680, 7936, 8448, 8960, 9472, 9984, 10752, 11264, 12032, 12544, 13312, 14080, 14848, 15872, 16640, 17664, 18688, 19968, 20992, 22272, 23552, 24832, 26368, 27904, 29696, 31232, 33024, 35072, 37120, 39424, 41728, 44032, 46592, 49408, 52224, 55296, 58624, 61952, 65536,
}

local _serverVolumeToGain = _defaultVolumeToGain -- same since Squeezeplay.pm uses Boom curve

--sb2 curve
--local _serverVolumeToGain = {
--232, 246, 260, 276, 292, 309, 327, 346, 366, 388, 411, 435, 460, 487, 516, 546, 578, 612, 648, 686, 726, 769, 814, 862, 912, 966, 1022, 1082, 1146, 1213, 1284, 1359, 1439, 1523, 1613, 1707, 1807, 1913, 2026, 2048, 2304, 2304, 2560, 2816, 2816, 3072, 3072, 3328, 3584, 3840, 4096, 4352, 4608, 4864, 5120, 5376, 5632, 5888, 6400, 6656, 7168, 7424, 7936, 8448, 8960, 9472, 9984, 10496, 11264, 11776, 12544, 13312, 14080, 14848, 15872, 16640, 17664, 18688, 19712, 20992, 22272, 23552, 24832, 26368, 27904, 29440, 31232, 33024, 35072, 37120, 39168, 41472, 44032, 46592, 49408, 52224, 55296, 58368, 61952, 65536,
--}

--provide hook for applets to modify the gain curve
function overrideDefaultVolumeToGain(self, value)
	_defaultVolumeToGain = value
end

function setVolume(self, volume, stateOnly)
	log:debug("setVolume: ", volume)

	self.volume = volume
	if (not stateOnly) then
		self:_setGain(self:_getGainFromVolume(volume))
	end
end


function getVolume(self)
	return self.volume
end


function _getGainFromVolume(self, volume)
	return _defaultVolumeToGain[volume]
end


function _setGain(self, gain)
	log:debug("_setGain: ", gain)

	local data = { gainL = gain, gainR = gain}

	self:_audg(data, true)
end


function _audg(self, data, isLocal)
	if not isLocal then
		local gain, volume = self:translateServerGain(data.gainL)

		local serverSequenceNumber = data.sequenceNumber
		if serverSequenceNumber and not self:isSequenceNumberInSync(serverSequenceNumber) then
			--ignore since not in sync
			return
		end

		self:_stopPauseAndStopTimers()
		
		-- NOTE: not using server value for self.volume, because fades come in through the audg mechanism.
		-- Instead, wait for the player status before setting the locally held self.volume.
		-- This could cause a case where a remote UI changes volume and
		-- the local volume isn't seen as right until playerstatus completes.
		-- Also, during a fade, the displayed volume will be the eventual volume for fade-in
		-- and the initial volume for fade-out. 
	end

	log:debug("gainL, gainR: ", data.gainL, " ", data.gainR)

	decode:audioGain(data.gainL, data.gainR)
end


function translateServerGain(self, serverGain)

	for volume = 0, (#_serverVolumeToGain - 1) do
		--find value close to the matching value (use lower value if in between
		local gain = volume == 0 and 0 or _serverVolumeToGain[volume]
		local nextGain = _serverVolumeToGain[volume + 1]
		if serverGain >= gain and  serverGain < nextGain then
			return self:_getGainFromVolume(volume), volume
		end
	end
	--use final value
	return self:_getGainFromVolume(#_serverVolumeToGain), #_serverVolumeToGain
end


function setCaptureVolume(self, volume)
	self.captureVolume = volume
	if self:getCapturePlayMode() == "play" then
		local gain = self:_getGainFromVolume(self.captureVolume)
		log:debug("Setting capture volume: ", self.captureVolume, " gain: ", self:_getGainFromVolume(#_serverVolumeToGain))

		decode:captureGain(gain, gain)
	end
end


function getSource(self)
	return self.source
end


function getCaptureVolume(self)
	return self.captureVolume
end


function getCapturePlayMode(self)
	return self.capturePlayMode
end


function setCapturePlayMode(self, capturePlayMode)
	self.capturePlayMode = capturePlayMode

	if capturePlayMode == nil then
		-- turn off capture mode
		_setSource(self, "off")
		return
	end

	_setSource(self, "capture")

	if capturePlayMode == "play" then
		self:setCaptureVolume(self:getCaptureVolume())
	else
		-- mute capture
		-- todo: seems cpu intensive, can we actually just stop capture but not switch back to local player
		decode:captureGain(0, 0)
	end
end


function _stopPauseAndStopTimers(self)
	log:debug("stopping local pause timer")
	if self.localPauseTimer then
		self.localPauseTimer:stop()
	end

	if self.localStopTimer then
		self.localStopTimer:stop()
	end
end


function isLocalPauseOrStopTimeoutActive(self)
	return (self.localPauseTimer and self.localPauseTimer:isRunning())
		or (self.localStopTimer and self.localStopTimer:isRunning())
end


function startLocalPauseTimeout(self)
	if not self.localPauseTimer then
		self.localPauseTimer = Timer(    LOCAL_PAUSE_STOP_TIMEOUT,
						function ()
							log:debug("Local pause since remote stop timed out")
							self:_pauseInternal(nil)
						end,
						true)
	end

	self.localPauseTimer:restart()
end


function startLocalStopTimeout(self)
	if not self.localStopTimer then
		self.localStopTimer = Timer(    LOCAL_PAUSE_STOP_TIMEOUT,
						function ()
							log:debug("Local stop since remote stop timed out")
							self:stopInternal()
						end,
						true)
	end

	self.localStopTimer:restart()
end


function registerHandler(self, id, handler)
	log:info("registering handler ", id)
	streamHandlers[id] = handler
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
