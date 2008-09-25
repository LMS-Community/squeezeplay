
--[[
=head1 NAME

jive.net.SlimProto - A TCP socket that implements the slimproto.

=head1 DESCRIPTION

This class implements a TCP socket running in a L<jive.net.NetworkThread>.

=head1 SYNOPSIS

 -- create a Comet socket to communicate with http://192.168.1.1:9000/
 local comet = jive.net.Comet(jnt, "192.168.1.1", 9000, "/cometd", "slimserver")

 -- subscribe to an event
 -- will callback to func whenever there is an event
 -- playerid may be nil
 comet:subscribe('/slim/serverstatus', func, playerid, {'serverstatus', 0, 50, 'subscribe:60'})

 -- unsubscribe from an event
 comet:unsubscribe('/slim/serverstatus', func)

 -- or unsubscribe all callbacks
 comet:unsubscribe('/slim/serverstatus')

 -- send a non-subscription request
 -- playerid may be nil
 -- request is a table (array) containing the raw request to pass to SlimServer
 comet:request(func, playerid, request)

 -- add a callback function for an already-subscribed event
 comet:addCallback('/slim/serverstatus', func)

 -- remove a callback function
 comet:removeCallback('/slim/serverstatus', func)

 -- start!
 comet:connect()

 -- disconnect
 comet:disconnect()

 -- batch a set of calls together into one request
  comet:startBatch()
  comet:subscribe(...)
  comet:request(...)
  comet:endBatch()

=head1 FUNCTIONS

=cut
--]]

local assert, ipairs, tonumber = assert, ipairs, tonumber


local oo          = require("loop.base")

local math        = require("math")
local string      = require("string")
local table       = require("jive.utils.table")

local Framework   = require("jive.ui.Framework")
local Timer       = require("jive.ui.Timer")

local SocketTcp   = require("jive.net.SocketTcp")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.slimproto")


module(..., oo.class)


local PORT = 3483

local DEVICEID = 7 -- XXXX using recevier device id

local WRITE_TIMEOUT = 10

-- connection state
local UNCONNECTED    = "UNCONNECTED"    -- not connected
local CONNECTED      = "CONNECTED"      -- connected


local function packNumber(v, len)
	local t = {}

	for i = 1,len do
		t[#t + 1] = string.char(v & 0xFF)
		v = v >> 8
	end

	return string.reverse(table.concat(t))
end


local function unpackNumber(str, pos, len)
	local v = 0
	for i = pos, pos + len - 1 do
		v = (v << 8) | (string.byte(str, i, i + 1) or 0)
	end
	return v
end


local function _hexDump(msg, str)
	local s = msg .. "\n" .. string.format('%04x ', 0)
	for i = 1, #str do
		s = s .. string.format('%02x', string.byte(str, i, i + 1))
		if i % 8 == 0 then
			s = s .. "\n" .. string.format('%04x ', i)
		else
			s = s .. " "
		end
	end

	log:info(s)
end


local opcodes = {
	HELO = function(self, data)
		assert(data.revision)
		assert(data.mac)
		assert(data.uuid)

		local macp = {}
		for v in string.gmatch(data.mac, "(%x%x)") do
			macp[#macp + 1] = string.char(tonumber(v, 16))
		end

		local uuidp = {}
		for v in string.gmatch(data.uuid or uuid, "(%x%x)") do
			uuidp[#uuidp + 1] = string.char(tonumber(v, 16))
		end

		return {
			packNumber(data.deviceID or DEVICEID, 1),
			packNumber(data.revision, 1),
			table.concat(macp),
			table.concat(uuidp),
			packNumber(0, 2), -- XXXX reconnection bit
			packNumber(0, 8), -- XXXX bytes received
			"EN", -- XXXX language
		}
	end,

	STAT = function(self, data)
		assert(#data.event == 4)
		assert(data.decodeSize)
		assert(data.decodeFull)
		assert(data.bytesReceivedL)
		assert(data.bytesReceivedH)
		assert(data.outputSize)
		assert(data.outputFull)
		assert(data.elapsed)
		assert(data.elapsed_jiffies)

		return {
			data.event,
			packNumber(0, 1), -- unused (num_crlf)
			packNumber(0, 2), -- unused (mas parameters)
			packNumber(data.decodeSize, 4),
			packNumber(data.decodeFull, 4),
			packNumber(data.bytesReceivedH, 4),
			packNumber(data.bytesReceivedL, 4),
			packNumber(data.signalStrength or 0, 2),
			packNumber(data.elapsed_jiffies, 4),
			packNumber(data.outputSize, 4),
			packNumber(data.outputFull, 4),
			packNumber(data.elapsed / 1000, 4),
			packNumber(data.voltage or 0, 2),
			packNumber(data.elapsed, 4),
			packNumber(data.serverTimestamp or 0, 4),
		}
	end,

	["IR  "] = function(self, data)
		return {
			packNumber(data.jiffies, 4),
			packNumber(data.format, 1),
			packNumber(data.noBits, 1),
			packNumber(data.code, 4),
		}
	end,

	RESP = function(self, data)
		assert(data.headers)

		return {
			data.headers
		}
	end,

	META = function(self, data)
		assert(data.metadata)

		return  {
			data.metadata
		}
	end,

	BODY = function(self, data)
		-- XXXX
		log:warn("TODO")
	end,

	DSCO = function(self, data)
		-- XXXX
		log:warn("TODO")
	end,

	aude = function(self, packet)
		return {
			enable = unpackNumber(packet, 5, 1),
		}
	end,

	audg = function(self, packet)
		local gainL, gainR, fixedDigital, preampAtten

		gainL = unpackNumber(packet, 5, 4) << 9
		gainR = unpackNumber(packet, 9, 4) << 9
		
		if #packet > 12 then
			fixedDigital = unpackNumber(packet, 13, 1)
		end

		if #packet > 13 then
			preampAtten = unpackNumber(packet, 14, 1)
		end

		if #packet > 14 then
			gainL = unpackNumber(packet, 15, 4)
			gainR = unpackNumber(packet, 19, 4)
		end

		return {
			gainL = gainL,
			gainR = gainR,
			fixedDigital = fixedDigital,
			preampAtten = preampAtten,
		}	end,

	strm = function(self, packet)
		return {
			command  = string.sub(packet, 5, 5),
			autostart = string.sub(packet, 6, 6),
			mode = string.sub(packet, 7, 7),
			pcmSampleSize = string.sub(packet, 8, 8),
			pcmSampleRate = string.sub(packet, 9, 9),
			pcmChannels = string.sub(packet, 10, 10),
			pcmEndianness = string.sub(packet, 11, 11),
			threshold = unpackNumber(packet, 12, 1),
			spdifEnable = string.sub(packet, 13, 13),
			transitionPeriod = unpackNumber(packet, 14, 1),
			transitionType = string.sub(packet, 15, 15),
			flags = unpackNumber(packet, 16, 1),
			outputThreshold = unpackNumber(packet, 17, 1),
			-- reserved = unpackNumber(packet, 18, 1),
			replayGain = unpackNumber(packet, 19, 4),
			serverPort = unpackNumber(packet, 23, 2),
			serverIp = unpackNumber(packet, 25, 4),
			header = string.sub(packet, 29)
		}
	end,

	body = function(self, packet)
		-- XXXX
		log:warn("TODO")
	end,

	cont = function(self, packet)
		return {
			icyMetaInterval = unpackNumber(packet, 5, 4),
			loop = unpackNumber(packet, 9, 1),
			-- XXXX read wma guid's
		}
	end,

	dsco = function(self, packet)
		-- XXXX
		log:warn("TODO")
	end,

	serv = function(self, packet)
		-- XXXX
		log:warn("TODO")
	end,

	http = function(self, packet)
		-- XXXX
		log:warn("TODO")
	end,
}


-- Create a slimproto connection object, to connect to SqueezeCenter at
-- address. The heloPacket is sent on server (re)connection.
function __init(self, jnt, serverip, heloPacket)
	-- validate the heloPacket
	assert(heloPacket.revision)

	local obj = oo.rawnew(self, {})

	-- connection state UNCONNECTED / CONNECTED
	obj.state          = UNCONNECTED
	obj.serverip       = serverip

	-- helo packet sent on connection
	obj.heloPacket     = heloPacket

	local uuid, mac = jnt:getUUID()
	obj.heloPacket.mac = string.lower(mac)
	obj.heloPacket.uuid = uuid

	obj.statusCallback = _defaultStatusCallback

	-- opcode subscriptions
	obj.subscriptions  = {}

	-- network state
	obj.jnt            = jnt
	obj.socket         = SocketTcp(jnt, serverip, PORT, "SlimProto")

	-- reconnect timer
	obj.reconnectTimer = Timer(0, function() _handleTimer(obj) end, true)

	return obj
end


-- Return the server ip address
function getServerIp(self)
	return self.serverip
end


-- Return this player's id 
function getId(self)
	return self.heloPacket.mac
end


-- Open the slimproto connection to SqueezeCenter.
function connect(self)
	local pump = function(NetworkThreadErr)
		if NetworkThreadErr then
			return _handleDisconnect(self, NetworkThreadErr)
		end

		local data, err = self.socket.t_sock:receive(2)
		if err then
			return _handleDisconnect(self, err)
		end

		local len = unpackNumber(data, 1, 2)
		local data, err = self.socket.t_sock:receive(len)
		if err then
			return _handleDisconnect(self, err)
		end

		-- decode opcode
		local opcode = string.sub(data, 1, 4)
		log:debug("read opcode=", opcode, " #", #data)

		--_hexDump(opcode, data)
		
		-- decode packet
		local packet
		local fn = opcodes[opcode]
		if fn then
			packet = fn(self, data)
		end

		if not packet then
			packet = {
				data = data
			}
		end

		packet.opcode = opcode
		packet.jiffies = Framework:getTicks()

		-- notify subscriptions
		local statusSent = false

		local subscriptions = self.subscriptions[opcode]
		if subscriptions then
			for i, subscription in ipairs(subscriptions) do
				if subscription(self, packet) then
					statusSent = true
				end
			end
		end

		-- send acknowledgement
		if not statusSent then
			self:sendStatus(opcode)
		end
	end

	-- connect
	self.socket:t_connect()
	self.socket:t_addRead(pump, 0) -- no timeout

	self.state = CONNECTED

	-- send helo packet
	self:send(self.heloPacket)
end


-- Disconnect from SqueezeCenter.
function disconnect(self)
	self.state = UNCONNECTED
	self.socket:close()
end


-- Set the callback to get a status packet
function statusPacketCallback(self, callback)
	self.statusCallback = callback
end


-- Subscribe subscription function to a slimproto opocde.
function subscribe(self, opcode, subscription)
	if not self.subscriptions[opcode] then
		self.subscriptions[opcode] = {}
	end

	table.insert(self.subscriptions[opcode], subscription)
end


-- Unsubscribe to a slimproto opocde. Returns true if the subscription
-- function was subscribe to opcode, otherwise returns false.
function unsubscribe(self, opcode, subscription)
	if not self.subscriptions[opcode] then
		return false
	end

	return table.delete(self.subscriptions[opcode], subscription)
end


-- Sent packet. Returns false is the connection is disconnected and the
-- packet can't be sent, otherwise it returns true.
function send(self, packet)
	if self.state == UNCONNECTED then
		return false
	end

	assert(packet.opcode)
	assert(opcodes[packet.opcode], "Unknown opcode")
	packet.jiffies = Framework:getTicks()

	log:debug("send opcode=", packet.opcode)

	-- encode packet
	local fn = opcodes[packet.opcode]
	local body = table.concat(fn(self, packet))

	local data = table.concat({
		packet.opcode,
		packNumber(#body, 4),
		body
	})

	--_hexDump("STAT", data)

	local pump = function(NetworkThreadErr)
		if (NetworkThreadErr) then
			return _handleDisconnect(NetworkThreadErr)
		end

		self.socket.t_sock:send(data)
		self.socket:t_removeWrite()
	end

	self.socket:t_addWrite(pump, WRITE_TIMEOUT)

	return true
end


-- Send a status packet for event.
function sendStatus(self, event, serverTimestamp)
	local packet = self.statusCallback(self, event, serverTimestamp)
	self:send(packet)
end


function _defaultStatusCallback(self, event, serverTimestamp)
	return {
		opcode = "STAT",
		event = event,
		decodeSize = 10000,
		decodeFull = 0,
		bytesReceived = 0,
		outputSize = 10000,
		outputFull = 0,
		elapsed = 0,
		serverTimestamp = serverTimestamp
	}
end


function _handleDisconnect(self, reason)
	local interval = math.random(1000, 5000)

	log:info("connection error: ", reason, ", reconnecting in ", (interval / 1000), " seconds")

	self:disconnect()
	self.reconnectTimer:restart(interval)
end


function _handleTimer(self)
	if self.state == CONNECTED then
		log:warn("bogus timer")
		return
	end

	self:connect()
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
