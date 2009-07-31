
local assert, tostring, type = assert, tostring, type


local oo                     = require("loop.base")

local string                 = require("string")
local table                  = require("table")

local hasDecode, decode      = pcall(require, "squeezeplay.decode")
local hasSprivate, spprivate = pcall(require, "spprivate")
local Stream                 = require("squeezeplay.stream")
local SlimProto              = require("jive.net.SlimProto")

local Task                   = require("jive.ui.Task")
local Timer                  = require("jive.ui.Timer")
local Framework              = require("jive.ui.Framework")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("audio.decode")


module(..., oo.class)


-- decode and audio states
local DECODE_RUNNING        = (1 << 0)
local DECODE_UNDERRUN       = (1 << 1)
local DECODE_ERROR          = (1 << 2)
local DECODE_NOT_SUPPORTED  = (1 << 3)

-- disconnect codes
local TCP_CLOSE_FIN           = 0
local TCP_CLOSE_LOCAL_RST     = 1
local TCP_CLOSE_REMOTE_RST    = 2
local TCP_CLOSE_UNREACHABLE   = 3
local TCP_CLOSE_LOCAL_TIMEOUT = 4


-- Do NOT set a read timeout, the stream may be paused indefinately
local STREAM_READ_TIMEOUT = 0
local STREAM_WRITE_TIMEOUT = 5


function __init(self, jnt, slimproto)
	assert(slimproto)

	local obj = oo.rawnew(self, {})

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

	obj.timer = Timer(100, function()
		obj:_timerCallback()
	end)
	obj.timer:start()

	if hasSprivate then
		spprivate:initAudio(slimproto)
	end
	decode:initAudio(slimproto)

	self.threshold = 0
	self.tracksStarted = 0

	self.statusTimestamp = 0

	self.sentResume = false
	self.sentDecoderFullEvent = false
	self.sentDecoderUnderrunEvent = false
	self.sentOutputUnderrunEvent = false
	self.sentAudioUnderrunEvent = false

	return obj
end


function free(self)
	decode:stop()
	self.timer:stop()
end


-- Load a file and play it in a loop. This is for playing test tones.
-- Currently only works with mp3 files.
function playFileInLoop(self, file)
--	assert(string.match(file , ".mp3"), "Only mp3 files are supported")

	log:info("loop file ", file)

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
		-- when XXXX

		if not self.sentAudioUnderrunEvent and
			self.sentDecoderUnderrunEvent then

			log:debug("status AUDIO UNDERRUN")
			decode:stop() -- XXX need to let last buffer play out before stop
			self:sendStatus(status, "STMu")

			self.sentAudioUnderrunEvent = true

		elseif not self.sentOutputUnderrunEvent and
			self.stream then

			log:debug("status OUTPUT UNDERRUN")
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
		and (self.tracksStarted < status.tracksStarted) then

		log:debug("status TRACK STARTED")
		self:sendStatus(status, "STMs")

		self.tracksStarted = status.tracksStarted
	end

	-- Start the decoder when some encoded data is buffered
	-- FIXME the threshold could be decoder specific?
	if status.decodeFull > 2048 and
		(self.autostart == '0' or self.autostart == '1') and
		status.decodeState & DECODE_RUNNING == 0 then

		log:debug("resumeDecoder")
		decode:resumeDecoder()
	end

	-- Start the audio when enough encoded data is been received
	if status.bytesReceivedL > self.threshold and
		status.outputTime > 50 and
		status.audioState & DECODE_RUNNING == 0 then

--	FIXME in a future release we may change the the threshold to use
--	the amount of audio buffered, see Bug 6442
--	if status.outputTime / 10 > self.threshold and
--		status.audioState & DECODE_RUNNING == 0 then

		if self.autostart == '1' and not self.sentResume then
			log:debug("resume bytesReceivedL=", status.bytesReceivedL, " outputTime=", status.outputTime, " threshold=", self.threshold)
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


function _streamConnect(self, serverIp, serverPort)
	log:info("connect ", _ipstring(serverIp), ":", serverPort, " ", string.match(self.header, "(.-)\n"))

	self.stream = Stream:connect(serverIp, serverPort)

	local wtask = Task("streambufW", self, _streamWrite)
	self.jnt:t_addWrite(self.stream, wtask, STREAM_WRITE_TIMEOUT)
	
	self.rtask = Task("streambufR", self, _streamRead)
	self.jnt:t_addRead(self.stream, self.rtask, STREAM_READ_TIMEOUT)

	self.slimproto:sendStatus('STMc')
end


function _streamDisconnect(self, reason, flush)
	if not self.stream then
		return
	end

	log:debug("disconnect streambuf")

	self.jnt:t_removeWrite(self.stream)
	self.jnt:t_removeRead(self.stream)

	self.stream:disconnect()
	if flush then
		self.stream:flush()
	end
	self.stream = nil

	-- Notify SqueezeCenter the stream is closed
	if (flush) then
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
		if n == 0 then
			-- buffer full
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

		local serverIp = data.serverIp == 0 and self.slimproto:getServerIp() or data.serverIp

		-- reset stream state
		-- XXXX flags
		self.header = data.header
		self.autostart = data.autostart
		self.threshold = data.threshold * 1024

		self.sentResume = false
		self.sentDecoderFullEvent = false
		self.sentDecoderUnderrunEvent = false
		self.sentOutputUnderrunEvent = false
		self.sentAudioUnderrunEvent = false
		self.isLooping = false

		-- connect to server
		self:_streamConnect(serverIp, data.serverPort)

	elseif data.command == 'q' then
		-- quit
		-- XXXX check against ip3k
		decode:stop()
		self:_streamDisconnect(nil, true)

		self.tracksStarted = 0

	elseif data.command == 'f' then
		-- flush
		decode:flush()
		if self.stream then
			self.stream:flush()
		end

	elseif data.command == 'p' then
		-- pause
		local interval_ms = data.replayGain

		decode:pauseAudio(interval_ms)
		if interval_ms == 0 then
			self.slimproto:sendStatus('STMp')
		end

	elseif data.command == 'a' then
		-- skip ahead
		local interval_ms = data.replayGain

		decode:skipAhead(interval_ms)

	elseif data.command == 'u' then
		-- unpause
		local interval_ms = data.replayGain

		decode:resumeAudio(interval_ms)
		self.slimproto:sendStatus('STMr')

	elseif data.command == 't' then
		-- timestamp
		local server_ts = data.replayGain

		self.slimproto:sendStatus('STMt', server_ts)
	end

	return true
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


function _audg(self, data)
	 decode:audioGain(data.gainL, data.gainR)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
