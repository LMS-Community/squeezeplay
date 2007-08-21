
local ipairs, tonumber, tostring = ipairs, tonumber, tostring

local oo          = require("loop.simple")

local io          = require("io")
local os          = require("os")
local string      = require("string")
local ltn12       = require("ltn12")

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


-- global wireless network scan results
local _scanResults = {}


function __init(self, jnt, interface, name)
	local obj = oo.rawnew(self, Socket(jnt, name))

	obj.interface = interface
	obj.t_sock = wireless:open()

	return obj
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
		if associated then
			_scanResults[associated].quality = self:getLinkQuality()
		end

		if callback then
			callback(_scanResults)
		end
	end)
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
	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%d+)"))
end


function getRSSI(self)
	local f = io.popen("/usr/sbin/iwpriv " .. self.interface .. " getRSSI 1")
	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%-?%d+)"))
end


function getNF(self)
	local f = io.popen("/usr/sbin/iwpriv " .. self.interface .. " getNF 1")
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
