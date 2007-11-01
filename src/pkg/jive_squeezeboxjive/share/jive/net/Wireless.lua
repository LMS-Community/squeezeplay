
local assert, ipairs, pairs, pcall, tonumber, tostring = assert, ipairs, pairs, pcall, tonumber, tostring

local oo          = require("loop.simple")

local io          = require("io")
local os          = require("os")
local string      = require("string")
local ltn12       = require("ltn12")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.socket")

local Socket      = require("jive.net.Socket")
local wireless    = require("jiveWireless")



module("jive.net.Wireless")
oo.class(_M, Socket)


-- wpa scan results signal level -> quality
-- FIXME tune with production boards
local WIRELESS_LEVEL = {
	180,
	190,
	200,
	210,
}

-- iwpriv snr -> quality
-- FIXME tune with production boards
local WIRELESS_SNR = {
	20,
	25,
	30,
	35,
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


function __init(self, jnt, interface, name)
	local obj = oo.rawnew(self, Socket(jnt, name))

	obj.interface = interface
	obj.t_sock = wireless:open()

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
		log:warn("code=", code, " mapping[1]=", mapping[1])
		if mapping[1] == code then
			log:warn("retruning=", name)
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
	log:warn("setRegion: ", cmd)
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


-- perform a network scan
function scan(self, callback)
	self.jnt:perform(function()
				 t_scan(self, callback)
			 end)
end


-- returns scan results, or nil if a network scan has not been performed.
function scanResults(self)
	return _scanResults
end


-- network scanning. this can take a little time so we do this in 
-- the network thread so the ui is not bocked.
function t_scan(self, callback)
	self:request("SCAN")

	local status = self:request("STATUS")
	local associated = string.match(status, "\nssid=([^\n]+)")

	local scanResults = self:request("SCAN_RESULTS")

	_scanResults = _scanResults or {}

	-- process in the main thread
	self.jnt:t_perform(function()
		for bssid, level, flags, ssid in string.gmatch(scanResults, "([%x:]+)\t%d+\t(%d+)\t(%S*)\t([^\n]+)\n") do

			local quality = 0
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
	end)
end


-- parse and return wpa status
function t_wpaStatusRequest(self)
	local statusStr = self:request("STATUS")

	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end

	return status
end


function t_addNetwork(self, ssid, option)
	local request, response

	-- make sure this ssid is not in any configuration
	self:t_removeNetwork(ssid)

	log:warn("Connect to ", ssid, " psk=", option.psk, " key=", option.key)
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
		log:warn("encryption WPA")

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
		log:warn("encryption WPA2")

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
		log:warn("encryption WEP")

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

	-- Use select network to disable all other networks
	request = 'SELECT_NETWORK ' .. id
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Save config, it will be removed later if it fails
	request = 'SAVE_CONFIG'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	return id
end


function t_removeNetwork(self, ssid)
	local networkResults = self:request("LIST_NETWORKS")
	log:warn("list results ", networkResults)

	local id = false
	for nid, nssid in string.gmatch(networkResults, "([%d]+)\t([^\t]*).-\n") do
		log:warn("id=", nid, " ssid=", nssid)
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
	log:warn("ifup status=", status)
end


function _editNetworkInterfaces(self, ssid, method, ...)
	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
	assert(ssid, debug.traceback())
	ssid = string.gsub(ssid, "[ \t]", "_")
	log:warn("munged ssid=", ssid)

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

	local quality = 0
	for i, l in ipairs(WIRELESS_SNR) do
		if snr < l then
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


function request(self, ...)
	return self.t_sock:request(...)
end


function attach(self, sink)
	-- calling attach requests unsolicied events from the wpa-cli
	self.t_sock:attach()

	local source = function()
			       return self.t_sock:receive()
		       end

	self:t_addRead(function()
			       ltn12.pump.step(source, self:safeSink(sink))
		       end)
end


function detach(self)
	--self.t_sock:detach()
	self:t_removeRead()
	self.t_sock = false
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
