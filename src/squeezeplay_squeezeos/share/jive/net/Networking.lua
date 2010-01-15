--[[
=head1 NAME

jive.net.Networking 

=head1 DESCRIPTION

This class implements methods for administering network interfaces.

Much of the methods in this class need to be done through Task. These methods are by convention prefixed with t_

=head1 SYNOPSIS

pull in networking object to manipulate wireless interface

	local wirelessInterface = Networking:wirelessInterface()
	local wireless = Networking(jnt, wirelessInterface)

=head1 FUNCTIONS

=cut
--]]

--[[

The file modifies the /etc/network/interfaces file, as described below:

    # Local loopback - always needed
    auto lo
    iface lo inet loopback

    # Wired interface
    # start / stop using 'ifup eth0' and 'ifdown eth0'
    # 'auto eth0' brings this interface up automatically on boot
    auto eth0
    iface eth0 inet dhcp
    	script /etc/network/udhcpc_action

    # Wireless interface
    # the mapping file is used by the network scripts, and must not be changed
    mapping wlan0
        script /etc/network/if_mapping

    # in this file you must use '_' instead of ' ' in ssid
    # start / stop using 'ifup wlan0=<SSID>' and 'ifdown wlan0=<SSID>
    # the wireless configuration must be in /etc/wpa_supplicant.conf
    auto wlan0=<SSID>
    iface <SSID> inet dhcp
        script /etc/network/udhcpc_action

This file also contains any static-ip configuration.

--]]


local assert, ipairs, pairs, pcall, tonumber, tostring, type = assert, ipairs, pairs, pcall, tonumber, tostring, type

local oo          = require("loop.simple")

local io          = require("io")
local os          = require("os")
local math        = require("math")
local string      = require("jive.utils.string")
local table       = require("jive.utils.table")
local ltn12       = require("ltn12")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.socket")

local System      = require("jive.System")
local Framework   = require("jive.ui.Framework")
local Socket      = require("jive.net.Socket")
local Process     = require("jive.net.Process")
local Task        = require("jive.ui.Task")
local network     = require("jiveWireless")

module("jive.net.Networking")
oo.class(_M, Socket)


local SSID_TIMEOUT = 20000

-- TODO: Remove when wpsapp is replaced with WPS capable wpa_supplicant
local wpaSupplicantRunning = true


-- wpa scan results signal level -> quality
-- FIXME tune with production boards
local WIRELESS_LEVEL = {
	0,
	175,
	180,
	190,
}

-- FIXME: reduce to two regions, and make sure XX is the correct code for all other regions
local REGION_CODE_MAPPING = {
	-- name, marvell code, atheros code
	[ "US" ] = { 0x10, 4  }, -- ch 1-11
	[ "XX" ] = { 0x30, 14 }, -- ch 1-13
}


-- global for interface objects
local interfaceTable = {}



--[[

=head2 jive.net.Networking(jnt, interface, name)

Constructs an object for administration of a network interface. This
methods should not be called from the application code directly, instead
one of the factory methods below should be used.

=cut
--]]

function __init(self, jnt, interface, isWireless)
	local obj = oo.rawnew(self, Socket(jnt, interface))

	obj.interface     = interface
	obj.wireless      = isWireless

	if isWireless then
		obj:detectChipset()
	end

	obj._scanResults = {}
	obj.responseQueue = {}
	obj:open()

	return obj
end


function detectChipset(self)
	local f = io.popen("/sbin/lsmod 2> /dev/null")
	if f == nil then
		return
	end

        while true do
               	local line = f:read("*l")
        	if line == nil then
               		break
        	end

       		local module = string.match(line, "^(%w+)%s+")
       		if module == "ar6000" then
               		self.chipset = "atheros"
       		elseif module == "sd8686" then
               		self.chipset = "marvell"
       		elseif module == "gspi8xxx" then
               		self.chipset = "marvell"
       		end
       	end
       	f:close()
end


--[[

=head2 jive.net.Networking:interfaces(jnt)

Factory method to return a table of interfaces on a device.

=cut
--]]

function interfaces(self, jnt)
	assert(jnt, debug.traceback())

	-- only scan once
	for interface, _ in pairs(interfaceTable) do
		return interfaceTable
	end

	log:debug('looking for network interfaces')

	local interfaces = {}

        local f = assert(io.open("/proc/net/dev"))
	while true do
        	local line = f:read("*l")
		if line == nil then
			break
		end

		local interface = string.match(line, "^%s*(%w+):")
		log:debug("found: ", interface)

		if interface ~= nil and interface ~= 'lo' and not string.find( interface, "usb") then
			table.insert(interfaces, interface)
		end
	end
	f:close()

	log:debug('looking for wireless interfaces')

	local wireless = {}

	-- XXXX replace iwconfig with ioctl lookup
	local f = io.popen("/sbin/iwconfig 2> /dev/null")
        if f ~= nil then
		while true do
        		local line = f:read("*l")
			if line == nil then
				break
			end

			local interface = string.match(line, "^(%w+)%s+")
			if interface then
				log:debug("found wireless: ", interface)
				wireless[interface] = true
			end
		end

        	f:close()
	end

	-- create Networking interface objects
	for _, interface in ipairs(interfaces) do
		interfaceTable[interface] = self(jnt, interface, wireless[interface])
	end

	return interfaceTable
end


--[[

Returns the active interface

--]]
function activeInterface(self)
	local active = nil

        local f = assert(io.open("/etc/network/interfaces"))
	while true do
        	local line = f:read("*l")
		if line == nil then
			break
		end

		local iface = string.match(line, "auto (%w+)")
		if iface ~= nil and iface ~= 'lo' then
			active = iface
			break
		end
	end
	f:close()

	return interfaceTable[active]
end


--[[

=head2 jive.net.Networking:wirelessInterface(jnt)

Convience method to return first wireless interface object.

=cut
--]]

function wirelessInterface(self, jnt)
        self:interfaces(jnt)

	for _, interface in pairs(interfaceTable) do
		if interface.wireless then
			return interface
		end
	end
	return nil
end


--[[

=head2 jive.net.Networking:wiredInterface(jnt)

Convience method to return first wired interface object.

=cut
--]]

function wiredInterface(self, jnt)
        self:interfaces(jnt)

	for _, interface in pairs(interfaceTable) do
		if not interface.wireless  then
			return interface 
		end
	end
	return nil
end


--[[

=head2 networking:getName(self, interface)

Returns the interface name of interface object

=cut
--]]

function getName(self)
	return self.interface
end


--[[

=head2 networking:isAtheros(self)

Returns true if the system is using Atheros wlan

=cut
--]]
function isAtheros(self)
	return self.chipset == "atheros"
end


--[[

=head2 networking:isMarvell(self)

Returns true if the system is using Marvell wlan

=cut
--]]
function isMarvell(self)
	return self.chipset == "marvell"
end


--[[

=head2 networking:isWireless(self)

Return true if the I<interface> is wireless

=cut
--]]

function isWireless(self)
	return self.wireless
end


--[[

=head2 networking:getIP(self, interface)

Returns the ip address, if any, of the object I<interface>

=cut
--]]

function getIP(self, interfaceObj)
	local ipaddr
	local cmd = io.popen("/sbin/ifconfig " .. interfaceObj.interface)
	for line in cmd:lines() do
		ipaddr = string.match(line, "inet addr:([%d%.]+)")
		if ipaddr ~= nil then 
			break 
		end
	end
	cmd:close()
	return ipaddr
end


--[[

=head2 networking:getRegionNames()

returns the available wireless region names

=cut
--]]

function getRegionNames(self)
	return pairs(REGION_CODE_MAPPING)
end


--[[

=head2 networking:getRegion()

Returns the current region for this interface

=cut
--]]

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
	local fh = assert(io.popen("/sbin/iwpriv " .. self.interface .. " getregioncode"))
	local line = fh:read("*a")
	fh:close()

	local code = tonumber(string.match(line, "getregioncode:(%d+)"))

	for name,mapping in pairs(REGION_CODE_MAPPING) do
		log:debug("code=", code, " mapping[1]=", mapping[1])
		if mapping[1] == code then
			log:debug("returning=", name)
			return name
		end
	end
	return nil
end


--[[

=head2 networking:setRegion(region)

Sets the current region for this interface

=cut
--]]

function setRegion(self, region)
	if type(self.interface) ~= "string" then
		return
	end
	local mapping = REGION_CODE_MAPPING[region]
	if not mapping then
		return
	end

	-- save config file
	System:atomicWrite("/etc/network/config",
		"REGION=" .. region .. "\n" ..
		"REGIONCODE=" .. mapping[1] .. "\n")

	-- set new region
	local cmd = "/sbin/iwpriv " .. self.interface .. " setregioncode " .. mapping[1]
	log:info("setRegion: ", cmd)
	os.execute(cmd)

end


--[[

=head2 jive.net.Networking:getMarvellRegionCode()

returns the region code for Marvell on Jive

=cut
--]]

function getMarvellRegionCode(self)
	local mapping = REGION_CODE_MAPPING[region or self:getRegion()]
	return mapping and mapping[1] or 0
end


--[[

=head2 jive.net.Networking:getAtherosRegionCode()

returns the region code for Atheros on Squeezebox

=cut
--]]

function getAtherosRegionCode(self)
	local mapping = REGION_CODE_MAPPING[region or self:getRegion()]
	return mapping and mapping[2] or 0
end


--[[

=head2 jive.net.Networking:scan(callback)

Start a wireless network scan in a new task.

=cut
--]]

function scan(self, callback)
	if self._scantask then
		return
	end

	self._scantask = Task("networkScan", self, function()
		if self.wireless then
			_wirelessScanTask(self, callback)
		else
			_ethernetScanTask(self, callback)
		end
		self._scantask = nil
	end):addTask()
end


--[[

=head2 jive.net.Networking:scanResults()

returns wireless scan results, or nil if a network scan has not been performed.

=cut
--]]

function scanResults(self)
	assert(self, debug.traceback())

	return self._scanResults
end


--[[

=head2 jive.net.Networking:_scan_task(callback)

network scanning. this can take a little time so we do this in 
the network thread so the ui is not blocked.

=cut
--]]

function _wirelessScanTask(self, callback)
	assert(Task:running(), "Networking:scan must be called in a Task")

	local status, err = self:request("SCAN")
	if err then
		return
	end

	-- get the active interface mapping (ssid)
	local active = self:_ifstate()

	-- get the associated network
	local associated = false
	if active then
		local status, err = self:request("STATUS")
		if err then
			return
		end

		associated = string.match(status, "\nssid=([^\n]+)")
	end
 
	-- load configured networks from wpa supplicant
	local networks = self:request("LIST_NETWORKS")

	-- get scan results
	local scan, err = self:request("SCAN_RESULTS")
	if err then
		return
	end

	local now = Framework:getTicks()

	-- process scan results
	for bssid, level, flags, ssid in string.gmatch(scan, "([%x:]+)\t%d+\t(%d+)\t(%S*)\t([^\n]+)\n") do

		local quality = 1
		level = tonumber(level)
		for i, l in ipairs(WIRELESS_LEVEL) do
			if level < l then
				break
			end
			quality = i
		end

		self._scanResults[ssid] = {
			bssid = string.lower(bssid),
			flags = flags,
			level = level,
			quality = quality,
			associated = (ssid == active),
			lastScan = now
		}
	end

	-- process configured networks
	for id, ssid, flags in string.gmatch(networks, "([%d]+)\t([^\t]*)\t[^\t]*\t([^\t]*)\n") do
		if not self._scanResults[ssid] then
			self._scanResults[ssid] = {
				bssid = false,
				flags = "",
				level = 0,
				quality = 0,
				associated = false,
			}
		end

		self._scanResults[ssid].id = id
		self._scanResults[ssid].lastScan = now
	end

	-- timeout networks
	local count = 0
	for ssid, entry in pairs(self._scanResults) do
		count = count + 1
		if now - entry.lastScan > SSID_TIMEOUT then
			self._scanResults[ssid] = nil
		end
	end

	log:info("scan found ", count, " wireless networks")

	-- Bug #5227 if we are associated use the same quality indicator
	-- as the icon bar
	if associated and self._scanResults[associated] then
		self._scanResults[associated].quality = self:getLinkQuality()
	end

	if callback then
		callback(self._scanResults)
	end

	self.scanTask = nil
end


function _ethernetScanTask(self, callback)
	local status = self.t_sock:ethStatus()

	local active = self:_ifstate()

	status.flags  = "[ETH]"
	status.lastScan = Framework:getTicks()
	status.associated = (self.interface == active)

	self._scanResults[self.interface] = status

	callback(self._scanResults)

	return
end


-- check the ifup interface state. returns true if the interface is enabled
-- or the enabled ssid for wireless interfaces.
function _ifstate(self)
	 local active = false

	 local f = assert(io.open("/var/run/ifstate"))
	 while true do
	 	local line = f:read("*l")
		if line == nil then
			break
		end

		local iface, mapping = string.match(line, "([^=]+)=?(.*)")
		if iface == self.interface then
			active = mapping or true
			break
		end
	end
	f:close()

	return active
end



function status(self)
	assert(Task:running(), "Networking:basicStatus must be called in a Task")

	local status = {}

	if self.wireless then
		local statusStr = self:request("STATUS")

		for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
			status[k] = v
		end
	else
		status = self.t_sock:ethStatus()
		status.wpa_state = "COMPLETED"
	end

	return status
end


--[[

=head2 jive.net.Networking:t_wpaStatus()

parse and return wpa status

=cut
--]]

-- XXXX rename to just status()
function t_wpaStatus(self)
	assert(Task:running(), "Networking:wpaStatus must be called in a Task")

	local status = self:status()

	-- exit early if we are not connected
	if status.wpa_state ~= "COMPLETED" then
		return status
	end

	local f, err = io.popen("/sbin/ifconfig " .. self.interface)
	if f == nil then
		log:error("Can't read ifconfig: ", err)
	else
		local ifconfig = f:read("*all")
		f:close()

		local ipaddr = string.match(ifconfig, "inet addr:([%d\.]+)")
		local subnet = string.match(ifconfig, "Mask:([%d\.]+)")

		status.ip_address = ipaddr
		status.ip_subnet = subnet
	end

	-- exit early if we do not have an ip address
	if not status.ip_address then
		return status
	end

	local f, err = io.popen("/bin/ip route")
	if f == nil then
		log:error("Can't read default route: ", err)
	else
		local iproute = f:read("*all")
		f:close()

		local gateway = string.match(iproute, "default via ([%d\.]+)")

		status.ip_gateway = gateway
	end

	local f = io.open("/etc/resolv.conf")
	if f ~= nil then
		while true do
			local line = f:read("*l")
			if line == nil then
				break
			end

			local dns = string.match(line, "nameserver ([%d\.]+)")
			if dns then
				status.ip_dns = dns
				break
			end
		end
		f:close()
	end

	return status
end


--[[

=head2 jive.net.Networking:t_addWPSNetwork(ssid)

wpa_supplicant using with Atheros already adds the network
to wpa_supplicant.conf when using WPS but it still needs to
be added to the interfaces file

=cut
--]]

function t_addWPSNetwork(self, ssid)
	assert(Task:running(), "Networking:addNetwork must be called in a Task")

	-- Set to use dhcp by default
	self:_editNetworkInterfaces(ssid, "dhcp", "script /etc/network/udhcpc_action")
end

--[[

=head2 jive.net.Networking:t_addNetwork(ssid, option)

adds a network to the list of discovered networks

=cut
--]]

function t_addNetwork(self, ssid, option)
	assert(Task:running(), "Networking:addNetwork must be called in a Task")

	log:info("add network ", ssid)

	-- make sure this ssid is not in any configuration
	self:t_removeNetwork(ssid)

	-- Set to use dhcp by default
	self:_editNetworkInterfaces(ssid, "dhcp", "script /etc/network/udhcpc_action")

	if not self.wireless then
		-- no further action for ethernet
		return
	end

	log:info("Connect to ", ssid)
	local flags = (self._scanResults[ssid] and self._scanResults[ssid].flags) or ""

	local request, response

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

		if #option.psk <= 63 then
			-- psk is ASCII passphrase (8 - 63 chars) and needs quotes
			request = 'SET_NETWORK ' .. id .. ' psk "' .. option.psk .. '"'
		else
			-- psk is 64 hex-digits (32 bytes) and needs _no_ quotes
			request = 'SET_NETWORK ' .. id .. ' psk ' .. option.psk
		end

		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	elseif option.encryption == "wpa2" then
		log:info("encryption WPA2")

		request = 'SET_NETWORK ' .. id .. ' key_mgmt WPA-PSK'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		request = 'SET_NETWORK ' .. id .. ' proto WPA2'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		if #option.psk <= 63 then
			-- psk is ASCII passphrase (8 - 63 chars) and needs quotes
			request = 'SET_NETWORK ' .. id .. ' psk "' .. option.psk .. '"'
		else
			-- psk is 64 hex-digits (32 bytes) and needs _no_ quotes
			request = 'SET_NETWORK ' .. id .. ' psk ' .. option.psk
		end

		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	else
		request = 'SET_NETWORK ' .. id .. ' key_mgmt NONE'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	if option.encryption == "wep40" or option.encryption == "wep104" then
		log:info("encryption WEP")

		request = 'SET_NETWORK ' .. id .. ' wep_key0 ' .. option.key
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Enable scanning with ssid specific probe requests at all times.
	-- (Previously we only did it for hidden SSIDs, i.e. when not listed in self._scanResults[ssid])
	-- This allows us to find APs with hidden SSIDs _and_ APs where the SSID
	--  is hidden later on. And it also works for non hidden SSIDs.
	request = 'SET_NETWORK ' .. id .. ' scan_ssid 1'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Disconnect from existing network
	self:_ifDown()

	-- Use select network to disable all other networks
	request = 'SELECT_NETWORK ' .. id
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Reassociate seems to break ad hoc
	if not (string.find(flags, "IBSS") or option.ibss) then
		-- Allow association
		request = 'REASSOCIATE'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Save config, it will be removed later if it fails
	request = 'SAVE_CONFIG'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	return id
end


--[[

=head2 jive.net.Networking:t_removeNetwork(ssid)

forgets a previously discovered network 

=cut
--]]

function t_removeNetwork(self, ssid)
	assert(Task:running(), "Networking:removeNetwork must be called in a Task")

	log:info("remove network ", ssid)

	if self.wireless then
		local networkResults = self:request("LIST_NETWORKS")

		local id = false
		local flags = false
		for nid, nssid, nbssid, nflags in string.gmatch(networkResults, "([%d]+)\t([^\t]*)\t([^\t]*)\t(.-)\n") do
			if nssid == ssid then
				id = nid
				flags = nflags
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

		-- Bug 10869: Make sure only one dhcp client is running on the wireless interface
		-- If we are forgetting the currently used wireless connection, also disconnect
		-- This in turn calls ifdown and stops the dhcp client daemon
		if flags and flags == "[CURRENT]" then
			self:t_disconnectNetwork()
		end

		-- Remove dhcp/static ip configuration for network
		self:_editNetworkInterfaces(ssid)
	end
end


--[[
=head2 jive.net.Networking:t_disconnectNetwork()

brings down a network interface. If wireless, then force the wireless disconnect as well

=cut
--]]
function t_disconnectNetwork(self)
	 self:_ifDown()
end


--[[

=head2 jive.net.Networking:t_selectNetwork(ssid)

selects a network to connect to. wireless only

=cut
--]]

function t_selectNetwork(self, ssid)
	assert(Task:running(), "Networking:selectNetwork must be called in a Task")

	log:info("select network ", ssid)

	-- set as auto network
	self:_editAutoInterfaces(ssid)

	-- bring the interface up
	self:_ifUp(ssid)
end


--[[

=head2 jive.net.Networking:t_setStaticIp(ssid, ipAddress, ipSubnet, ipGateway, ipDNS)

apply IP address and associated configuration parameters to a network interface

=cut
--]]


function t_setStaticIP(self, ssid, ipAddress, ipSubnet, ipGateway, ipDNS)
	assert(type(self.interface) == 'string')
	-- Reset the network
	local killCommand   = "kill -TERM `cat /var/run/udhcpc." .. self.interface .. ".pid`"
	local killCommand2  = "killall zcip > /dev/null"
	local configCommand = "/sbin/ifconfig " .. self.interface .. " 0.0.0.0"

	os.execute(killCommand)
	os.execute(killCommand2)
	os.execute(configCommand)

	-- Set static ip configuration for network
	self:_editNetworkInterfaces(ssid, 
		"static",
		"address " .. ipAddress,
		"netmask " .. ipSubnet,
		"gateway " .. ipGateway,
		"dns " .. ipDNS,
		"up echo 'nameserver " .. ipDNS .. "' > /etc/resolv.conf"
	)

	self:_ifUp(ssid)
end


--[[

=head2 jive.net.Networking:_ifUp(ssid)

brings I<interface> up, and all others (except loopback) down
writes to /etc/network/interfaces and configures i<interface> 
to be the only interface brought up at next boot time

if the optional ssid argument is given, correct use of ifup I<interface>=I<ssid> is used

=cut
--]]

function _ifUp(self, ssid)
	-- bring down all other interfaces
	for _, interface in pairs(interfaceTable) do
		if interface ~= self then
			interface:_ifDown()
		end
	end

	-- associate
	if self.wireless then
		-- FIXME this should be handled by the ifup scripts

		-- We need to kick wpa_cli in order to work properly
		-- Also during WPS wpa_cli was stopped
		self:restartWpaCli()

		local networkResults = self:request("LIST_NETWORKS")

		local id = false
		for nid, nssid in string.gmatch(networkResults, "([%d]+)\t([^\t]*).-\n") do
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
		local request = 'DISCONNECT'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		local request = 'SELECT_NETWORK ' .. id
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		-- Allow association
		request = 'REASSOCIATE'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		-- Save configuration
		request = 'SAVE_CONFIG'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

	end

	-- bring interface up
	local iface = self.interface
	if self.wireless then
		ssid = string.gsub(ssid, "[ \t]", "_")
		-- Bug 11840: Allow special chars in SSID
		-- First escape '\' and '"' ...
		ssid = string.gsub(ssid, '\\', '\\\\')
		ssid = string.gsub(ssid, '"', '\\"')
		-- ... then quote SSID for ifup call
		iface = '"' .. iface .. "=" .. ssid .. '"'
	end

	log:info("ifup ", iface)
	self:_ifUpDown("/sbin/ifup " .. iface)
end


--[[

=head2 networking:_ifDown()

brings I<interface> down
=cut
--]]

function _ifDown(self)
	-- bring interface down
	local active = self:_ifstate()

	if active then
		local iface = self.interface
		if self.wireless then
			-- Bug 11840: Allow special chars in SSID
			-- First escape '\' and '"' ...
			local ssid = string.gsub(active, '\\', '\\\\')
			ssid = string.gsub(ssid, '"', '\\"')
			-- ... then quote SSID for ifdown call
			iface = '"' .. iface .. "=" .. ssid .. '"'
		end

		log:info("ifdown ", iface)
		self:_ifUpDown("/sbin/ifdown " .. iface .. " -f")

		if not self.wireless then
			return
		end

		-- FIXME this should be handled by the ifdown scripts

		-- disconnect
		local networkResults = self:request("LIST_NETWORKS")

		local id = false
		for nid, nssid in string.gmatch(networkResults, "([%d]+)\t([^\t]*).-\n") do
			log:info("id=", nid, " ssid=", nssid)
			if nssid == active then
				id = nid
				break
			end
		end

		if id then
			-- Disconnect from existing network
			local request = 'DISCONNECT'
			assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

			-- Disable network
			local request = 'DISABLE_NETWORK ' .. id
			assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

			-- Save configuration
			request = 'SAVE_CONFIG'
			assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)

		end
	end
end


function _ifUpDown(self, cmd)
	-- reading the output of ifup causes the process to block, we
	-- don't need the output, so send to /dev/null
	local proc = Process(self.jnt, cmd .. " 2>1 > /dev/null")
	proc:read(
		function(chunk, err)
			if err then
				log:error("if command failed: ", err)
				return false
			end
                       	-- FIXME: if command was ifup and command succeeded, bring down other interfaces
                       	if chunk ~= nil then
                       	end
                        return 1
       		end)

	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end
end


function _editAutoInterfaces(self, ssid)
	local interface = self.interface

	-- for the `auto interface[=<ssid>]` line
	local autoInterface = interface

	-- for the `iface <interface|ssid> inet ...` line
	local iface_name = interface

	if ssid and self.wireless then
		ssid = string.gsub(ssid, "[ \t]", "_")
		autoInterface = interface .. "=" .. ssid
		iface_name = ssid
	end

	log:debug('writing /etc/network/interfaces, enabling auto for ', autoInterface)

	local fi = assert(io.open("/etc/network/interfaces", "r+"))
	local outStr = ""

	local autoSet = false
	for line in fi:lines() do
		if string.match(line, "^auto%s") then
			-- if the interface is to be enabled, it should continue to be set to auto 
			if string.matchLiteral(line, autoInterface) then
				outStr = outStr .. line .. "\n"
				autoSet = true
			elseif string.match(line, "^auto%slo") then
				outStr = outStr .. line .. "\n"
			else
				log:debug('disabling interface: ', line)
			end
		elseif string.match(line, "^iface%s") then
			if not autoSet and string.matchLiteral(line, iface_name) then
				log:debug('enabling interface:', autoInterface)
				outStr = outStr .. "auto " .. autoInterface .. "\n"
				autoSet = true
			end
			outStr = outStr .. line .. "\n"
		else
			outStr = outStr .. line .. "\n"
		end
	end

	fi:close()

	System:atomicWrite("/etc/network/interfaces", outStr)
end


function _editNetworkInterfacesBlock( self, outStr, iface_name, method, ...)

	if method then
		outStr = outStr .. "iface " .. iface_name .. " inet " .. method .. "\n"
		log:debug("WRITING: ", "iface ", iface_name, " inet ", method)
		for _,v in ipairs{...} do
			outStr = outStr .. "\t" .. v .. "\n"
			log:debug("WRITING:\t", v)
		end
	end

	return outStr
end


function _editNetworkInterfaces( self, ssid, method, ...)
	local iface = self.interface

	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
	assert(ssid, debug.traceback())
	ssid = string.gsub(ssid, "[ \t]", "_")

	log:debug('WRITING /etc/network/interfaces for ', iface, ', ssid: ', ssid , ' method: ', method)

	local fi = assert(io.open("/etc/network/interfaces", "r+"))
	local outStr = ""

	local iface_name

	if ssid then
		iface_name = ssid
	else
		iface_name = iface
	end

	local network = ""
	local done = false

	for line in fi:lines() do
		-- this cues a new block, so clear the network variable
		if string.match(line, "^mapping%s") or string.match(line, "^auto%s") then
			network = ""
		-- this also cues a new block, possibly for iface_name
		elseif string.match(line, "^iface%s") then
			network = string.match(line, "^iface%s([^%s]+)%s")
			-- when network is iface_name, write a new block for it
			if network == iface_name then
				outStr = self:_editNetworkInterfacesBlock( outStr, network, method, ...)
				-- mark that we're done writing the iface_name block
				done = true
			end
		end
		-- write any line except what previously existed for the iface_name block
		if network ~= iface_name then
			outStr = outStr .. line .. "\n"
		end
	end

	-- if we haven't written the block for iface_name, do it now
	if not done then
		outStr = self:_editNetworkInterfacesBlock( outStr, iface_name, method, ...)
	end

	fi:close()

	System:atomicWrite("/etc/network/interfaces", outStr)
end


--[[
=head2 jive.net.Networking:getLinkQuality()

returns "quality" and snr of wireless interface
used for dividing SNR values into categorical levels of signal quality

(deprecated, use getSignalStrength instead)

=cut
--]]

function getLinkQuality(self)
	local strength = getSignalStrength(self)

	return math.ceil(strength / 25), strength
end


--[[

=head2 jive.net.Networking:getSNR()

returns signal to noise ratio of wireless link

=cut
--]]

function getSNR(self)
	if type(self.interface) ~= 'string' then
		return 0
	end

	if not self.t_sock then
		return 0
	end

	local t = self.t_sock:getSNR()
	if t == nil then
		log:error("getSNR() failed")
		return 0
	end

	-- == Marvell ==
	-- t[1] : Beacon non-average
	-- t[2] : Beacon average
	-- t[3] : Data non-average
	-- t[4] : Data average
	-- == Atheros ==
	-- t[1] : Beacon non-average
	-- t[2] : Beacon average
	-- t[3] : 0
	-- t[4] : 0

	if self.minSNR == nil then
		self.minSNR = t[2]
		self.maxSNR = t[2]
	else
		self.minSNR = math.min(self.minSNR, t[2])
		self.maxSNR = math.max(self.maxSNR, t[2])
	end

	return t[2], self.minSNR, self.maxSNR
end


-- returns wireless signal strength as a percentage
function getSignalStrength(self)
	local snr = getSNR(self)

	-- with informal testing I see a SNR range of: 
	-- jive: 5 - 71
	-- baby: 5 - 72

	-- an SNR of 20dB should be adequate, this is
	-- tuned so 40 SNR = 100%

	return math.ceil((math.min(snr, 40) / 40) * 100), snr
end


--[[

=head2 jive.net.Networking:getTxBitRate()

returns bitrate of a wireless interface

=cut
--]]

function getTxBitRate(self)
	if type(self.interface) ~= 'string' then
		return "0"
	end
	local f = io.popen("/sbin/iwconfig " .. self.interface)
	if f == nil then
		return "0"
	end

	local t = f:read("*all")
	f:close()

	return string.match(t, "Bit Rate:(%d+%s[^%s]+)")
end


--[[

=head2 jive.net.Networking:powerSave(enable)

sets wireless power save state

=cut
--]]

function powerSave(self, enable)
	if self._powerSaveState == enable then
		return
	end

	if not self.t_sock then
		return
	end

	self._powerSaveState = enable
	if enable then
		log:info("iwconfig power on")
		self.t_sock:setPower(true)
	else
		log:info("iwconfig power off")
		self.t_sock:setPower(false)
	end
end


--[[

=head2 jive.net.Networking:open()

opens a socket to pick up network events

=cut
--]]

function open(self)
	if self.t_sock then
		log:error("Socket already open")
		return
	end

	local err

	log:debug('Open network socket')
	-- self.wireless and self.chipset are only valid for wireless interfaces
	self.t_sock, err = network:open(self.interface, self.wireless, self.chipset)
	if err then
		log:warn(err)
	
		self:close()
		return false
	end

	if self.wireless then
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
				       local status, err = ltn12.pump.step(source, sink)
				       if err then
					       log:warn(err)
					       self:close()
				       end
			       end,
	       0) -- no timeout
	end

	return true
end


--[[

=head2 jive.net.Networking:close()

closes existing socket

=cut
--]]

function close(self)
	-- cancel queued requests
	for i, task in ipairs(self.responseQueue) do
		task:addTask(nil, "closed")
	end
	self.responseQueue = {}

	Socket.close(self)
end


--[[

=head2 jive.net.Networking:request()

pushes request to open socket

=cut
--]]

function request(self, ...)
	local task = Task:running()
	assert(task, "Networking:request must be called in a Task")

	if self:isMarvell(self) then
		if wpaSupplicantRunning == false then
			return "", "not running"
		end
	end


	log:debug("REQUEST: ", ...)

	-- open the socket if it is closed
	if not self.t_sock and not self:open() then
		-- XXXX callers expect a string
		return "", "closed"
	end

	local status, err = self.t_sock:request(...)

	if err then
		log:warn(err)
		self:close()

		-- XXXX callers expect a string
		return "", err
	end

	-- yield task
	table.insert(self.responseQueue, task)
	local _, reply, err = Task:yield(false)

	if not reply or err then
		log:warn(err)
		self:close()

		-- XXXX callers expect a string
		return "", err
	end

	log:debug("REPLY:", reply, " for ", ...)
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

=head2 jive.net.Networking:computeWPSChecksum()

Computes last digit of WPS pin

=cut
--]]

function computeWPSChecksum( pin)
	local accum = 0
	local digit
	local pin = pin * 10

	accum = accum + 3 * (math.floor(pin / 10000000) % 10)
	accum = accum + 1 * (math.floor(pin / 1000000) % 10)
	accum = accum + 3 * (math.floor(pin / 100000) % 10)
	accum = accum + 1 * (math.floor(pin / 10000) % 10)
	accum = accum + 3 * (math.floor(pin / 1000) % 10)
	accum = accum + 1 * (math.floor(pin / 100) % 10)
	accum = accum + 3 * (math.floor(pin / 10) % 10)
	digit = (accum % 10)

	return (10 - digit) % 10
end


--[[

=head2 jive.net.Networking:generateWPSPin()

Returns 8 digit generated WPS pin

=cut
--]]

function generateWPSPin(self)
	local wps_pin

-- TODO: Needed? Seem to be different after each reboot already
--	math.randomseed(os.time())
	wps_pin = math.random(0,10000000) % 10000000

	if wps_pin < 1000000 then
		wps_pin = wps_pin + 1000000
	end

	wps_pin = wps_pin * 10 + computeWPSChecksum( wps_pin)

	return wps_pin
end

--[[

=head2 jive.net.Networking:startWPSApp()

Starts the wpsapp (Marvell) to get passphrase etc. via WPS
Removes old wps.conf file

=cut
--]]

function startWPSApp(self, wpsmethod, wpspin)
	assert(wpsmethod, debug.traceback())

--	Do this in the same shell command to maintain the correct sequence, i.e.
--	 first stopping a still running wpsapp, then starting the new one.
--	Seems to be an issue lately - maybe since using the RT kernel?
--	self:stopWPSApp()
	log:info("startWPSApp")
	os.execute("rm /usr/sbin/wps/wps.conf 2>1 > /dev/null &")
	if( wpsmethod == "pbc") then
		os.execute("killall wpsapp; cd /usr/sbin/wps; ./wpsapp " .. self.interface .. " " .. wpsmethod .. " 2>1 > /dev/null &")
	else
		assert( wpspin, debug.traceback())
		os.execute("killall wpsapp; cd /usr/sbin/wps; ./wpsapp " .. self.interface .. " " .. wpsmethod .. " " .. wpspin .. " 2>1 > /dev/null &")
	end
end

--[[

=head2 jive.net.Networking:stopWPSApp()

Stops the wpsapp (Marvell) to get passphrase etc. via WPS

=cut
--]]

function stopWPSApp(self)
	log:info("stopWPSApp")
	os.execute("killall wpsapp 2>1 > /dev/null &")
end

--[[

=head2 jive.net.Networking:startWPASupplicant()

Starts wpa supplicant

=cut
--]]

function startWPASupplicant(self)
	log:info("startWPASupplicant")
	os.execute("/usr/sbin/wpa_supplicant -B -Dmarvell -i" .. self.interface .. " -c/etc/wpa_supplicant.conf")
	wpaSupplicantRunning = true
end

--[[

=head2 jive.net.Networking:stopWPASupplicant()

Stops wpa supplicant

=cut
--]]

function stopWPASupplicant(self)
	log:info("stopWPASupplicant")
	wpaSupplicantRunning = false
	os.execute("killall wpa_supplicant 2>1 > /dev/null &")
	self:close()
end

--[[

=head2 jive.net.Networking:restartWpaCli()

Restarts wpa cli

=cut
--]]

function restartWpaCli(self)
	log:info("restartWpaCli")
	os.execute("killall wpa_cli; /usr/sbin/wpa_cli -B -a/etc/network/wpa_action 2>1 > /dev/null &")
end

--[[

=head2 jive.net.Networking:stopWpaCli()

Stops wpa cli

=cut
--]]

function stopWpaCli(self)
	log:info("stopWpaCli")
	os.execute("killall wpa_cli 2>1 > /dev/null &")
end

--[[

=head2 jive.net.Networking:t_wpsStatus()

Returns data from wps.conf if present

=cut
--]]

function t_wpsStatus(self)
	assert(Task:running(), "Networking:t_wpsStatus must be called in a Task")

	local status = {}

	local fh = io.open("/usr/sbin/wps/wps.conf", "r")
	if fh == nil then
		status.wps_state = "IN_PROGRESS"
	else
		local wpsconf = fh:read("*all")
		fh:close()

		local proto = string.match(wpsconf, "proto=([^%s]+)")
		-- psk is ASCII passphrase (8 - 63 chars) and has quotes
		local psk = string.match(wpsconf, "psk=\"(.+)\"\n")
		if psk == nil then
			-- psk is 64 hex-digits (32 bytes) and has _no_ quotes
			psk = string.match(wpsconf, "psk=([^%s]+)")
		end
		local key = string.match(wpsconf, "wep_key0=([^%s]+)")

		-- No encryption
		if proto == nil and psk == nil and key == nil then
			status.wps_encryption = "none"
		-- WEP 64
		elseif key ~= nil and #key <= 10 then
			status.wps_encryption = "wep40"
		-- WEP 128
		elseif key ~= nil then
			status.wps_encryption = "wep104"
		-- WPA
		elseif proto == "WPA" then
			status.wps_encryption = "wpa"
		-- WPA2
		else
			status.wps_encryption = "wpa2"
		end

		status.wps_psk = psk
		status.wps_key = key

		status.wps_state = "COMPLETED"
	end

	return status
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
