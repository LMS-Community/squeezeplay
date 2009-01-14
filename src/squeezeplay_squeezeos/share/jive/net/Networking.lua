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

local assert, ipairs, pairs, pcall, tonumber, tostring, type = assert, ipairs, pairs, pcall, tonumber, tostring, type

local oo          = require("loop.simple")

local io          = require("io")
local os          = require("os")
local string      = require("string")
local table       = require("jive.utils.table")
local ltn12       = require("ltn12")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("net.socket")

local Framework   = require("jive.ui.Framework")
local Socket      = require("jive.net.Socket")
local Process     = require("jive.net.Process")
local Task        = require("jive.ui.Task")
local wireless    = require("jiveWireless")

local jnt         = jnt

module("jive.net.Networking")
oo.class(_M, Socket)


local SSID_TIMEOUT = 20000

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

-- FIXME: reduce to two regions, and make sure XX is the correct code for all other regions
local REGION_CODE_MAPPING = {
	-- name, marvell code, atheros code
	[ "US" ] = { 0x10, 4  }, -- ch 1-11
	[ "XX" ] = { 0x30, 14 }, -- ch 1-13
}


-- global for storing data on available network interfaces
local interfaceTable = {}

-- global wireless network scan results
local _scanResults = {}

-- singleton wireless instance per interface
local _instance = {}

--[[

=head2 jive.net.Networking(jnt, interface, name)

Constructs an object for administration of a network interface

=cut
--]]

function __init(self, jnt, interface, name)

	if _instance[interface] then
		return _instance[interface]
	end

	local obj = oo.rawnew(self, Socket(jnt, name))

	obj.interface     = interface
	obj.wireless      = ( interfaceTable[interface] and interfaceTable[interface].wireless ) 
				or obj:isWireless(interface)
	log:debug('Interface : ', obj.interface)
	log:debug('isWireless: ', obj.wireless)
	obj.responseQueue = {}

	obj:open()

	_instance[interface] = obj
	return obj
end

--[[

=head2 jive.net.Networking:interfaces()

returns a table of existing interfaces on a device

=cut
--]]


function interfaces(self)

	log:debug('scanning /proc/net/dev for interfaces...')

	for interface, _ in pairs(interfaceTable) do
		if interface then
			return interfaceTable
		end
	end

        local interfaces = {}

        local f = io.popen("cat /proc/net/dev")
        if f == nil then
		log:error('`cat /proc/net/dev` produced no results')
                return interfaces
        end

	while true do
        	local line = f:read("*l")
		if line == nil then
			break
		end
		local interface = string.match(line, "^%s*(%w+):")
		if interface ~= nil and interface ~= 'lo' then
			table.insert(interfaces, interface)
		end
	end

	for _, interface in ipairs(interfaces) do
		if not interfaceTable[interface] then
			interfaceTable[interface] = {}
		end
		self:isWireless(interface)
	end

        f:close()
        return interfaces

end

--[[

=head2 jive.net.Networking:wirelessInterface()

returns the first interface (if any) from the interface table capable of wireless

=cut
--]]


function wirelessInterface(self)

        self:interfaces()

	for interface, _ in pairs(interfaceTable) do
		if self:isWireless(interface) then
			log:debug('Wireless interface found: ', interface)
			return interface
		end
	end

	log:error('Error: interfaceTable shows no wireless interface. returning eth0, the default wireless on SBC')
	return 'eth0'

end


--[[

=head2 jive.net.Networking:wiredInterface()

returns the first available interface (if any) from the interface table that does not do wireless

=cut
--]]


function wiredInterface(self)

        self:interfaces()

	for interface, _ in pairs(interfaceTable) do
		if not self:isWireless(interface) then
			return interface 
		end
	end
	return false
end

--[[

=head2 jive.net.Networking:isWireless(interface)

returns true if the named I<interface> is wireless

=cut
--]]

function isWireless(self, interface)

	if not interface then
		return false
	end

	-- look to see if we've cached this already
	if interfaceTable[interface] and interfaceTable[interface].wireless then
		return true
	end

	local f = io.popen("/sbin/iwconfig " .. interface .. " 2>/dev/null")
        if f == nil then
                return false
        end

	while true do
        	local line = f:read("*l")
		if line == nil then
			break
		end

		local doesWireless = string.match(line, "^(%w+)%s+")
		if interface == doesWireless then
			interfaceTable[interface] = { wireless = true }
			f:close()
			return true
		end
	end

        f:close()

	return false
	
end

--[[

=head2 jive.net.Networking:getRegionNames()

returns the available wireless region names

=cut
--]]

function getRegionNames(self)
	return pairs(REGION_CODE_MAPPING)
end

--[[

=head2 jive.net.Networking:getRegion()

returns the current region

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
		log:info("code=", code, " mapping[1]=", mapping[1])
		if mapping[1] == code then
			log:info("returning=", name)
			return name
		end
	end
	return nil
end

--[[

=head2 jive.net.Networking:setRegion(region)

sets the current region

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
	local fh = assert(io.open("/etc/network/config", "w"))
	fh:write("REGION=" .. region .. "\n")
	fh:write("REGIONCODE=" .. mapping[1] .. "\n")
	fh:close()

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

start a wireless network scan in a new task

=cut
--]]

function scan(self, callback)
	Task("networkScan", self,
	     function()
		     t_scan(self, callback)
	     end):addTask()
end

--[[

=head2 jive.net.Networking:scanResults()

returns wireless scan results, or nil if a network scan has not been performed.

=cut
--]]

function scanResults(self)
	return _scanResults
end

--[[

=head2 jive.net.Networking:t_scan(callback)

network scanning. this can take a little time so we do this in 
the network thread so the ui is not blocked.

=cut
--]]


function t_scan(self, callback)
	assert(Task:running(), "Networking:scan must be called in a Task")

	local status, err = self:request("SCAN")
	if err then
		return
	end

	local status, err = self:request("STATUS")
	if err then
		return
	end

	local associated = string.match(status, "\nssid=([^\n]+)")

	local scanResults, err = self:request("SCAN_RESULTS")
	if err then
		return
	end

	_scanResults = _scanResults or {}

	local now = Framework:getTicks()

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
			bssid = string.lower(bssid),
			flags = flags,
			level = level,
			quality = quality,
			associated = (ssid == associated),
			lastScan = now
		}
	end

	for ssid, entry in pairs(_scanResults) do
		if now - entry.lastScan > SSID_TIMEOUT then
			_scanResults[ssid] = nil
		end
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

--[[

=head2 jive.net.Networking:t_wpaStatus()

parse and return wpa status

=cut
--]]

function t_wpaStatus(self)
	assert(Task:running(), "Networking:wpaStatus must be called in a Task")

	local statusStr = self:request("STATUS")

	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end

	return status
end

--[[

=head2 jive.net.Networking:t_addNetwork(ssid, option)

adds a network to the list of discovered networks

=cut
--]]


function t_addNetwork(self, ssid, option)
	assert(Task:running(), "Networking:addNetwork must be called in a Task")

	local request, response

	-- make sure this ssid is not in any configuration
	self:t_removeNetwork(ssid)

	log:info("Connect to ", ssid)
	local flags = (_scanResults[ssid] and _scanResults[ssid].flags) or ""

	-- Set to use dhcp by default
	self:_editNetworkInterfaces(self.interface, ssid, "dhcp", "script /etc/network/udhcpc_action")

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

--[[

=head2 jive.net.Networking:t_removeNetwork(ssid)

forgets a previously discovered network 

=cut
--]]

function t_removeNetwork(self, ssid)
	assert(Task:running(), "Networking:removeNetwork must be called in a Task")

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
	self:_editNetworkInterfaces(self.interface, ssid)
end

--[[

=head2 jive.net.Networking:t_disconnectNetwork()

brings down a network interface. If wireless, then force the wireless disconnect as well

=cut
--]]

function t_disconnectNetwork(self, interface)

	if not interface then
		interface = self.interface
	end

	assert(type(interface) == 'string')
	assert(Task:running(), "Networking:disconnectNetwork must be called in a Task")

	if self:isWireless(interface) then
		-- Force disconnect from existing network
		local request = 'DISCONNECT'
		assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Force the interface down
	local result = self:t_ifDown(interface)

end

--[[

=head2 jive.net.Networking:t_selectNetwork(ssid)

selects a network to connect to. wireless only

=cut
--]]


function t_selectNetwork(self, ssid)

	assert(Task:running(), "Networking:selectNetwork must be called in a Task")

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
	log:debug('##### wpa_cli select_network ', id , ' complete')

	-- Allow association
	request = 'REASSOCIATE'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	log:debug('##### wpa_cli reassociate complete')

	-- Save configuration
	request = 'SAVE_CONFIG'
	assert(self:request(request) == "OK\n", "wpa_cli failed:" .. request)
	log:debug('##### wpa_cli save_config complete')

	-- bring the inteface up
	self:t_ifUp(self.interface, ssid)

end


--[[

=head2 jive.net.Networking:t_setStaticIp(ssid, ipAddress, ipSubnet, ipGateway, ipDNS)

apply IP address and associated configuration parameters to a network interface

=cut
--]]


function t_setStaticIP(self, ssid, ipAddress, ipSubnet, ipGateway, ipDNS)
	assert(type(self.interface) == 'string')
	-- Reset the network
	local killCommand   = "kill -TERM `cat /var/run/udhcpc." .. self.interface .. "pid`"
	local configCommand = "/sbin/ifconfig " .. self.interface .. " 0.0.0.0"

	os.execute(killCommand)
	os.execute(configCommand)

	-- Set static ip configuration for network
	self:_editNetworkInterfaces(self.interface,
					ssid, 
					"static",
				    "address " .. ipAddress,
				    "netmask " .. ipSubnet,
				    "gateway " .. ipGateway,
				    "dns " .. ipDNS,
				    "up echo 'nameserver " .. ipDNS .. "' > /etc/resolv.conf"
			    )
	self:t_ifUp(interface, ssid)
end

--[[

=head2 jive.net.Networking:t_ifUp(interface, ssid)

brings I<interface> up, and all others (except loopback) down
writes to /etc/network/interfaces and configures i<interface> 
to be the only interface brought up at next boot time

if the optional ssid argument is given, correct use of ifup I<interface>=I<ssid> is used

=cut
--]]

function t_ifUp(self, interface, ssid)

	local iface_name = interface
	if ssid then
		iface_name = interface .. "=" .. ssid
	end

	-- bring interface up
	self:_toggleInterface(iface_name, 'up')

	--[[
	-- for now at least, bring down all other interfaces
	for otherInterface, _ in pairs(interfaceTable) do
		if otherInterface ~= 'lo' and otherInterface ~= interface then
			log:debug('Bringing down ', otherInterface)
			self:t_ifDown(otherInterface)
		end
	end
	--]]

end

--[[

=head2 jive.net.Networking:t_ifDown(interface)

brings I<interface> down
=cut
--]]

function t_ifDown(self, interface)
	local result = self:_toggleInterface(interface, 'down -f')
end


function _toggleInterface(self, interface, direction)

	local ifCmd = "/sbin/if" .. direction .. ' ' .. interface
	local proc = Process(jnt, ifCmd)
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
end

function _editNetworkInterfacesBlock( self, fo, iface_name, method, ...)
	if method then
		fo:write("iface " .. iface_name .. " inet " .. method .. "\n")
		log:debug("WRITING: ", "iface ", iface_name, " inet ", method)
		for _,v in ipairs{...} do
			fo:write("\t" .. v .. "\n")
			log:debug("WRITING:\t", v)
		end
	end
end

function _editAutoInterfaces(self, interface, ssid)

	-- for the `auto interface[=<ssid>]` line
	local enabledInterface = interface
	-- for the `iface <interface|ssid> inet ...` line
	local iface_name = interface

	if ssid then
		enabledInterface = interface .. "=" .. ssid
		iface_name = ssid
	end

	log:debug('EDITING THE AUTO LINES IN /etc/network/interfaces, enabledInterface is: ', enabledInterface)

	local fi = assert(io.open("/etc/network/interfaces", "r+"))
	local fo = assert(io.open("/etc/network/interfaces.tmp", "w"))
	local autoSet = false
	for line in fi:lines() do
		if string.match(line, "^mapping%s") or string.match(line, "^auto%s") then
			-- if the interface is to be enabled, it should continue to be set to auto 
			if (string.match(line, enabledInterface)) then
				log:debug('WRITING: ', line)
				fo:write(line .. "\n")
				autoSet = true
			else
				log:debug('This interface is not the enabled interface, so do not configure it to come up on boot')
			end
		elseif string.match(line, "^iface%s") then
			if not autoSet and string.match(line, iface_name) then
				log:debug('WRITING: auto ' .. enabledInterface)
				fo:write("auto " .. enabledInterface .. "\n")
				autoSet = true
			end
			log:debug('WRITING: ', line)
			fo:write(line .. "\n")
		else
			log:debug('WRITING: ', line)
			fo:write(line .. "\n")
		end
	end

	fi:close()
	fo:close()

	os.execute("/bin/mv /etc/network/interfaces.tmp /etc/network/interfaces")
	-- FIXME: workaround until filesystem write issue resolved
	os.execute("sync")

end

function _editNetworkInterfaces( self, interface, ssid, method, ...)
	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
---	assert(ssid, debug.traceback())
	ssid = string.gsub(ssid, "[ \t]", "_")
---	log:info("munged ssid=", ssid)

	log:debug('Writing /etc/network/interfaces for interface: ', interface, ', ssid: ', ssid , ' method: ', method)

	local fi = assert(io.open("/etc/network/interfaces", "r+"))
	local fo = assert(io.open("/etc/network/interfaces.tmp", "w"))

	local iface_name

	if ssid then
		iface_name = ssid
	else
		iface_name = interface
	end

	local network = ""
	local network_block_next = 0
	for line in fi:lines() do
	
		if string.match(line, "^mapping%s") or string.match(line, "^auto%s") then
			network = ""
			if network_block_next == 1 then
				network_block_next = 2
				self:_editNetworkInterfacesBlock( fo, iface_name, method, ...)
			end
		elseif string.match(line, "^iface%s") then
			network = string.match(line, "^iface%s([^%s]+)%s")
			if network_block_next == 1 then
				network_block_next = 2
				self:_editNetworkInterfacesBlock( fo, iface_name, method, ...)
			end
		end

		if network ~= interface then
			log:debug('WRITING: ', line)
			fo:write(line .. "\n")
		else
			network_block_next = 1
		end
	end

	if network_block_next != 2 then
		self:_editNetworkInterfacesBlock( fo, iface_name, method, ...)
	end

	fi:close()
	fo:close()

	os.execute("/bin/mv /etc/network/interfaces.tmp /etc/network/interfaces")

	-- FIXME: workaround until filesystem write issue resolved
	os.execute("sync")

	self:_editAutoInterfaces(interface, ssid)

end

--[[
=head2 jive.net.Networking:getLinkQuality()

returns "quality" of wireless interface
used for dividing SNR values into categorical levels of signal quality

	quality of 1 indicates SNR of 0
	quality of 2 indicates SNR <= 10
	quality of 3 indicates SNR <= 18
	quality of 4 indicates SNR <= 25

=cut
--]]

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

--[[

=head2 jive.net.Networking:getSNR()

returns signal to noise ratio of wireless link

=cut
--]]


function getSNR(self)
	if type(self.interface) ~= 'string' then
		return 0
	end
	local f = io.popen("/sbin/iwpriv " .. self.interface .. " getSNR 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%d+)"))
end

--[[

=head2 jive.net.Networking:getRSSI()

returns Received Signal Strength Indication (signal power) of a wireless interface
=cut
--]]

function getRSSI(self)
	if type(self.interface) ~= 'string' then
		return 0
	end
	local f = io.popen("/sbin/iwpriv " .. self.interface .. " getRSSI 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%-?%d+)"))
end

--[[

=head2 jive.net.Networking:getNF()

returns NF (?) of a wireless interface

=cut
--]]


function getNF(self)
	if type(self.interface) ~= 'string' then
		return 0
	end
	local f = io.popen("/sbin/iwpriv " .. self.interface .. " getNF 1")
	if f == nil then
		return 0
	end

	local t = f:read("*all")
	f:close()

	return tonumber(string.match(t, ":(%-?%d+)"))
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

	if self.wireless then
		log:debug('Open wireless socket')
		self.t_sock, err = wireless:open(self.interface)
		if err then
			log:warn(err)
	
			self:close()
			return false
		end

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

	log:info("REQUEST: ", ...)

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

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
