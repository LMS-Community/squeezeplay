
local pairs, ipairs, print, tonumber, unpack, tostring = pairs, ipairs, print, tonumber, unpack, tostring

local oo          = require("loop.base")

local socket      = require("socket")
local string      = require("string")
local table       = require("jive.utils.table")

local SocketUdp   = require("jive.net.SocketUdp")
local log         = require("jive.utils.log").logger("net.socket")

local System         = require("jive.System")
local JIVE_VERSION   = jive.JIVE_VERSION

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
	"discover",				-- 1
	"get_ip",				-- 2
	"set_ip",				-- 3
	"reset",				-- 4
	"get_data",				-- 5
	"set_data",				-- 6
	"error",				-- 7
	"credentials_error",	-- 8
	"adv_discover",			-- 9
	nil,					-- 10
	"get_uuid",				-- 11
	"set_volume",			-- 12
	"pause",				-- 13
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

local function _ucpString(v)
	return v
end

local function _ucpHex(v)
	local h = { '0x' }
	for i, n in ipairs({ string.byte(v, 1, -1) }) do
		h[#h + 1] = string.format('%02x', n)
	end

	return #v .. " " .. table.concat(h)
end

local ucpStrings = {
	name = _ucpString,
	type = _ucpString,
	use_dhcp = _ucpHex,
	ip_addr = _ucpHex,
	subnet_mask = _ucpHex,
	gateway_addr = _ucpHex,
	firmware_rev = _ucpString,
	hardware_rev = _ucpString,
	device_id = _ucpString,
	device_status = _ucpString,
	uuid = _ucpString,
}

function __init(self, jnt, sink)
	if _instance then
		if sink then
			_instance:addSink(sink)
		end
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
			       end,
			       "",
			       PORT)

	if sink then
		obj:addSink(sink)
	end

	_instance = obj

	return obj
end


function addSink(self, sink)
	table.insert(self.sinks, sink)
	return sink
end


function removeSink(self, sink)
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


function parseSetData(pkt, recv, offset)
	local num, off, len, data

	pkt.data = {}

	local username = ""
	local password = ""

	username, offset = unpackString(recv, offset, 16)
	password, offset = unpackString(recv, offset, 16)

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

function parseSetVolume(pkt, recv, offset)
	pkt.data = {}

	pkt.data.volume, offset = unpackNumber(recv, offset, 1)
	pkt.data.seq, offset = unpackNumber(recv, offset, 4)
end

-- Handlers for udap responses we receive upon requests we've sent
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

-- Handlers for udap requests we receive from other devices and need to send an response
local ucpMethodHandlersRequest = {
	[ "discover" ] = parseDiscover,
	[ "get_ip" ] = parseDiscover,
	[ "set_ip" ] = nil,
	[ "reset" ] = nil,
	[ "get_data" ] = nil,
	[ "set_data" ] = parseSetData,
	[ "error" ] = nil,
	[ "credentials_error" ] = nil,
	[ "adv_discover" ] = parseDiscover,
	[ "get_uuid" ] = nil,
	[ "set_volume" ] = parseSetVolume,
	[ "pause" ] = nil,
}


function parseUdap(recv)
	local offset = 1
	local pkt = {}

	pkt.destType, offset = unpackNumber(recv, offset, 2)
	-- Check destination type, but don't care about the broadcast flag
	if pkt.destType & 0x00FF == 0x0001 then
		-- mac address
		pkt.dest, offset = unpackString(recv, offset, 6)
	elseif pkt.destType & 0x00FF == 0x0002 then
		-- ip address
		pkt.dest, offset = unpackString(recv, offset, 6)
	elseif pkt.destType & 0x00FF == 0x0000 then
		-- raw
		pkt.dest, offset = unpackString(recv, offset, 6)
	else
		log:error("uknown address type " .. pkt.destType)
	end

	pkt.sourceType, offset = unpackNumber(recv, offset, 2)
	if pkt.sourceType == 0x0001 then
		-- mac address
		pkt.source, offset = unpackString(recv, offset, 6)
	elseif pkt.sourceType == 0x0002 then
		-- ip address
		pkt.source, offset = unpackString(recv, offset, 6)
	else
		log:error("uknown address type " .. pkt.sourceType)
	end

	pkt.seqno, offset = unpackNumber(recv, offset, 2)
	pkt.udapType, offset = unpackNumber(recv, offset, 2)
	pkt.udapFlag, offset = unpackNumber(recv, offset, 1)
	pkt.uapClass, offset = unpackString(recv, offset, 4)
	pkt.uapMethodId, offset = unpackNumber(recv, offset, 2)
	
	pkt.uapMethod = ucpMethods[pkt.uapMethodId]

	-- Handle udap responses we receive upon requests we've sent
	if pkt.udapFlag == 0x00 then
		if ucpMethodHandlers[pkt.uapMethod] then
			ucpMethodHandlers[pkt.uapMethod](pkt, recv, offset)
		end

	-- Handle udap requests from other devices sent to us and we need to provide an response
	elseif pkt.udapFlag == 0x01 then
		if ucpMethodHandlersRequest[pkt.uapMethod] then
			ucpMethodHandlersRequest[pkt.uapMethod](pkt, recv, offset)
		end
	end

	return pkt
end


function createUdap(destmac, seq, ...)
	local destmacstr = {}
	local bcast = 0

	if destmac == nil then
		bcast = 1
		destmac = "000000000000"
	end

	destmac = string.gsub(destmac, "[^%x]", "")

	for i=1,12,2 do
		destmacstr[#destmacstr + 1] = string.char(tonumber(string.sub(destmac, i, i+1), 16))
	end

	local srcmacstr = {}
	local srcmac = System:getMacAddress()

	srcmac = string.gsub(srcmac, "[^%x]", "")

	for i=1,12,2 do
		srcmacstr[#srcmacstr + 1] = string.char(tonumber(string.sub(srcmac, i, i+1), 16))
	end

	return table.concat {
		packNumber(bcast, 1),         -- destination broadcast
		packNumber(0x01, 1),          -- destination type ethernet
		table.concat(destmacstr),     -- destination mac
		packNumber(0x0001, 2),        -- source type ethernet
		table.concat(srcmacstr),      -- source mac
		packNumber(seq, 2),           -- seqno number
		packNumber(0xC001, 2),        -- udap_type_ucp
		packNumber(0x01, 1),          -- flags (1 for request)
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
			t[#t + 1] = k .. ":\t" .. ucpStrings[k](v)
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
	if pkt.uuid then
		t[#t + 1] = "uuid:\t\t" .. pkt.uuid
	end

	return table.concat(t, "\n")
end



-- Client methods Udap response
function createUdapResponse(srcmac, destmac, seq, ...)
	local srcmacstr = {}
	local destmacstr = {}

	for i=1,12,2 do
		srcmacstr[#srcmacstr + 1] = string.char(tonumber(string.sub(srcmac, i, i+1), 16))
	end

	for i=1,12,2 do
		destmacstr[#destmacstr + 1] = string.char(tonumber(string.sub(destmac, i, i+1), 16))
	end

	return table.concat {
		packNumber(0x0002, 2),        -- destination type ethernet
		table.concat(destmacstr),     -- destination mac
		packNumber(0x0001, 2),        -- source type ethernet
		table.concat(srcmacstr),      -- source mac
		packNumber(seq, 2),           -- seqno number
		packNumber(0xC001, 2),        -- udap_type_ucp
		packNumber(0x00, 1),          -- flags (0 for response)
		packNumber(0x00001, 2),       -- uap_class_ucp
		packNumber(0x00001, 2),
		table.concat({...})
	}
end

function createGetIpResponse(srcmac, destmac, seq, ip)
	return createUdapResponse(srcmac,
				  destmac,
				  seq,
				  packNumber(0x0002, 2),		-- get_ip
				  packNumber(0x05, 1),			-- ip_addr
				  packNumber(#ip, 1),			-- ip_addr len
				  ip
	)
end

function createDiscoverResponse(srcmac, destmac, seq, devName, devType)
	return createUdapResponse(srcmac,
				  destmac,
				  seq,
				  packNumber(0x0001, 2),		-- discover
				  packNumber(0x03, 1),			-- device type
				  packNumber(#devType, 1),		-- device type len
				  devType,
				  packNumber(0x02, 1),			-- device name
				  packNumber(#devName, 1),		-- device name len
				  devName
	)
end

function createAdvancedDiscoverResponse(srcmac, destmac, seq, devName, devType, devId, devStatus)

	local machine, revision = System:getMachine()
	local hwRev = tostring(revision)

	return createUdapResponse(srcmac,
				  destmac,
				  seq,
				  packNumber(0x0009, 2),		-- adv discover
				  packNumber(0x0C, 1),			-- device status
				  packNumber(#devStatus, 1),		-- device status len
				  devStatus,
				  packNumber(0x0B, 1),			-- device id
				  packNumber(#devId, 1),		-- device id len
				  devId,
				  packNumber(0x0A, 1),			-- hardware rev
				  packNumber(#hwRev, 1),		-- hardware rev len
				  hwRev,
				  packNumber(0x09, 1),			-- firmware rev
				  packNumber(#JIVE_VERSION, 1),		-- firmware rev len
				  JIVE_VERSION,
				  packNumber(0x03, 1),			-- device type
				  packNumber(#devType, 1),		-- device type len
				  devType,
				  packNumber(0x02, 1),			-- device name
				  packNumber(#devName, 1),		-- device name len
				  devName
	)
end

function createSetDataResponse(srcmac, destmac, seq)
	return createUdapResponse(srcmac,
				  destmac,
				  seq,
				  packNumber(0x0006, 2)			-- set data
	)
end

function createGetUUIDResponse(srcmac, destmac, seq)
	local uuidstr = {}
	local uuid = System:getUUID()

	for i=1,32,2 do
		uuidstr[#uuidstr + 1] = string.char(tonumber(string.sub(uuid, i, i+1), 16))
	end

	return createUdapResponse(srcmac,
				  destmac,
				  seq,
				  packNumber(0x000B, 2),		-- get uuid
				  packNumber(0x0D, 1),			-- uuid
				  packNumber(#uuidstr, 1),		-- uuid len
				  table.concat(uuidstr)
	)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
