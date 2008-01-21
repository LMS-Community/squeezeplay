
local assert, ipairs, pairs, pcall, tonumber, tostring = assert, ipairs, pairs, pcall, tonumber, tostring

local oo          = require("loop.simple")

local io          = require("io")
local os          = require("os")
local string      = require("string")
local table       = require("jive.utils.table")
local ltn12       = require("ltn12")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.socket")

local Socket      = require("jive.net.Socket")
local Task        = require("jive.ui.Task")
local wireless    = require("jiveWireless")



module("jive.net.Wireless")
oo.class(_M, Socket)


-- wpa scan results signal level -> quality
-- FIXME tune with production boards
local WIRELESS_LEVEL = {
	0,
	175,
	180,
	190,
}

-- iwpriv snr -> quality
-- FIXME tune with production boards
local WIRELESS_SNR = {
	0,
	10,
	18,
	25,
}

-- FIXME check this region mapping is correct for Marvell and Atheros
local REGION_CODE_MAPPING = {
	-- name, marvell code, atheros code
	[ "US" ] = { 0x10, 4  }, -- ch 1-11
	[ "CA" ] = { 0x20, 6  }, -- ch 1-11
	[ "EU" ] = { 0x30, 14 }, -- ch 1-13
	[ "FR" ] = { 0x32, 13 }, -- ch 10-13
	[ "CH" ] = { 0x30, 23 }, -- ch 1-13
	[ "TW" ] = { 0x30, 21 }, -- ch 1-13
	[ "AU" ] = { 0x10, 7  }, -- ch 1-11
	[ "JP" ] = { 0x40, 16 }, -- ch 1-13
}


-- global wireless network scan results
local _scanResults = {}

-- singleton wireless instance per interface
local _instance = {}


function __init(self, jnt, interface, name)
	if _instance[interface] then
		return _instance[interface]
	end

	local obj = oo.rawnew(self, Socket(jnt, name))

	obj.interface = interface
	obj.responseQueue = {}

	obj.t_sock = wireless:open()
	obj:_addPump()

	_instance[interface] = obj
	return obj
end


-- returns available region names
function getRegionNames(self)
	return pairs(REGION_CODE_MAPPING)
end


-- returns the current region
function getRegion(self)
	-- check config file
	local fh = io.open("/etc/network/config")
	if fh then
		local file = fh:read("*a")
		fh:close()

		local region = string.match(file, "REGION=([^%s]+)")
		if  region then
			return region
		end
	end
	
	-- check marvell region
	local fh = assert(io.popen("/usr/sbin/iwpriv " .. self.interface .. " getregioncode"))
	local line = fh:read("*a")
	fh:close()

	local code = tonumber(string.match(line, "getregioncode:(%d+)"))

	for name,mapping in pairs(REGION_CODE_MAPPING) do
		log:info("code=", code, " mapping[1]=", mapping[1])
		if mapping[1] == code then
			log:info("returning=", name)
			return name
		end
	end
	return nil
end


-- sets the current region
function setRegion(self, region)
	local mapping = REGION_CODE_MAPPING[region]
	if not mapping then
		return
	end

	-- save config file
	local fh = assert(io.open("/etc/network/config", "w"))
	fh:write("REGION=" .. region .. "\n")
	fh:write("REGIONCODE=" .. mapping[1] .. "\n")
	fh:close()

	-- set new region
	local cmd = "/usr/sbin/iwpriv " .. self.interface .. " setregioncode " .. mapping[1]
	log:info("setRegion: ", cmd)
	os.execute(cmd)
end


-- returns the region code for Marvell on Jive
function getMarvellRegionCode(self)
	local mapping = REGION_CODE_MAPPING[region or self:getRegion()]
	return mapping and mapping[1] or 0
end


-- returns the region code for Atheros on Squeezebox
function getAtherosRegionCode(self)
	local mapping = REGION_CODE_MAPPING[region or self:getRegion()]
	return mapping and mapping[2] or 0
end


-- start a network scan in a new task
function scan(self, callback)
	Task("networkScan", self,
	     function()
		     t_scan(self, callback)
	     end):addTask()
end


-- returns scan results, or nil if a network scan has not been performed.
function scanResults(self)
	return _scanResults
end


-- network scanning. this can take a little time so we do this in 
-- the network thread so the ui is not bocked.
function t_scan(self, callback)
	assert(Task:running(), "Wireless:scan must be called in a Task")

	self:request("SCAN")

	local status = self:request("STATUS")
	local associated = string.match(status, "\nssid=([^\n]+)")

	local scanResults = self:request("SCAN_RESULTS")

	_scanResults = _scanResults or {}

	for bssid, level, flags, ssid in string.gmatch(scanResults, "([%x:]+)\t%d+\t(%d+)\t(%S*)\t([^\n]+)\n") do

		local quality = 1
		level = tonumber(level)
		for i, l in ipairs(WIRELESS_LEVEL) do
			if level < l then
				break
			end
			quality = i
		end

		_scanResults[ssid] = {
			bssid = bssid,
			flags = flags,
			level = level,
			quality = quality,
			associated = (ssid == associated),
			lastScan = os.time()
		}
	end

	-- Bug #5227 if we are associated use the same quality indicator
	-- as the icon bar
	if associated and _scanResults[associated] then
		_scanResults[associated].quality = self:getLinkQuality()
	end

	if callback then
		callback(_scanResults)
	end

	self.scanTask = nil
end


-- parse and return wpa status
function t_wpaStatus(self)
	assert(Task:running(), "Wireless:wpaStatus must be called in a Task")

	local statusStr = self:request("STATUS")

	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end

	return status
end


function t_addNetwork(self, ssid, option)
	assert(Task:running(), "Wireless:addNetwork must be called in a Task")

	local request, response

	-- make sure this ssid is not in any configuration
	self:t_removeNetwork(ssid)

	log:info("Connect to ", ssid)
	local flags = (_scanResults[ssid] and _scanResults[ssid].flags) or ""

	-- Set to use dhcp by default
	self:_editNetworkInterfaces(ssid, "dhcp", "script /etc/network/udhcpc_action")

	response = self:request("ADD_NETWORK")
	local id = string.match(response, "%d+")
	assert(id, "wpa_cli failed: to add network")

	request = 'SET_NETWORK ' .. id .. ' ssid "' .. ssid .. '"'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	if string.find(flags, "IBSS") or option.ibss then
		request = 'SET_NETWORK ' .. id .. ' mode 1 '
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	if option.encryption == "wpa" then
		log:info("encryption WPA")

		request = 'SET_NETWORK ' .. id .. ' key_mgmt WPA-PSK'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		request = 'SET_NETWORK ' .. id .. ' proto WPA'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		-- Setting the PSK can timeout
		pcall(function()
			      request = 'SET_NETWORK ' .. id .. ' psk "' .. option.psk .. '"'
			      assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
		      end)
	elseif option.encryption == "wpa2" then
		log:info("encryption WPA2")

		request = 'SET_NETWORK ' .. id .. ' key_mgmt WPA-PSK'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		request = 'SET_NETWORK ' .. id .. ' proto WPA2'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		-- Setting the PSK can timeout
		pcall(function()
			      request = 'SET_NETWORK ' .. id .. ' psk "' .. option.psk .. '"'
			      assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
		      end)
	else
		request = 'SET_NETWORK ' .. id .. ' key_mgmt NONE'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	if option.encryption == "wep40" or option.encryption == "wep104" then
		log:info("encryption WEP")

		request = 'SET_NETWORK ' .. id .. ' wep_key0 ' .. option.key
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- If we have not scanned the ssid then enable scanning with ssid 
	-- specific probe requests. This allows us to find APs with hidden
	-- SSIDS
	if not _scanResults[ssid] then
		request = 'SET_NETWORK ' .. id .. ' scan_ssid 1'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Disconnect from existing network
	self:t_disconnectNetwork()

	-- Use select network to disable all other networks
	request = 'SELECT_NETWORK ' .. id
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Allow association
	request = 'REASSOCIATE'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Save config, it will be removed later if it fails
	request = 'SAVE_CONFIG'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	return id
end


function t_removeNetwork(self, ssid)
	assert(Task:running(), "Wireless:removeNetwork must be called in a Task")

	local networkResults = self:request("LIST_NETWORKS")

	local id = false
	for nid, nssid in string.gmatch(networkResults, "([%d]+)\t([^\t]*).-\n") do
		if nssid == ssid then
			id = nid
			break
		end
	end

	-- Remove ssid from wpa supplicant
	if id then
		local request = 'REMOVE_NETWORK ' .. id
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		request = 'SAVE_CONFIG'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Remove dhcp/static ip configuration for network
	self:_editNetworkInterfaces(ssid)
end


function t_disconnectNetwork(self)
	assert(Task:running(), "Wireless:disconnectNetwork must be called in a Task")

	-- Force disconnect from existing network
	local request = 'DISCONNECT'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Force the interface down
	os.execute("/sbin/ifdown -f eth0")
end


function t_selectNetwork(self, ssid)
	assert(Task:running(), "Wireless:selectNetwork must be called in a Task")

	local networkResults = self:request("LIST_NETWORKS")
	log:info("list results ", networkResults)

	local id = false
	for nid, nssid in string.gmatch(networkResults, "([%d]+)\t([^\t]*).-\n") do
		log:info("id=", nid, " ssid=", nssid)
		if nssid == ssid then
			id = nid
			break
		end
	end

	-- Select network
	if not id then
		log:warn("can't find network ", ssid)
		return
	end

	-- Disconnect from existing network
	self:t_disconnectNetwork()

	local request = 'SELECT_NETWORK ' .. id
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Allow association
	request = 'REASSOCIATE'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Save configuration
	request = 'SAVE_CONFIG'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
end


function t_setStaticIP(self, ssid, ipAddress, ipSubnet, ipGateway, ipDNS)
	-- Reset the network
	os.execute("kill -TERM `cat /var/run/udhcpc.eth0.pid`")
	os.execute("/sbin/ifconfig eth0 0.0.0.0")

	-- Set static ip configuration for network
	self:_editNetworkInterfaces(ssid, "static",
				    "address " .. ipAddress,
				    "netmask " .. ipSubnet,
				    "gateway " .. ipGateway,
				    "dns " .. ipDNS,
				    "up echo 'nameserver " .. ipDNS .. "' > /etc/resolv.conf"
			    )

	-- Bring up the network
	local status = os.execute("/sbin/ifup eth0")
	log:info("ifup status=", status)
end


function _editNetworkInterfaces(self, ssid, method, ...)
	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
	assert(ssid, debug.traceback())
	ssid = string.gsub(ssid, "[ \t]", "_")
	log:info("munged ssid=", ssid)

	local fi = assert(io.open("/etc/network/interfaces", "r+"))
	local fo = assert(io.open("/etc/network/interfaces.tmp", "w"))

	local network = ""
	for line in fi:lines() do
		if string.match(line, "^mapping%s") or string.match(line, "^auto%s") then
			network = ""
		elseif string.match(line, "^iface%s") then
			network = string.match(line, "^iface%s([^%s]+)%s")
		end

		if network ~= ssid then
			fo:write(line .. "\n")
		end
	end

	if method then
		fo:write("iface " .. ssid .. " inet " .. method .. "\n")
		for _,v in ipairs{...} do
			fo:write("\t" .. v .. "\n")
		end
	end

	fi:close()
	fo:close()

	os.execute("/bin/mv /etc/network/interfaces.tmp /etc/network/interfaces")
end


function getLinkQuality(self)
	local snr = self:getSNR()

	if snr == nil or snr == 0 then
		return nil
	end

	local quality = 1
	for i, l in ipairs(WIRELESS_SNR) do
		if snr <= l then
			break
		end
		quality = i
	end

	return quality
end


function getSNR(self)
	local f = io.popen("/usr/sbin/iwpriv " .. self.interface .. " getSNR 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%d+)"))
end


function getRSSI(self)
	local f = io.popen("/usr/sbin/iwpriv " .. self.interface .. " getRSSI 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%-?%d+)"))
end


function getNF(self)
	local f = io.popen("/usr/sbin/iwpriv " .. self.interface .. " getNF 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%-?%d+)"))
end


function getTxBitRate(self)
	local f = io.popen("/usr/sbin/iwconfig " .. self.interface)
	if f == nil then
		return "0"
	end

	local t = f:read("*all")
	f:close()

	return string.match(t, "Bit Rate:(%d+%s[^%s]+)")
end


function _addPump(self)
	local source = function()
			       return self.t_sock:receive()
		       end

	local sink = function(chunk, err)
			     if chunk and string.sub(chunk, 1, 1) == "<" then
				     -- wpa event message
				     if self.eventSink  then
					     Task("wirelessEvent", nil,
						  function()
							  self.eventSink(chunk, err)
						  end):addTask()
				     end
			     else
				     -- request response
				     local task = table.remove(self.responseQueue, 1)
				     if task then
					     task:addTask(chunk, err)
				     end
			     end
		     end

	self:t_addRead(function()
			       -- XXXX handle timeout
			       return ltn12.pump.step(source, sink)
		       end,
		       0) -- no timeout
end


function request(self, ...)
	local task = Task:running()
	assert(task, "Wireless:request must be called in a Task")

	log:info("REQUEST: ", ...)
	self.t_sock:request(...)

	-- yield task
	table.insert(self.responseQueue, task)
	local _, reply = Task:yield(false)

	log:info("REPLY:", reply)
	return reply
end


function attach(self, sink)
	-- XXXX allow multiple sinks
	self.eventSink = sink
end


function detach(self)
	self.eventSink = nil
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
