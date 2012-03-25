
--[[
=head1 NAME

jive.net.SlimProto - A TCP socket that implements the slimproto.

=head1 DESCRIPTION

This class implements a TCP socket running in a L<jive.net.NetworkThread>.

=head1 SYNOPSIS



=head1 FUNCTIONS

=cut
--]]

local assert, ipairs, tonumber, type = assert, ipairs, tonumber, type


local oo          = require("loop.base")

local math        = require("math")
local string      = require("string")
local table       = require("jive.utils.table")
local os          = require("os")

local Framework   = require("jive.ui.Framework")
local Task        = require("jive.ui.Task")
local Timer       = require("jive.ui.Timer")

local locale      = require("jive.utils.locale")

local DNS         = require("jive.net.DNS")
local SocketTcp   = require("jive.net.SocketTcp")
local System      = require("jive.System")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.slimproto")


module(..., oo.class)


local PORT = 3483

local DEVICEID = 7 -- XXXX using recevier device id

local READ_TIMEOUT = 35
local WRITE_TIMEOUT = 10

-- connection state
local UNCONNECTED    = "UNCONNECTED"    -- not connected
local CONNECTED      = "CONNECTED"      -- connected
local CONNECTING     = "CONNECTING"     -- connecting


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
		v = (v << 8) + (string.byte(str, i) or 0)
	end
	return v
end


function _ipstring(ip)
	local str = {}
	for i = 4,1,-1 do
		str[i] = string.format("%d", ip & 0xFF)
		ip = ip >> 8
	end
	str = table.concat(str, ".")
	return str
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

		local wlanList = 0
		if data.reconnect then
		   	-- reconnection bit
			wlanList = wlanList | 0x4000
		end

		local capabilities = {}
		for i, key in ipairs(self.capabilities) do
			if type(key) == 'function' then
				local v
				key, v = key()
				if key and v then
					key = key .. '=' .. v
				end
			end
			if key then
				table.insert(capabilities, key)
			end
		end

		capabilities = table.concat(capabilities, ",")

		-- always clear the syncgroupid after using it
		for i, key in ipairs(self.capabilities) do
			if type(key) == 'string' and string.match(key, "SyncgroupID=") then
				table.remove(self.capabilities, i)
				break
			end
		end
		
		log:info("Send HELO: reconnect-bit=", data.reconnect or 0, " bytesReceived(H,L)=", data.bytesReceivedH, ",", data.bytesReceivedL)

		return {
			packNumber(data.deviceID or DEVICEID, 1),
			packNumber(0, 1),
			table.concat(macp),
			table.concat(uuidp),
			packNumber(wlanList, 2),
			packNumber(data.bytesReceivedH or 0, 4),
			packNumber(data.bytesReceivedL or 0, 4),
			string.upper(locale.getLocale()),
			capabilities			
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
			packNumber(data.signalStrength or 0xffff, 2),
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

	BODY = function(self, data)
		-- XXXX
		log:error("TODO")
	end,

	DSCO = function(self, data)
		assert(data.reason)
		
		return {
			packNumber(data.reason, 1),
		}
	end,

	aude = function(self, packet)
		return {
			enable = unpackNumber(packet, 5, 1),
		}
	end,

	audg = function(self, packet)
		local gainL, gainR, fixedDigital, preampAtten, sequenceNumber, controller

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
		if #packet > 22 then
			sequenceNumber = unpackNumber(packet, 23, 4)
		end
		if #packet > 28 then
			controller = unpackNumber(packet, 27, 6)
		end

		return {
			gainL = gainL,
			gainR = gainR,
			fixedDigital = fixedDigital,
			preampAtten = preampAtten,
			sequenceNumber = sequenceNumber,
			controller = controller,
		}
	end,

	setd = function(self, packet)
		return {
			command = unpackNumber(packet, 5, 1),
			packet  = packet
		}
	end,

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
			slaves = unpackNumber(packet, 18, 1),
			replayGain = unpackNumber(packet, 19, 4),
			serverPort = unpackNumber(packet, 23, 2),
			serverIp = unpackNumber(packet, 25, 4),
			header = string.sub(packet, 29)
		}
	end,

	cont = function(self, packet)
		return {
			icyMetaInterval = unpackNumber(packet, 5, 4),
			loop = unpackNumber(packet, 9, 1),
			guid_len = unpackNumber(packet, 10, 2),
			guid = string.sub(packet, 12)
		}
	end,

	dsco = function(self, packet)
		return { }
	end,

	serv = function(self, packet)
		return {
			serverip = unpackNumber(packet, 5, 4),
			syncgroupid = string.sub(packet, 9, 19),
		}
	end,

	geek = function(self, packet)
		return {
			geekmode = unpackNumber(packet, 5, 1),
		}
	end,

	blst = function(self, packet)
		return {
			irstr = string.sub( packet, 5),
	}
	end,

	http = function(self, packet)
		-- XXXX
		log:error("TODO")
	end,

	body = function(self, packet)
		-- XXXX
		log:error("TODO")
	end,
}


-- Create a slimproto connection object, to connect to SqueezeCenter at
-- address. The heloPacket is sent on server (re)connection.
function __init(self, jnt, heloPacket)
	-- validate the heloPacket
	assert(heloPacket.version)
	assert(heloPacket.mac)
	assert(heloPacket.uuid)
	assert(heloPacket.model)
	assert(heloPacket.modelName)

	local obj = oo.rawnew(self, {})

	-- connection state UNCONNECTED / CONNECTED
	obj.state            = UNCONNECTED
	obj.connectionFailed = false
	obj.capabilities     = {}
	obj.txqueue          = {}

	-- helo packet sent on connection
	obj.heloPacket     = heloPacket
	obj.heloPacket.mac = string.lower(obj.heloPacket.mac)

	obj:capability("Model", obj.heloPacket.model)
	obj:capability("ModelName", obj.heloPacket.modelName)
	obj:capability("Firmware", string.gsub(obj.heloPacket.version, '%s', '-'))
	if System:hasDigitalOut() then
		obj:capability("HasDigitalOut", 1)
	end

	obj.statusCallback = _defaultStatusCallback

	-- opcode subscriptions
	obj.subscriptions  = {}

	-- network state
	obj.jnt            = jnt
	jnt:subscribe(obj)

	-- reconnect timer
	obj.reconnectTimer = Timer(0, function() _handleTimer(obj) end, true)

	-- subscriptions
	obj:subscribe("dsco", function(_, data)
		log:info("server told us to disconnect")
		obj:disconnect()
	end)

	obj:subscribe("serv", function(_, data)
		log:info("slimproto serv command - syncgroupid=", data.syncgroupid)

		-- set syncgroupid
		obj:capability("SyncgroupID", data.syncgroupid)

		connectIp(obj, data.serverip)
	end)

	obj:subscribe("geek", function(_, data)
		local geekmode = data.geekmode
		log:info( "IR Blaster - geekmode: ", geekmode)

		_setGeekmode( obj, geekmode)
	end)

	obj:subscribe("blst", function(_, data)
		local irstr = data.irstr
		log:info( "IR Blaster - irstr: ", irstr)

		_blastIR( obj, irstr)
	end)

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


-- Open the slimproto connetion to Ip.
-- Called by slimproto 'serv' and udap
function connectIp(self, serverip, slimserverip)
	-- A bug in ip3k firmware forces Jive to sometimes set slimserverip
	--  to 0.0.0.1 to work around that bug.
	-- Do not store this bogus slimserver ip address.
	if slimserverip and slimserverip ~= 0 and slimserverip ~= 1 then
		self.lastServerip = _ipstring(slimserverip)
	end

	if serverip == 0 then
		if not self.lastServerip then
			log:warn("no last SC ip address stored - ignore connection request")
			return
		end
		serverip = self.lastServerip
	elseif serverip == 1 then
		serverip = self.jnt:getSNHostname()
	elseif serverip == 2 then
		serverip = "www.test.squeezenetwork.com"
	else
		serverip = _ipstring(serverip)
	end

	log:info("server told us to connect to ", serverip)

	self.connectionFailed = false
	_connectToAddr(self, serverip)
end


-- Open the slimproto connection to SqueezeCenter.
function connect(self, server)
	local serverip = self.serverip
	if server then
		-- the server may have moved, get a fresh ip address
		serverip = server:getIpPort()
		
		-- remember last SqueezeCenter for 'serv 0'
		if not server:isSqueezeNetwork() then
			self.lastServerip = serverip
		end
	end

	self.connectionFailed = false
	_connectToAddr(self, serverip)
end


function _connectToAddr(self, serverip)
	Task("slimprotoConnect", self, connectTask):addTask(serverip)
end


function connectTask(self, serverip)
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

		-- discard network test packets without processing
		-- we need to minimse processing as they can arrive at a high rate
		if opcode == 'test' then
			return
		end

		-- We got a packet so we must be connected
		self.state = CONNECTED
		
		if self.connectionFailed then
			local subscriptions = self.subscriptions["reconnect"]
			if subscriptions then
				for i, subscription in ipairs(subscriptions) do
					subscription(self, nil)
				end
			end
		end
		
		self.connectionFailed = false

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

		-- any future connections to this server are reconnects
		self.reconnect = true
	end

	self.writePump = function(NetworkThreadErr)
		if (NetworkThreadErr) then
			return _handleDisconnect(self, NetworkThreadErr)
		end

		self.socket.t_sock:send(table.concat(self.txqueue))
		self.socket:t_removeWrite()

		self.txqueue = {}
	end

	-- disconnect from previous server
	self:disconnect()

	-- update connection state
	self.state = CONNECTING

	if serverip and serverip ~= self.serverip then
		self.reconnect = false
		self.serverip = serverip
	end

	local ip = self.serverip
	if not DNS:isip(ip) then
		ip = DNS:toip(ip)

		if not ip then
			log:warn("dns lookup failed for ", self.serverip)
			_handleDisconnect(self, "DNS lookup")
			return
		end
	end

	log:info("connect to ", self.serverip, " (", ip, ")")

	self.socket = SocketTcp(self.jnt, ip, PORT, "SlimProto")

	-- connect
	self.socket:t_connect()
	self.txqueue = {}

	-- SC and SN ping the player every 5 and 30 seconds respectively.
	-- This timeout could be made shorter in the SC case.
	self.socket:t_addRead(pump, READ_TIMEOUT)

	-- the reconnect bit means that we have a running data connection
	-- for this server or we're looping
	local status = self.statusCallback(self, event, serverTimestamp)
	self.heloPacket.reconnect =
		self.reconnect and
		(status.isStreaming or status.isLooping)
	
	self.heloPacket.bytesReceivedH = status.bytesReceivedH;
	self.heloPacket.bytesReceivedL = status.bytesReceivedL;

	-- send helo packet
	self:send(self.heloPacket, true)
end


function _setGeekmode( self, geekmode)
	Task( "setGeekmode", self, setGeekmodeTask):addTask( geekmode)
end


function setGeekmodeTask( self, geekmode)
	if geekmode == 1 then
		os.execute( "echo 0 > /sys/devices/platform/fab4_gpio.0/HDP_EN0")
		os.execute( "echo 0 > /sys/devices/platform/fab4_gpio.0/HDP_EN1")
	else
		os.execute( "echo 1 > /sys/devices/platform/fab4_gpio.0/HDP_EN0")
		os.execute( "echo 1 > /sys/devices/platform/fab4_gpio.0/HDP_EN1")
	end
end


function _blastIR( self, irstr)
	Task( "blastIR", self, blastIRTask):addTask( irstr)
end


function blastIRTask( self, irstr)
	local cmd = "cd /sys/bus/i2c/drivers/fab4-ir/0-0047; "
	cmd = cmd .. "echo \"" .. irstr .. "\" > ir_blaster; "
	cmd = cmd .. "echo 1 > ir_blaster; "
	os.execute( cmd)
end


-- Disconnect from SqueezeCenter.
function disconnect(self)
	log:debug("disconnect")

	self.state = UNCONNECTED

	if self.socket then
		self.socket:close()
		self.socket = nil
	end
end


-- Return true if slimproto is connected
function isConnected(self)
	 return self.state == CONNECTED
end

-- Has the connection attempt actually failed
function hasConnectionFailed(self)
	return self.connectionFailed
end

-- Set the callback to get a status packet
function statusPacketCallback(self, callback)
	self.statusCallback = callback
end


-- Register capability
function capability(self, key, value)
	if value then
		key = key .. "=" .. value
	end
	table.insert(self.capabilities, key)
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
function send(self, packet, force)
	if not force and self.state ~= CONNECTED then
		return false
	end

	assert(packet.opcode)
	packet.jiffies = Framework:getTicks()

	log:debug("send opcode=", packet.opcode)

	-- encode packet
	local fn = opcodes[packet.opcode]
	local body
	if fn then
		body = table.concat(fn(self, packet))
	else
		body = packet.data
	end

	local data = table.concat({
		packet.opcode,
		packNumber(#body, 4),
		body
	})

	--_hexDump(packet.opcode, data)

	table.insert(self.txqueue, data)

	self.socket:t_addWrite(self.writePump, WRITE_TIMEOUT)

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

	self.state = CONNECTING
	self.connectionFailed = true
	self.reconnectTimer:restart(interval)
end


function _handleTimer(self)
	if self.state == CONNECTED then
		log:error("bogus timer")
		return
	end

	self:_connectToAddr(self.serverip)
end


function notify_networkConnected(self)
	if self.state ~= UNCONNECTED then
		-- force reconnect
		self:disconnect()
		self:connect()
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
