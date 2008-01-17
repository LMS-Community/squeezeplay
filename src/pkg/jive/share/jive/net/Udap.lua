
local pairs, ipairs, print, tonumber, unpack = pairs, ipairs, print, tonumber, unpack

local oo          = require("loop.base")

local socket      = require("socket")
local string      = require("string")
local table       = require("jive.utils.table")

local SocketUdp   = require("jive.net.SocketUdp")
local log         = require("jive.utils.log").logger("net.socket")


module(..., oo.class)


local PORT = 0x4578


-- singleton wireless instance per interface
local _instance = nil


-- Squeezebox nvram settings
local configSettings = {
	[ "lan_ip_mode" ] = { 4, 1 },
	[ "lan_network_address" ] = { 5, 4 },
	[ "lan_subnet_mask" ] = { 9, 4 },
	[ "lan_gateway" ] = { 13, 4 },
	[ "hostname" ] = { 17, 33 },
	[ "bridging" ] = { 50, 1 },
	[ "interface" ] = { 52, 1 },
	[ "primary_dns" ] = { 59, 4 },
	[ "secondary_dns" ] = { 67, 4 },
	[ "server_address" ] = { 71, 4 },
	[ "slimserver_address" ] = { 79, 4 },
	[ "wireless_mode" ] = { 173, 1 },
	[ "SSID" ] = { 183, 33 },
	[ "channel" ] = { 216, 1 },
	[ "region_id" ] = { 218, 1 },
	[ "keylen" ] = { 220, 1 },
	[ "wep_key" ] = { 222, 13 },
	[ "wepon" ] = { 274, 1 },
	[ "wpa_cipher" ] = { 275, 1 },
	[ "wpa_enabled" ] = { 277, 1 },
	[ "wpa_mode" ] = { 276, 1 },
	[ "wpa_psk" ] = { 278, 64 }
}


-- ucp methods
local ucpMethods = {
	"discover",
	"get_ip",
	"set_ip",
	"reset",
	"get_data",
	"set_data",
	"error",
	"credentials_error",
	"adv_discover",
	nil,
	"get_uuid"
}


-- ucp discovery codes
local ucpCodes = {
	nil,
	"name",
	"type",
	"use_dhcp",
	"ip_addr",
	"subnet_mask",
	"gateway_addr",
	nil,
	"firmware_rev",
	"hardware_rev",
	"device_id",
	"device_status",
	"uuid"
}


function __init(self, jnt)
	if _instance then
		return _instance
	end

	local obj = oo.rawnew(self, {})
	obj.sinks = {}

	obj.socket = SocketUdp(jnt,
			       function(chunk, err)
				       -- forward to all sinks
				       for i, sink in ipairs(obj.sinks) do
					       sink(chunk, err)
				       end
				       return 1
			       end)

	return obj
end


function addSink(self, sink)
	log:warn("ADD SINK ", sink)
	table.insert(self.sinks, sink)
	return sink
end


function removeSink(self, sink)
	log:warn("REMOVE SINK ", sink)
	table.delete(self.sinks, sink)
end


function send(self, pkt, addr, port)
	self.socket:send(pkt, addr, port or PORT)
end


function packNumber(v, len)
	local t = {}

	for i = 1,len do
		t[#t + 1] = string.char(v & 0xFF)
		v = v >> 8
	end

	return string.reverse(table.concat(t))
end


function unpackString(str, pos, len)
	local v = ""
	for i = pos, pos+len-1 do
		v = string.format("%s%02x", v, string.byte(string.sub(str, i, i+1)))
	end

	return v, pos + len
end


function unpackNumber(str, pos, len)
	local v, offset = unpackString(str, pos, len)
	return tonumber(v, 16), offset
end


function parseDiscover(pkt, recv, offset)
	pkt.ucp = {}
	while offset < #recv do
		local ucp_code, ucp_len, ucp_pkt
		
		ucp_code, offset = unpackNumber(recv, offset, 1)
		ucp_len, offset = unpackNumber(recv, offset, 1)
		ucp_data = string.sub(recv, offset, offset + ucp_len - 1)
		offset = offset + ucp_len

		pkt.ucp[ucpCodes[ucp_code]] = ucp_data
	end
end


function parseGetData(pkt, recv, offset)
	local num, off, len, data

	pkt.data = {}

	num, offset = unpackNumber(recv, offset, 2)
	for i = 1,num do
		off, offset = unpackNumber(recv, offset, 2)
		len, offset = unpackNumber(recv, offset, 2)
		data = string.sub(recv, offset, offset + len - 1)
		offset = offset + len

		for k,v in pairs(configSettings) do
			if v[1] == off and v[2] == len then
				pkt.data[k] = data
				break
			end
		end
	end
end


function parseGetUUID(pkt, recv, offset)
	local num, off, len, data

	pkt.data = {}

	len, offset = unpackNumber(recv, offset, 2)
	local n = { string.byte(string.sub(recv, offset, offset + len - 1), 1, len) }

	pkt.uuid = {}
	for k,v in ipairs(n) do
		pkt.uuid[#pkt.uuid + 1] = string.format("%02x", v)
	end
	pkt.uuid = table.concat(pkt.uuid)
end


local ucpMethodHandlers = {
	[ "discover" ] = parseDiscover,
	[ "get_ip" ] = parseDiscover,
	[ "set_ip" ] = nil,
	[ "reset" ] = nil,
	[ "get_data" ] = parseGetData,
	[ "set_data" ] = nil,
	[ "error" ] = nil,
	[ "credentials_error" ] = nil,
	[ "adv_discover" ] = parseDiscover,
	[ "get_uuid" ] = parseGetUUID,
}


function parseUdap(recv)
	local offset = 1
	local pkt = {}

	pkt.destType, offset = unpackNumber(recv, offset, 2)
	if pkt.destType == 1 then
		-- mac address
		pkt.dest, offset = unpackString(recv, offset, 6)
	elseif pkt.destType == 2 then
		-- ip address
		pkt.dest, offset = unpackString(recv, offset, 6)
	else
		error("uknown address type " .. pkt.destType)
	end

	pkt.sourceType, offset = unpackNumber(recv, offset, 2)
	if pkt.sourceType == 1 then
		-- mac address
		pkt.source, offset = unpackString(recv, offset, 6)
	elseif pkt.sourceType == 2 then
		-- ip address
		pkt.source, offset = unpackString(recv, offset, 6)
	else
		error("uknown address type " .. pkt.sourceType)
	end

	pkt.seqno, offset = unpackNumber(recv, offset, 2)
	pkt.udapType, offset = unpackNumber(recv, offset, 2)
	pkt.udapFlag, offset = unpackNumber(recv, offset, 1)
	pkt.uapClass, offset = unpackString(recv, offset, 4)
	pkt.uapMethodId, offset = unpackNumber(recv, offset, 2)
	
	pkt.uapMethod = ucpMethods[pkt.uapMethodId]
	
	if ucpMethodHandlers[pkt.uapMethod] then
		ucpMethodHandlers[pkt.uapMethod](pkt, recv, offset)
	end

	return pkt
end


function createUdap(mac, seq, ...)
	local macstr = {}
	local bcast = 0

	if mac == nil then
		bcast = 1
		mac = "000000000000"
	end

	for i=1,12,2 do
		macstr[#macstr + 1] = string.char(tonumber(string.sub(mac, i, i+1), 16))
	end

	return table.concat {
		packNumber(bcast, 1),         -- broadcast
		packNumber(0x01, 1),          -- ethernet
		table.concat(macstr),         -- destination mac
		packNumber(0x0002, 2),        -- source type udp
		packNumber(0x00000000, 4),    -- source ip
		packNumber(0x0000, 2),        -- source port
		packNumber(seq, 2),           -- seqno number
		packNumber(0xC001, 2),        -- udap_type_ucp
		packNumber(0x01, 1),          -- flags
		packNumber(0x00001, 2),       -- uap_class_ucp
		packNumber(0x00001, 2),
		table.concat({...})
	}
end


function createDiscover(mac, seq)
	return createUdap(mac,
			  seq,
			  packNumber(0x0001, 2) -- discover
		   )
end


function createAdvancedDiscover(mac, seq)
	return createUdap(mac,
			  seq,
			  packNumber(0x0009, 2) -- discover
		   )
end


function createReset(mac, seq)
	return createUdap(mac,
			  seq,
			  packNumber(0x0004, 2) -- reset
		   )
end


function createGetIPAddr(mac, seq)
	return createUdap(mac,
			  seq,
			  packNumber(0x0002, 2) -- get ip
		   )
end


function createGetUUID(mac, seq)
	return createUdap(mac,
			  seq,
			  packNumber(0x000b, 2) -- get uuid
		   )
end


function createGetData(mac, seq, args)
	local req = {
		packNumber(0x0005, 2),    -- get data
		string.rep("\0", 16),      -- username
		string.rep("\0", 16),      -- password
		packNumber(#args, 2),     -- num of items
	}
	
	for i,k in ipairs(args) do
		local p = configSettings[k]
		if p ~= nil then
			req[ #req + 1 ] = packNumber(p[1], 2)  -- offset
			req[ #req + 1 ] = packNumber(p[2], 2)  -- length
		end
	end

	return createUdap(mac,
			  seq,
			  unpack(req))
end


function createSetData(mac, seq, args)
	local num = 0
	for k,v in pairs(args) do
		num = num + 1
	end

	local req = {
		packNumber(0x0006, 2),    -- set data
		string.rep("\0", 16),      -- username
		string.rep("\0", 16),      -- password
		packNumber(num, 2),       -- num of items
	}
	
	for k,v in pairs(args) do
		local p = configSettings[k]
		if p ~= nil then
			req[ #req + 1 ] = packNumber(p[1], 2)  -- offset
			req[ #req + 1 ] = packNumber(p[2], 2)  -- length
			req[ #req + 1 ] = v .. string.rep("\0", p[2] - #v)
		end
	end

	return createUdap(mac,
			  seq,
			  unpack(req))
end


function tostringUdap(pkt)
	local t = {
		"source:\t\t" .. pkt.source,
		"dest:\t\t" .. pkt.dest,
		"seq:\t\t" .. pkt.seqno,
		"udap type:\t" .. string.format("%04x", pkt.udapType),
		"udap flag:\t" .. string.format("%02x", pkt.udapFlag),
		"uap class:\t" .. pkt.uapClass,
		"uap method:\t" .. pkt.uapMethod,
	}
	if pkt.ucp then
		for k,v in pairs(pkt.ucp) do
			t[#t + 1] = k .. ":\t" .. v
		end
	end
	if pkt.data then
		for k,v in pairs(pkt.data) do
			local hex = ""
			for i = 1,#v do
				hex = hex .. string.format("%02x", string.byte(string.sub(v, i, i)))
			end

			t[#t + 1] = k .. " (#" .. #v .. "):\t" .. hex
		end
	end

	return table.concat(t, "\n")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
