
local assert, tostring = assert, tostring


local oo                     = require("loop.base")

local string                 = require("string")

local Decode                 = require("squeezeplay.decode")
local Stream                 = require("squeezeplay.stream")
local SlimProto              = require("jive.net.SlimProto")

local Task                   = require("jive.ui.Task")
local Timer                  = require("jive.ui.Timer")
local Framework              = require("jive.ui.Framework")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("audio")


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



function __init(self, jnt, slimproto)
	assert(slimproto)

	local obj = oo.rawnew(self, {})

	obj.jnt = jnt
	obj.slimproto = slimproto

	obj.slimproto:statusPacketCallback(function(_, event, serverTimestamp)
		local status = Decode:status()

		status.opcode = "STAT"
		status.event = event
		status.serverTimestamp = serverTimestamp
		
		return status
	end)

	obj.slimproto:subscribe("strm", function(_, data)
		return obj:_strm(data)
	end)

	obj.slimproto:subscribe("cont", function(_, data)
		return obj:_cont(data)
	end)

	obj.timer = Timer(100, function()
		obj:_timerCallback()
	end)
	obj.timer:start()


	self.threshold = 0
	self.tracksStarted = 0

	self.statusTimestamp = 0

	self.sentResume = false
	self.sentDecoderFullEvent = false
	self.sentDecoderUnderrunEvent = false
	self.sentOutputUnderrunEvent = false
	self.sentAudioUnderrunEvent = false

	log:info("playback init")
	
	return obj
end


function sendStatus(self, status, event, serverTimestamp)
	status.opcode = "STAT"
	status.event = event
	status.serverTimestamp = serverTimestamp

	self.slimproto:send(status)
	self.statusTimestamp = Framework:getTicks()
end


function _timerCallback(self)
	local status = Decode:status()


	-- enable stream reads when decode buffer is not full
	if status.decodeFull < status.decodeSize and self.stream then
		self.jnt:t_addRead(self.stream, self.rtask, 0) -- XXXX timeout?
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
				-- XXXX not supported event
			end

			log:info("status DECODE UNDERRUN")
			self:sendStatus(status, "STMd")

			self.sentDecoderUnderrunEvent = true
			self.sentDecoderFullEvent = false

			Decode:songEnded()
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

			log:info("status AUDIO UNDERRUN")
			self:sendStatus(status, "STMu")

			self.sentAudioUnderrunEvent = true

		elseif not self.sentOutputUnderrunEvent and
			self.stream then

			log:info("status OUTPUT UNDERRUN")
			self:sendStatus(status, "STMo")

			self.sentOutputUnderrunEvent = true
		end
	else
		self.sentOutputUnderrunEvent = false
		self.sentAudioUnderrunEvent = false
	end


	-- Cannot test of stream is not nil because stream may be complete (and closed) before track start
	if status.decodeState & DECODE_RUNNING and (self.tracksStarted < status.tracksStarted) then

		log:info("status TRACK STARTED")
		self:sendStatus(status, "STMs")

		self.tracksStarted = status.tracksStarted
	end


	-- XXXX
	if status.decodeFull > self.threshold and
		status.decodeState & DECODE_RUNNING == 0 then

		if self.autostart == '1' and not self.sentResume then
			log:info("resume decodeFull=", status.decodeFull, " threshold=", self.threshold)
			Decode:resume()
			self.sentResume = true
			self.sentDecoderFullEvent = true -- fake it so we don't send STMl with pause

		elseif not self.sentDecoderFullEvent then
			-- Tell SC decoder buffer is full
			log:info("status FULL")
			self:sendStatus(status, "STMl")

			self.sentDecoderFullEvent = true
		end
	end

	if status.decodeState & DECODE_RUNNING and 
		Framework:getTicks() > self.statusTimestamp + 1000
	then
		self:sendStatus(status, "STMt")
	end

	-- stream metadata
	local metadata = Decode:streamMetadata()
	if metadata then
		-- XXXX extend META with more data
		self.slimproto:send({
			opcode = "META",
			metadata = metadata.metadata,
		})
	end
end


function _streamConnect(self, serverIp, serverPort)
	self.stream = Stream:connect(serverIp, serverPort)

	log:info("connect streambuf")

	local wtask = Task("streambufW", self, _streamWrite)
	self.jnt:t_addWrite(self.stream, wtask, 5)
	
	self.rtask = Task("streambufR", self, _streamRead)
	self.jnt:t_addRead(self.stream, self.rtask, 0) -- XXXX timeout?

	self.slimproto:sendStatus('STMc')
end


function _streamDisconnect(self, reason, flush)
	if not self.stream then
		return
	end

	log:info("disconnect streambuf")

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
		log:error("write error: ", networkErr)
		self:_streamDisconnect(TCP_CLOSE_LOCAL_RST)
		return
	end

	local status, err = self.stream:write(self, self.header)
	self.jnt:t_removeWrite(self.stream)

	if err then
		log:error("write error: ", err)
	end
end


function _streamRead(self, networkErr)
	if networkErr then
		log:error("read error: ", networkErr)
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

	self:_streamDisconnect((n == false) and TCP_CLOSE_FIN or TCP_CLOSE_LOCAL_RST)
end


function _streamHttpHeaders(self, headers)
	-- send stream http headers to SqueezeCenter
	self.slimproto:send({
		opcode = "RESP",
		headers = headers,
	})
end


function _strm(self, data)
	if data.command ~= 't' then log:info("strm ", data.command)	end

	if data.command == 's' then
		-- start

		-- if we aborted the stream early, or there's any junk left 
		-- over, flush out whatever's left.
		self:_streamDisconnect(nil, true)

		Decode:start(string.byte(data.mode),
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

		-- connect to server
		self:_streamConnect(serverIp, data.serverPort)

	elseif data.command == 'q' then
		-- quit
		-- XXXX check against ip3k
		Decode:stop()
		self:_streamDisconnect(nil, true)

		self.tracksStarted = 0

	elseif data.command == 'f' then
		-- flush
		Decode:flush()
		if self.stream then
			self.stream:flush()
		end

	elseif data.command == 'p' then
		-- pause
		local interval_ms = data.replayGain

		Decode:pause(interval_ms)
		if interval_ms == 0 then
			self.slimproto:sendStatus('STMp')
		end

	elseif data.command == 'a' then
		-- skip ahead
		local interval_ms = data.replayGain

		Decode:skipAhead(interval_ms)

	elseif data.command == 'u' then
		-- unpause
		local interval_ms = data.replayGain

		Decode:resume(interval_ms)
		self.slimproto:sendStatus('STMr')

	elseif data.command == 't' then
		-- timestamp
		local server_ts = data.replayGain

		self.slimproto:sendStatus('STMt', server_ts)
	end

	return true
end


function _cont(self, data)
	log:info("cont loop=", data.loop)

	if data.loop == 1 then
		log:warn("LOOP")
		self.stream:markLoop()
	end

	-- icy metainterval
	if data.icyMetaInterval > 0 then
		self.stream:icyMetaInterval(data.icyMetaInterval)
	end

	-- XXXX wma guid's

	self.autostart = (self.autostart == '2') and '0' or '1'
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
