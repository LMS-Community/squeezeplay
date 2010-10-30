--[[
Methods to respond to the following udap requests:
 - discover
 - advanced discover
 - set server address
 - set slimserver address
 - get uuid
--]]

local pairs, tonumber, tostring = pairs, tonumber, tostring

-- stuff we use
local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local System        = require("jive.System")

local Framework     = require("jive.ui.Framework")
local Timer         = require("jive.ui.Timer")

local SocketUdp     = require("jive.net.SocketUdp")
local Udap          = require("jive.net.Udap")

local debug         = require("jive.utils.debug")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


-- udap packet received
function _udapSink( self, chunk, err)

	if chunk == nil then
		return -- ignore errors
	end

	local pkt = Udap.parseUdap( chunk.data)

	if pkt.uapMethod == nil then
		return
	end

--	log:debug("*** UDAP: pkt.dest: ", pkt.dest)
--	log:debug("*** UDAP: pkt.source: ", pkt.source)

--	log:debug("*** UDAP: seqno: ", pkt.seqno)
--	log:debug("*** UDAP: chunk.data length: ", #chunk.data)
--	log:debug("*** UDAP: chunk.ip: ", chunk.ip)
--	log:debug("*** UDAP: chunk.port: ", chunk.port)

--	log:debug("*** UDAP: uapMethod: ", pkt.uapMethod)
--	log:debug("*** UDAP: udapFlag: ", pkt.udapFlag)

	-- We are not interested in udap responses here - only requests from other devices
	if pkt.udapFlag ~= 0x01 then
		log:debug("UDAP: not a request - discard packet")
		return
	end

	local ownMacAddress = System:getMacAddress()
	ownMacAddress = string.gsub(ownMacAddress, "[^%x]", "")

	-- Discard packets from ourself
	if ownMacAddress == pkt.source then
		log:debug("UDAP: self origined packet - discard packet")
		return
	end

	local acceptPacket = false

	-- Only accept discover queries (length 27)
	if pkt.uapMethod == "discover" and #chunk.data == 27 then
		acceptPacket = true

	-- Only accept advanced discover queries (length 27)
	elseif pkt.uapMethod == "adv_discover" and #chunk.data == 27 then
		acceptPacket = true

	-- Only accept set data packets with our mac address as target
	elseif pkt.uapMethod == "set_data" and pkt.dest == ownMacAddress then
		if pkt.data["server_address"] then
			acceptPacket = true
		elseif pkt.data["slimserver_address"] then
			acceptPacket = true
		end

	-- Only accept get uuid packets with our mac address as target
	elseif pkt.uapMethod == "get_uuid" and pkt.dest == ownMacAddress then
		acceptPacket = true
	end

	-- Check for supported methods
	if not acceptPacket then
		log:debug("UDAP: not supported method - discard packet")
		return
	end

	local currentPlayer = appletManager:callService("getCurrentPlayer")

	-- Check if there is a current player
	if not currentPlayer then
		log:debug("UDAP: no current player - discard packet")
		return
	end

	log:debug("UDAP: curPlayer: ", currentPlayer, " local: ", currentPlayer:isLocal(), " connected: ", currentPlayer:isConnected())

	-- Check if current player is local
	if not currentPlayer:isLocal() then
		log:debug("UDAP: current player is not local - discard packet")
		return
	end

	-- Check if local player is connected
	if currentPlayer:isConnected() then
		log:debug("UDAP: current local player is connected - discard packet")
		return
	end

	local deviceName = currentPlayer:getName()
	local deviceModel = currentPlayer:getModel()

	if pkt.uapMethod == "discover" then

		log:debug("UDAP - discover request received - sending answer...")

		local packet = Udap.createDiscoverResponse(ownMacAddress, pkt.source, pkt.seqno, deviceName, deviceModel)
		self.udap:send(function() return packet end, "255.255.255.255", chunk.port)

	elseif pkt.uapMethod == "adv_discover" then

		log:debug("UDAP - advanced discover request received - sending answer...")

		local deviceId = currentPlayer:getDeviceType()
		deviceId = tostring(deviceId)

		local deviceStatus = "wait_slimserver"

		if currentPlayer:isConnected() then
			deviceStatus = "connected"
		end

		local packet = Udap.createAdvancedDiscoverResponse(ownMacAddress, pkt.source, pkt.seqno, deviceName,
								   deviceModel, deviceId, deviceStatus)
		self.udap:send(function() return packet end, "255.255.255.255", chunk.port)

	elseif pkt.uapMethod == "set_data" then

		log:debug("UDAP - set data request received - sending answer...")

		if pkt.data["server_address"] and pkt.data["slimserver_address"] then
			local serverip = pkt.data["server_address"]
			local a1, b1, c1, d1 = string.byte(serverip, 1, 4)

			serverip = (a1 << 24) + (b1 << 16) + (c1 << 8) + d1

			local slimserverip = pkt.data["slimserver_address"]
			local a2, b2, c2, d2 = string.byte(slimserverip, 1, 4)

			slimserverip = (a2 << 24) + (b2 << 16) + (c2 << 8) + d2
			currentPlayer:connectIp(serverip, slimserverip)

		elseif pkt.data["server_address"] then
			local serverip = pkt.data["server_address"]
			local a1, b1, c1, d1 = string.byte(serverip, 1, 4)

			serverip = (a1 << 24) + (b1 << 16) + (c1 << 8) + d1
			currentPlayer:connectIp(serverip)

		elseif pkt.data["slimserver_address"] then
			local slimserverip = pkt.data["slimserver_address"]
			local a2, b2, c2, d2 = string.byte(slimserverip, 1, 4)

			slimserverip = (a2 << 24) + (b2 << 16) + (c2 << 8) + d2

			currentPlayer:connectIp(0, slimserverip)
		end

		local packet = Udap.createSetDataResponse(ownMacAddress, pkt.source, pkt.seqno)
		self.udap:send(function() return packet end, "255.255.255.255", chunk.port)

	elseif pkt.uapMethod == "get_uuid" then

		log:debug("UDAP - get uuid request received - sending answer...")

		local packet = Udap.createGetUUIDResponse(ownMacAddress, pkt.source, pkt.seqno)
		self.udap:send(function() return packet end, "255.255.255.255", chunk.port)

	end
end


-- init
-- Initializes the applet
function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))

	-- udap socket
	obj.udap = Udap(jnt, 
		function(chunk, err)
			obj:_udapSink(chunk, err)
		end)

	return obj
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

