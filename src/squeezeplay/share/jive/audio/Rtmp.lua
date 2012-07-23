-- This module implements a subset of the Adobe RTMP protocol as specified by:
--  http://www.adobe.com/devnet/rtmp/pdf/rtmp_specification_1.0.pdf
--
-- It provides direct streaming for rtmp and is primarily designed to be used with the BBCRadio applet or BBCiPlayer plugin
--
-- (c) Adrian Smith (Triode), 2009, 2010, 2011, triode1@btinternet.com
--
-- The implementation (api v2) here contains both the low level state machine for processing the rtmp protocol and
-- serialisation code for generating amf0 request objects.  Parsing of amf0 responses is not implemented here and requires
-- server support.
--
-- The protocol state machine and all packet processing is now implemented in C to improve performance and resource demands.
-- The remaining lua code is used to create serialised rtmp request packets which are passed to the C protocol implementation.
--
-- The implementation makes the following assumptions:
--
-- 1) streams use a streamingId of 1 (it ignores the streamingId inside the amf0 _result reponse to a createStream message)
-- 2) only implements single byte chunk headers (chunk id < 63)
-- 3) timestamps are not send in any packets sent to the server (they are always set to 0)
--
-- Due to the way the stream object is created it is necessary to switch methods in the stream object's meta table
-- so that the Rtmp read and write methods here are used (this is done in Playback.lua)
--

local string, table, math, pairs, type = string, table, math, pairs, type

local Stream   = require("squeezeplay.stream")
local mime     = require("mime")
local hasC, rtmpC = pcall(require, "rtmp")

local debug    = require("jive.utils.debug")
local log      = require("jive.utils.log").logger("audio.decode")

module(...)

local FLASH_VER  = "LNX 10,0,22,87"

-- C read method
if hasC then
	read = rtmpC.read
end

-- session params (can't be stored in the object as we reuse the streambuf object)
rtmpMessages = {} -- not local so it can be accessed from C
local slimproto


function write(stream, playback, header)
	-- initialise
	rtmpMessages = {}
	slimproto = playback.slimproto

	if not hasC then
		log:warn("no rtmp binary module loaded - stream not supported")
		return
	end

	-- extract the pre built rtmp packets or params within the header
	for k, v in string.gmatch(header, "(%w+)=([a-zA-Z0-9%/%+]+%=*)&") do
		rtmpMessages[k] = mime.unb64("", v)
	end

	-- create serialised amf packets if params rather than prebuild packets extracted
	if rtmpMessages["streamname"] then
		rtmpMessages["create"]  = createStreamPacket()
		rtmpMessages["play"]    = playPacket(rtmpMessages["streamname"], rtmpMessages["live"], rtmpMessages["start"])
		rtmpMessages["connect"] = connectPacket(rtmpMessages["app"], rtmpMessages["swfurl"] or "", rtmpMessages["tcurl"])
		if rtmpMessages["subname"] then
			rtmpMessages["subscribe"] = subscribePacket(rtmpMessages["subname"])
		end
	end

	-- start the rtmp protocol by sending the handshake (implemented in C)
	return rtmpC.sendHandshake(stream);
end


-- called from C to send RESP message back to server
function streamStartEvent()
	if rtmpMessages["meta"] ~= nil then
		slimproto:send({ opcode = "RESP", headers = "" })
	end
end


-- called from C to send Metadata back to server
function sendMeta(msg)
	if rtmpMessages["meta"] == nil or rtmpMessages["meta"] == "send" then
		slimproto:send({ opcode = "META", data = msg })
	end
end


---------------------------------------------------------------------------------------------------------------------
-- amf packet formatting and serialisation code
-- this is added for api version 2 so we don't rely on server code to generate serialsed amf0
---------------------------------------------------------------------------------------------------------------------

local function packNumber(v, len, le)
	local t = {}
	for i = 1, len do
		t[#t + 1] = string.char(v & 0xFF)
		v = v >> 8
	end
	local str = table.concat(t)
	return le and str or string.reverse(str)
end


-- emulate pack "d" to serialise numbers as doubles
-- this only implements most signficant 28 bits of the mantissa, rest are 0
function _todouble(v)
	local s, e, m

	if v == 0 then
		return string.char(0, 0, 0, 0, 0, 0, 0, 0)
	end

	s = v > 0 and 0 or 1
	v = v > 0 and v or -v
	e = 0

	local i = v
	while i >= 2 do
		i = i / 2
		e = e + 1
	end

	m = v / math.pow(2, e - 28)
	e = e + 1023

	return string.char(
		(s << 7) | 
		((e & 0x7f0) >> 4),
		((e & 0x00f) << 4) |
		((m & 0x0f000000) >> 24),
		 (m & 0x00ff0000) >> 16,
		 (m & 0x0000ff00) >>  8,
		 (m & 0x000000ff),
		0, 0, 0)
end


function amfFormatNumber(n)
	return string.char(0x00) .. _todouble(n)
end


function amfFormatBool(b)
	return string.char(0x01, b and 0x01 or 0x00)
end


function amfFormatString(s)
	return string.char(0x02) .. packNumber(string.len(s), 2) .. s
end


function amfFormatNull()
	return string.char(0x05)
end


function amfFormatObject(o)
	local res = string.char(0x03)
	for k, v in pairs(o) do
		res = res .. packNumber(string.len(k), 2) .. k
		if type(v) == 'number' then
			res = res .. amfFormatNumber(v)
		elseif type(v) == 'string' then
			res = res .. amfFormatString(v)
		else
			res = res .. amfFormatNull()
		end
	end
	return res .. string.char(0x00, 0x00, 0x09)
end


function formatRtmp(chan, type, streamId, body)
	return
		string.char(chan & 0x7f) ..        -- chan X, format 0
		string.char(0x00, 0x00, 0x00) ..   -- timestamp
		packNumber(string.len(body), 3) .. -- length
		string.char(type & 0xff) ..        -- type
		packNumber(streamId, 4, true) ..   -- streamId
		body                               -- body
end


function connectPacket(app, swfurl, tcurl)
	return formatRtmp(0x03, 20, 0,
		amfFormatString('connect') ..
		amfFormatNumber(1) ..
		amfFormatObject({
			app         = app, 
			swfUrl      = swfurl,
			tcUrl       = tcurl,
			audioCodecs = 0x0404,
			videoCodecs = 0x0000,
			flashVer    = FLASH_VER
		})
	)
end


function createStreamPacket()
	return formatRtmp(0x03, 20, 0,
		amfFormatString('createStream') ..
		amfFormatNumber(2) ..
 		amfFormatNull()
	)
end


function subscribePacket(subscribe)
	return formatRtmp(0x03, 20, 0,
		amfFormatString('FCSubscribe') ..
		amfFormatNumber(0) ..
		amfFormatNull() ..
		amfFormatString(subscribe)
	)
end


function playPacket(streamname, live, start)
	return formatRtmp(0x08, 20, 1, 
		amfFormatString('play') ..
		amfFormatNumber(0) ..
		amfFormatNull() ..
		amfFormatString(streamname) ..
		amfFormatNumber(live and -1000 or (start or 0) * 1000)
	)
end
