


-- stuff we use
local assert, error, getmetatable, ipairs, pcall, pairs, require, setmetatable, tonumber, tostring = assert, error, getmetatable, ipairs, pcall, pairs, require, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local string                 = require("string")
local io                     = require("io")
local os                     = require("os")
local math                   = require("math")
local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")

local Applet                 = require("jive.Applet")
local AppletManager          = require("jive.AppletManager")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local Wireless               = require("jive.net.Wireless")

local log                    = require("jive.utils.log").logger("applets.setup")

local SocketUdp              = require("jive.net.SocketUdp")
local socket                 = require("socket")

local udap                   = require("applets.SetupSqueezebox.udap")
local jnt                    = jnt


local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_ACTIVE    = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local setupsqueezeboxTitleStyle = 'settingstitle'
local SETUP_TIMEOUT = 45 -- 45 second timeout for each action
local SETUP_EXTENDED_TIMEOUT = 85 -- 85 second timeout in case Squeezebox is upgrading after first connecting to SC

module(...)
oo.class(_M, Applet)


function init(self)
	self.data1 = {}
	self.data2 = {}
	self.seqno = math.random(65535)

	self.slimdiscovery = AppletManager:getAppletInstance("SlimDiscovery")
	if not self.slimdiscovery then
		error("No slimdiscovery applet")
	end


	self.t_ctrl = Wireless(jnt, "eth0")

	-- socket for udap discovery
	self.socket = assert(SocketUdp(jnt, function(chunk, err)
						    self:t_udapSink(chunk, err)
					    end))
end


-- setup squeezebox
function settingsShow(self, keepOldEntries)
	local window = Window("window", self:string("SQUEEZEBOX_SETUP"), setupsqueezeboxTitleStyle)

	-- window to return to on completion of network settings
	self.topWindow = window

	self.scanMenu = SimpleMenu("menu")
	self.scanMenu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	-- scan now (in network thread)
	self.scanResults = {}

	-- process existing scan results
	-- note we keep old entries so this list the window is not empty
	-- during initial setup. if this becomes a problem a "finding
	-- squeezeboxen" screen will need to be added.
	self:_scanComplete(self.t_ctrl:scanResults(), keepOldEntries)

	window:addListener(EVENT_WINDOW_ACTIVE,
			   function()
				   -- network scan now
				   _setAction(self, t_scanDiscover)
				   _scan(self)
			   end)

	-- schedule network scan 
	self.scanMenu:addTimer(2000, function()
					     _scan(self)
				     end)

	-- find jive network configuration
	jnt:perform(function()
			    self:t_readJiveConfig()
		    end)

	local help = Textarea("help", self:string("SQUEEZEBOX_HELP"))
	window:addWidget(help)
	window:addWidget(self.scanMenu)

	self:tieAndShowWindow(window)
	return window
end


-- bridge jive via a squeezebox
function setupAdhocShow(self, setupNext)
	self.setupNext = setupNext
	self.bridged = true

	local window = settingsShow(self, true)
	window:setAllowScreensaver(false)

	return window
end


-- setup squeezebox
function setupSqueezeboxShow(self, setupNext)
	self.setupNext = setupNext

	local window = settingsShow(self, true)
	window:setAllowScreensaver(false)

	self.scanMenu:addItem({
				      text = self:string("SQUEEZEBOX_PROBLEM_SKIP"),
				      callback = function()
							 setupNext()
						 end,
				      weight = 2
			      })

	return window
end


function _scan(self)
	self.t_ctrl:scan(function(scanTable)
				 _scanComplete(self, scanTable)
			 end)

	self.seqno = self.seqno + 1
	local packet = udap.createDiscover(nil, self.seqno)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


function t_scanDiscover(self, pkt)
	if pkt.uapMethod ~= "discover" then
		return
	end

	if pkt.ucp.type ~= "squeezebox" then
		return
	end

	jnt:t_perform(function()
			      local mac = string.upper(pkt.source)
			      
			      if not self.scanResults[mac] then
				      local item = {
					      text = mac,
					      sound = "WINDOWSHOW",
					      icon = Icon("icon"),
					      callback = function()
								 _selectSqueezebox(self, mac)
							 end,
					      weight = 1
				      }

				      self.scanResults[mac] = {
					      item = item,            -- menu item
					      ether = nil	      -- unknown
				      }

				      self.scanMenu:addItem(item)
			      end

			      -- squeezebox available via udap
			      self.scanResults[mac].udap = true
		      end)
end


function _scanComplete(self, scanTable, keepOldEntries)
	local now = os.time()

	for ssid, entry in pairs(scanTable) do
		local ether,mac = string.match(ssid, "logitech([%-%+])squeezebox[%-%+](%x+)")
		log:warn("ether=", ether, " mac=", mac)

		if mac ~= nil then
			mac = string.upper(mac)

			if not self.scanResults[mac] then
				local item = {
					text = mac,
					sound = "WINDOWSHOW",
					icon = Icon("icon"),
					callback = function()
							   _selectSqueezebox(self, mac)
						   end,
					weight = 1
				}
		      
				self.scanResults[mac] = {
					item = item,            -- menu item
					ether = ether
				}

				self.scanMenu:addItem(item)
			end

			-- squeezebox available via adhoc
			self.scanResults[mac].adhoc = true

			-- remove networks not seen for 10 seconds
			if keepOldEntries ~= true and os.difftime(now, entry.lastScan) > 10 then
				log:warn(mac, " not ssen for 10 seconds")
				self.scanResults[mac].adhoc = nil

				if self.scanResults[mac].udap ~= true then
					self.scanMenu:removeItem(self.scanResults[mac].item)
					self.scanResults[mac] = nil
				end
			end
		end
	end
end


function _selectSqueezebox(self, mac)

	-- prefer setup via wireless
	if self.scanResults[mac].adhoc then
		-- adhoc setup
		_setupInit(self, mac, self.scanResults[mac].ether)
		_setupConfig(self)
	else
		-- udap setup
		_setupInit(self, mac, nil)

		self.interface = ''
		self.ipAddress = ''

		_setAction(self, t_waitSqueezeboxNetwork)
		_setupSqueezebox(self)
	end

	-- remove squeezebox from scan results
	self.scanMenu:removeItem(self.scanResults[self.mac].item)
	self.scanResults[self.mac] = nil
end


-- allow the user to choose between wired or wireless connection
function _wiredOrWireless(self)
	local window = Window("window", self:string("SQUEEZEBOX_NETWORK_CONNECTION"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu", {{
						 text = self:string("SQUEEZEBOX_WIRELESS"),
						 sound = "WINDOWSHOW",
						 callback = function()
								    self.interface = 'wireless'
								    _setupConfig(self)
							    end
					 },
					 {
						 text = self:string("SQUEEZEBOX_ETHERNET"),
						 sound = "WINDOWSHOW",
						 callback = function()
								    self.interface = 'wired'
								    _setupConfig(self)
							    end
					 }
					 --[[
					 -- FIXME just for testing...
					 {
						 text = "Bridged (for testing only)",
						 callback = function()
								    self.interface = 'bridged'
								    _setupConfig(self)
							    end
					 }
					 --]]
				})

	local help = Textarea("help", self:string("SQUEEZEBOX_CONNECT_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


function _parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
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


function _validip(str)
	local ip = _parseip(str)
	if ip == 0x00000000 or ip == 0xFFFFFFFF then
		return false
	else
		return true
	end
end


function _ipAndNetmask(self, address, netmask)
	local ip = _parseip(address or "0.0.0.0")
	local subnet = _parseip(netmask or "255.255.255.0")

	return _ipstring(ip & subnet)
end


function _enterIP(self)
	-- default using jive address
	local address = self:_ipAndNetmask(self.networkOption.address, self.networkOption.netmask)

	local v = Textinput.ipAddressValue(address)

	local window = Window("window", self:string("SQUEEZEBOX_IP_ADDRESS"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	window:addWidget(Textarea("help", self:string("SQUEEZEBOX_IP_ADDRESS_HELP")))
	window:addWidget(Textinput("textinput", v,
				   function(widget, value)
					   value = value:getValue()
					   if not _validip(value) then
						   return false
					   end

					   self.ipAddress = value

					   widget:playSound("WINDOWSHOW")
					   _setupConfig(self)
					   return true
				   end))

	self:tieAndShowWindow(window)
	return window
end


-- initial connection state
function _setupInit(self, mac, ether)
	self.mac = mac or self.mac
	self.ether = ether or self.ether

	if self.bridged then
		self.interface = 'bridged'
	else
		self.interface = nil
	end

	_setAction(self, t_connectJiveAdhoc)
end


-- fill in the Squeezebox configuration, based on the Jive network configuration.
function _setupConfig(self)
	if self.interface == nil then
		if self.ether == '-' then
			-- wireless only
			self.interface = 'wireless'
		else
			return _wiredOrWireless(self)
		end
	end

	if self.networkMethod == 'static' and not self.ipAddress then
		return _enterIP(self)
	end

	if self.interface ~= '' then
		if self.interface  == 'wireless' then
			_wirelessConfig(self)
		elseif self.interface == 'wired' then
			_wiredConfig(self)
		elseif self.interface == 'bridged' then
			_bridgedConfig(self)
		end
		self.interface = ''
	end

	return _setupSqueezebox(self)
end


-- configure Squeezebox for wirless network
function _wirelessConfig(self)

	local statusStr = self.t_ctrl:request("STATUS")
	log:warn("status ", statusStr)

	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end

	assert(status.wpa_state, "COMPLETED")

	local data = self.data1

	-- no slimserver
	data.server_address = udap.packNumber(0, 4)
	data.slimserver_address = udap.packNumber(0, 4) -- none existant server

	data.interface = udap.packNumber(0, 1) -- wireless
	data.bridging = udap.packNumber(0, 1) -- off
	if self.networkMode == 0 then
		data.wireless_mode = udap.packNumber(0, 1) -- infrastructure
	else
		data.wireless_mode = udap.packNumber(1, 1) -- adhoc
	end

	self:_ipConfig(data) -- ip config

	data.SSID = status.ssid

	-- wireless region
	local region = self.t_ctrl:getAtherosRegionCode()
	log:warn("data.region_id=", data.region)
	data.region_id = udap.packNumber(region, 1)

	-- default to encryption disabled
	data.wepon = udap.packNumber(0, 1)
	data.wpa_enabled = udap.packNumber(0, 1)

	if status.key_mgmt == "WPA2-PSK" then
		data.wpa_enabled = udap.packNumber(1, 1)
		data.wpa_mode = udap.packNumber(2, 1)

		data.wpa_psk = _readPSK(self, status.ssid)

	elseif status.key_mgmt == "WPA-PSK" then
		data.wpa_enabled = udap.packNumber(1, 1)
		data.wpa_mode = udap.packNumber(1, 1)

		data.wpa_psk = _readPSK(self, status.ssid)

	end

	-- FIXME including this causes squeezebox to ignore the setdata command?
	if status.pairwise_cipher == "CCMP" then
		data.wpa_cipher = udap.packNumber(2, 1) -- CCMP

	elseif status.pairwise_cipher == "TKIP" then
		data.wpa_cipher = udap.packNumber(1, 1) -- TKIP

	end

	if status.pairwise_cipher == "WEP-104" then
		data.wepon = udap.packNumber(1, 1)
		data.keylen = udap.packNumber(1, 1)
		data.wep_key = _readWepKey(self, status.ssid)

	elseif status.pairwise_cipher == "WEP-40" then	
		data.wepon = udap.packNumber(1, 1)
		data.keylen = udap.packNumber(0, 1)
		data.wep_key = _readWepKey(self, status.ssid)
	end
end


-- parse wpa_supplicant file returning parameters for specific ssid
function _readWpaConfig(self, ssid)
	local conf = assert(io.open("/etc/wpa_supplicant.conf"))

	local param = {}

	-- add quoted syntax for ssid
	ssid = '"' .. ssid .. '"'

	local state = 0
	while true do
		local line = conf:read()
		if not line then
			break
		end

		if line == "network={" then
			state = 1
		elseif line == "}" then
			state = 0
		else
			local k, v = string.match(line, '%s?([^=]+)=(.+)')

			log:warn("k=", k, " v=", v)
			if state == 1 and k == "ssid" and v == ssid then
				state = 2
			end

			if state == 2 then
				param[k] = v
			end
		end
	end

	conf:close()
	return param
end


-- the wpa supplicant won't tell you the keys, we need to parse them from the config file
function _readWepKey(self, ssid)
	local param = _readWpaConfig(self, ssid)
	local key_str = assert(param["wep_key0"])

	log:warn("key_str=", key_str)

	local ascii = string.match(key_str, '^"(.+)"$')
	if ascii then
		-- ascii key
		return ascii
	else
		-- hex key
		local key = {}
		for d in string.gmatch(key_str, "(%x%x)") do
			key[#key + 1] = string.char(tonumber(d, 16))
		end

		return table.concat(key, "")
	end
end


-- the wpa supplicant won't tell you the keys, we need to parse them from the config file
function _readPSK(self, ssid)
	local param = _readWpaConfig(self, ssid)
	local psk = assert(param["psk"])

	-- remove quotes
	psk = string.match(psk, '^"(.*)"$') or psk
	return psk
end


-- configure Squeezebox for wired network
function _wiredConfig(self)
	local data = self.data1

	-- no slimserver
	data.server_address = udap.packNumber(0, 4)
	data.slimserver_address = udap.packNumber(0, 4)

	data.interface = udap.packNumber(1, 1) -- wired
	data.bridging = udap.packNumber(0, 1) -- off

	self:_ipConfig(data) -- ip config
end


-- configure both Squeezebox and Jive for bridged configuration
function _bridgedConfig(self)
	local request, response
	local data = self.data1

	-- generate WEP key
	local key = {}
	local binkey = {}
	for i = 1,13 do
		key[i] = string.format('%02x', math.random(255))
		binkey[i] = string.char(tonumber(key[i], 16))
	end

	-- Jive config:
	local ssid = 'logitech*squeezebox*' .. self.mac
	local option = {
		ibss = true,
		encryption = "none"
-- FIXME enable encryption
--		encryption = "wep104",
--		key = table.concat(key)
	}

	jnt:perform(function()
			   self.networkId = self.t_ctrl:t_addNetwork(ssid, option)
		   end)

	self.networkSSID = ssid
	self.networkMode = 1 -- adhoc
	self.networkMethod = 'dhcp'
	self.networkOption = {}


	-- Squeezebox config:

	-- no slimserver
	data.server_address = udap.packNumber(0, 4)
	data.slimserver_address = udap.packNumber(0, 4)

	data.interface = udap.packNumber(0, 1) -- wireless
	data.bridging = udap.packNumber(1, 1) -- on
	data.wireless_mode = udap.packNumber(1, 1) -- adhoc
--	data.channel = udap.packNumber(6, 1) -- fixed channel

	data.lan_ip_mode = udap.packNumber(1, 1) -- 1 dhcp

	data.SSID = ssid

	-- wireless region
	local region = self.t_ctrl:getAtherosRegionCode()
	log:warn("data.region_id=", data.region)
	data.region_id = udap.packNumber(region, 1)

	-- secure network
	data.wpa_enabled = udap.packNumber(0, 1)
	data.wepon = udap.packNumber(0, 1)

-- FIXME enable encryption
--	data.wpa_enabled = udap.packNumber(0, 1)
--	data.wepon = udap.packNumber(1, 1)
--	data.keylen = udap.packNumber(1, 1)
--	data.wep_key = table.concat(binkey)
end


function _ipConfig(self, data)
	if self.networkMethod == 'static' then
		log:warn("ipAddress=", self.ipAddress)
		log:warn("netmask=", self.networkOption.netmask)
		log:warn("gateway=", self.networkOption.gateway)
		log:warn("dns=", self.networkOption.dns)

		data.lan_ip_mode = udap.packNumber(0, 1) -- 0 static ip
		data.lan_network_address = udap.packNumber(_parseip(self.ipAddress), 4)
		data.lan_subnet_mask = udap.packNumber(_parseip(self.networkOption.netmask), 4)
		data.lan_gateway = udap.packNumber(_parseip(self.networkOption.gateway), 4)
		data.primary_dns = udap.packNumber(_parseip(self.networkOption.dns), 4)
	else
		data.lan_ip_mode = udap.packNumber(1, 1) -- 1 dhcp
	end
end


-- reads the existing network configuraton on Jive, including ssid,
-- network id, dhcp/static ip information.
function t_readJiveConfig(self)
	-- read the existing network configuration
	local statusStr = self.t_ctrl:request("STATUS-VERBOSE")
	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end


	self.networkId = status.id
	self.networkSSID = status.ssid
	self.networkMode = 0 -- infrastructure
	self.networkMethod = nil
	self.networkOption = {}


	-- note if we are going to use the bridged mode id and ssid
	-- will be nil here
	if not status.ssid then
		return
	end


	-- infrastructure or ad-hoc?
	local mode = self.t_ctrl:request("GET_NETWORK " .. status.id .. " mode")
	log:warn("mode=", mode)
	self.networkMode = tonumber(mode) or 0


	-- read dhcp/static from interfaces file
	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
	local ssid = string.gsub(self.networkSSID, "[ \t]", "_")
	log:warn("munged ssid=", ssid)

	local fh = assert(io.open("/etc/network/interfaces", "r+"))

	local network, method = ""
	for line in fh:lines() do
		if string.match(line, "^mapping%s") or string.match(line, "^auto%s") then
			network = ""
		elseif string.match(line, "^iface%s") then
			network, method  = string.match(line, "^iface%s([^%s]+)%s+%a+%s+(%a+)")

			if network == ssid then
				self.networkMethod = method
			end
		else
			if network == ssid then
				local option, value = string.match(line, "%s*(%a+)%s+(.+)")
				log:warn("option=", option, " value=", value)

				self.networkOption[option] = value
			end
		end
	end

	log:warn("network_id=", self.networkId)
	log:warn("network_ssid=", self.networkSSID)
	log:warn("network_method=", self.networkMethod)

	fh:close()
end


-- disconnect from all slimservers
function t_disconnectSlimserver(self)
	log:warn("t_disconnectSlimserver")

	-- we must have a network connection now, either to an
	-- access point or bridged.
	assert(self.networkId, "jive not connected to network")

	-- disconnect to slimserver
	self.slimdiscovery.serversObj:disconnect()

	_setAction(self, t_waitDisconnectSlimserver)
end


-- wait until we have disconnected from all slimservers
function t_waitDisconnectSlimserver(self)
	log:warn("t_waitDisconnectSlimserver")

	local connected = false

	for i,server in self.slimdiscovery:allServers() do
		connected = connected or server:isConnected()
		log:warn("server=", server:getName(), " connected=", connected)
	end		

	if not connected then
		_setAction(self, t_connectJiveAdhoc)
	end
end


-- connects jive to the squeezebox adhoc network. we also capture the existing
-- network id for later.
function t_connectJiveAdhoc(self)
	log:warn("connectSqueezebox")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_CONNECTION"

	local request, response, id

	-- connect to squeezebox ah-hoc network
	local ssid = 'logitech' .. self.ether .. 'squeezebox' .. self.ether .. self.mac
	local option = {
		ibss = true,
		encryption = "none"
	}

	local id = self.t_ctrl:t_addNetwork(ssid, option)

	self.adhoc_ssid = ssid
	_setAction(self, t_waitJiveAdhoc)
end


-- polls jive network status, waiting until we have connected to the ad-hoc network.
function t_waitJiveAdhoc(self)
	log:warn("waitSqueezebox")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_CONNECTION"

	local status = self.t_ctrl:t_wpaStatusRequest("STATUS")

	if status.wpa_state ~= "COMPLETED" or not status.ip_address then
		return
	end

	-- we're connected
	log:warn("completed")
	_setAction(self, t_udapDiscover)
end


-- discover the Squeezebox over udap. this makes sure that the Squeezebox exists.
function t_udapDiscover(self)
	log:warn("udapDiscover")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	-- check squeezebox exists via udap
	self.seqno = self.seqno + 1
	local packet = udap.createDiscover(self.mac, self.seqno)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


-- set Squeezebox configuration over udap. this configures the wired or wireless
-- network settings, and the dhcp or static ip settings. we don't configure the
-- slimserver yet.
function t_udapSetData(self)
	log:warn("udapSetData")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	for k,v in pairs(self.data1) do
		local hex = ""
		for i = 1,#v do
			hex = hex .. string.format("%02x", string.byte(string.sub(v, i, i)))
		end

		log:warn("\tk=", k, " v=", hex)
	end

	-- configure squeezebox network
	self.seqno = self.seqno + 1
	local packet = udap.createSetData(self.mac, self.seqno, self.data1)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


-- reset Squeezebox over udap
function t_udapReset(self)
	log:warn("udapReset")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	-- reset squeezebox
	self.seqno = self.seqno + 1
	local packet = udap.createReset(self.mac, self.seqno)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)

	-- if the reset udp reply is lost we won't know the squeezebox has reset ok
	-- let's assume that after ten requests it must have reset, if we haven't
	-- by now we are probably about to fail anyway
	if self._timeout >= 10 then
		log:warn("missing reset response, assuming squeezebox has rebooted")
		_setAction(self, t_scanNetwork)
	end
end

-- Get Squeezebox IP address
function t_udapGetIPAddr(self)
	log:warn("udapGetIPAddr")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	self.seqno = self.seqno + 1
	local packet = udap.createGetIPAddr(self.mac, self.seqno)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


-- sink for udap replies. based on the replies this sets up the next action to call.
function t_udapSink(self, chunk, err)
	log:warn("udapSink chunk=", chunk, " err=", err)

	if chunk == nil then
		-- ignore errors, and try again
		return
	end

	local pkt = udap.parseUdap(chunk.data)
	log:warn("seqno=", self.seqno, " pkt=", udap.tostringUdap(pkt))

	if self.seqno ~= pkt.seqno then
		log:warn("discarding old packet")
		return
	end

	if pkt.uapMethod == "discover" then
		if self._action == t_scanDiscover then
			t_scanDiscover(self, pkt)
		elseif self._action == t_udapDiscover then
			_setAction(self, t_udapSetData)
		end

	elseif pkt.uapMethod == "set_data" then
		if self._action == t_udapSetData then
			_setAction(self, t_udapReset)
		elseif self._action == t_udapSetSlimserver then
			_setAction(self, t_waitSlimserver)
		else
			error("unexpected state " .. tostring(self._action))
		end

	elseif pkt.uapMethod == "reset" then
		assert(self._action == t_udapReset)
		_setAction(self, t_scanNetwork)

	elseif pkt.uapMethod == "adv_discover" then
		assert(self._action == t_waitSqueezeboxNetwork)
		if pkt.ucp.device_status == "wait_wireless" then
			-- we won't see this, the Squeezebox network is not up yet

		elseif pkt.ucp.device_status == "wait_dhcp" then
			self.errorMsg = "SQUEEZEBOX_PROBLEM_DHCP_ERROR"

		elseif pkt.ucp.device_status == "wait_slimserver" then
			_setAction(self, t_udapGetIPAddr)

		elseif pkt.ucp.device_status == "connected" then
			-- we should not get this far yet
			error("squeezebox connected to slimserver")

		end

	-- Get Squeezebox IP address to be shown to user
	elseif pkt.uapMethod == "get_ip" then
			_setAction(self, nil)

			local ip_addr_str = ""
			local v = pkt.ucp["ip_addr"]
			for i = 1,#v do
				ip_addr_str = ip_addr_str .. string.format("%d", string.byte(string.sub(v, i, i)))
				if i < #v then
					ip_addr_str = ip_addr_str .. "."
				end
			end
			-- Save Squeezebox IP address to be shown in next screen
			self.squeezeboxIPAddr = ip_addr_str

			jnt:t_perform(function()
					      _chooseSlimserver(self)
				      end)

	end
end


-- wait until the network is available. this is needed in the bridged case, as
-- we need to wait for Ray to create the network first.
function t_scanNetwork(self)
	if not self.bridged then
		-- skip this step if we are not bridged
		_setAction(self, t_connectJiveNetwork)
		return
	end

	log:warn("scanNetwork network=", self.networkSSID)

	local scan = self.t_ctrl:scanResults()
	debug.dump(scan, 2)

	if scan[self.networkSSID] then
		_setAction(self, t_connectJiveNetwork)
	else
		self.t_ctrl:scan()
	end
end


-- reconnect Jive to it's network. we also remove the ad-hoc network from the
-- wpa-supplicant configuration.
function t_connectJiveNetwork(self)
	log:warn("connectJiveNetwork adhoc_ssid=", self.adhoc_ssid)

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_NETWORK"

	if self.adhoc_ssid then
		self.t_ctrl:t_removeNetwork(self.adhoc_ssid)
		self.adhoc_ssid = nil
	end

	self.t_ctrl:t_selectNetwork(self.networkSSID)
	_setAction(self, t_waitJiveNetwork)
end


-- polls jives network status, waiting until we have connected to the network again.
function t_waitJiveNetwork(self)
	log:warn("waitJiveNetwork")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_NETWORK"

	local status = self.t_ctrl:t_wpaStatusRequest()
	if status.wpa_state == "COMPLETED" and status.ip_address then
		if self.networkMethod == 'dhcp' and string.match(status.ip_address, "^169.254.") then
			-- waiting for dhcp
			return
		end

		-- reconnect to slimserver
		self.slimdiscovery.serversObj:connect()

		_setAction(self, t_waitSqueezeboxNetwork)
	end
end


-- check for Squeezebox status over udap. we use the advanced status request, this
-- replies with a status string so we know when the Squeezebox is ready to connect
-- to slimserver.
function t_waitSqueezeboxNetwork(self)
	log:warn("waitSqueezeboxNetwork")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_CONNECTION_ERROR"

	-- check squeezebox status via udap
	self.seqno = self.seqno + 1
	local packet = udap.createAdvancedDiscover(self.mac, self.seqno)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


-- menu allowing the user to choose the slimserver they want to connect to
function _chooseSlimserver(self)
	local window = Window("window", self:string("SQUEEZEBOX_MUSIC_SOURCE"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	local help = Textarea("help", self:string("SQUEEZEBOX_MUSIC_SOURCE_HELP", self.squeezeboxIPAddr))

	window:addWidget(help)
	window:addWidget(menu)

	self.slimserverMenu = menu
	self.slimservers = {}

	-- scan slimservers now
	_scanSlimservers(self)

	-- schedule slimserver scan 
	menu:addTimer(1000, function()
				    _scanSlimservers(self)
			    end)

	window:show()

	if self.slimserverMenu:numItems() == 0 then
		local popup = Popup("popupIcon")

		popup:addWidget(Icon("iconConnecting"))
		popup:addWidget(Label("text", self:string("SQUEEZEBOX_FINDING_SOURCES")))

		-- schedule slimserver scan 
		popup:addTimer(1000, function() _scanSlimservers(self) end)

		-- close after 5 seconds
		popup:addTimer(5000, function() popup:hide() end)

		self:tieAndShowWindow(popup)
	end
end


-- poll for slimservers and populate the slimserver menu.
function _scanSlimservers(self)
	-- scan for slimservers
	log:warn("in _scanSlimservers calling discover")
	self.slimdiscovery:discover()

	-- update slimserver list
	for i,v in self.slimdiscovery:allServers() do
		if self.slimservers[i] == nil then
			local item = {
				text = v:getName(),
				callback = function()
						   _setSlimserver(self, v)
					   end
			}

			self.slimservers[i] = item
			self.slimserverMenu:addItem(item)
		end
	end
end


function parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
end


-- user has selected a slimserver. open the connecting popup again, and send
-- the slimserver configuration to Squeezebox over udap.
function _setSlimserver(self, slimserver)
	local serverip, port = slimserver:getIpPort()

	self.slimserver = slimserver:getName()
	self.data2.server_address = udap.packNumber(0, 4)
	self.data2.slimserver_address = udap.packNumber(parseip(serverip), 4)

	log:warn("slimserver_address=", serverip)

	_setAction(self, t_udapSetSlimserver)
	_setupSqueezebox(self)
end


-- send the slimserver configuration to Squeezebox using udap. this action
-- repeats until notify_playerNew or notify_playerConnected indicate that
-- the player is successfully connected to slimserver.
function t_udapSetSlimserver(self)
	log:warn("t_connectSqueezeboxSlimserver")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	-- configure squeezebox network
	self.seqno = self.seqno + 1
	local packet = udap.createSetData(self.mac, self.seqno, self.data2)
	self.socket:send(function() return packet end, "255.255.255.255", udap.port)
end


function t_waitSlimserver(self)
	log:warn("t_waitSlimserver")
	-- do nothing, notify_playerNew will be called
end


-- this is called by jnt when the playerNew message is sent
function notify_playerNew(self, player)
	local playerId = string.gsub(player:getId(), ":", "")

	log:warn("got new playerId ", playerId)
	if string.lower(playerId) == string.lower(self.mac) then
		-- player is connected to slimserver, set as current player
		self.slimdiscovery:setCurrentPlayer(player)

		-- and then we're done
		_setupOK(self)
	end
end


-- this is called by jnt when the playerConnected message is sent
function notify_playerConnected(self, player)
	-- use same action as new player
	notify_playerNew(self, player)
end


function _setAction(self, action)
	self._action = action
	self._timeout = 1
end


-- call the next action require to setup the Squeezebox, we do this in the network
-- thread.
function _nextAction(self)
	if self._action == nil then
		return
	end

	local totalTimeout = SETUP_TIMEOUT
	-- Extend timeout when waiting on Squeezebox to connect to SlimServer since SB might upgrade
	if self._action == t_waitSlimserver then
		totalTimeout = SETUP_EXTENDED_TIMEOUT
	end

	self._timeout = self._timeout + 1

	if self._timeout == totalTimeout then

		-- restore our network connection
		jnt:perform(function()
				    t_connectJiveNetwork(self)
			    end)

		-- display error
		_setupFailed(self)
		return
	end

	jnt:perform(function()
			    if self._action == nil then
				    return
			    end

			    local ok, err = pcall(self._action, self)
			    if not ok then
				    log:warn(err)

				    -- restore our network connection
				    t_connectJiveNetwork(self)

				    jnt:t_perform(function()
							  _setupFailed(self)
						  end)

			    end
		    end)
end


-- display the connecting popup
-- when this popup is displayed the _nextAction() function walks through the actions
-- required to setup the Squeezebox.
function _setupSqueezebox(self)
	_nextAction(self)

	local help
	if self._action == t_udapSetSlimserver then
		help = self:string("SQUEEZEBOX_CONNECTING_TO", tostring(self.slimserver))
	elseif self._action == t_waitSqueezeboxNetwork then
		-- displayed when setting squeezebox follow udap discovery
		-- e.g. when squeezebox is discovered with blue led
		help = self:string("SQUEEZEBOX_FINDING_SOURCES")
	else
		if self.data1.SSID then
			help = self:string("SQUEEZEBOX_CONNECTING_TO", self.data1.SSID)
		else
			help = self:string("SQUEEZEBOX_CONNECTING_TO", tostring(self:string("SQUEEZEBOX_ETHERNET")))
		end
	end

	local window = Popup("popupIcon")

	window:addWidget(Icon("iconConnecting"))
	window:addWidget(Label("text", help))
	window:addTimer(1000,
			function()
				_nextAction(self)
			end)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   return EVENT_CONSUME
			   end)

	-- subscribe to the jnt so that we get notifications of players added
	window:addListener(EVENT_WINDOW_ACTIVE,
			   function(event)
				   jnt:subscribe(self)
			   end)

	window:addListener(EVENT_WINDOW_INACTIVE,
			   function(event)
				   jnt:unsubscribe(self)
			   end)

	self:tieAndShowWindow(window)
end


-- Squeezebox setup completed
function _setupOK(self)
	local window = Popup("popupIcon")
	window:setAllowScreensaver(false)

	window:addWidget(Icon("iconConnected"))

	local text = Label("text", self:string("SQUEEZEBOX_SETUP_COMPLETE"))
	window:addWidget(text)

	window:addTimer(2000,
			function(event)
				self:_setupDone()
			end)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   self:_setupDone()
				   return EVENT_CONSUME
			   end)


	window:show()
end


-- Squeezebox setup failed
function _setupFailed(self)
	local window = Window("wireless", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("SQUEEZEBOX_PROBLEM_TRY_AGAIN"),
						sound = "WINDOWHIDE",
						callback = function()
								   _setupInit(self)
								   self:_hideToTop()
							   end
					},
					{
						text = self:string("SQUEEZEBOX_PROBLEM_SKIP"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_setupDone()
							   end
					},
				})


	helpText = self:string("SQUEEZEBOX_PROBLEM_HELP")
	if self.errorMsg then
		helpText = tostring(helpText) .. tostring(self:string(self.errorMsg))
	end

	local help = Textarea("help", helpText)

	window:addWidget(help)
	window:addWidget(menu)

	window:show()
end


function _setupDone(self)
	if self.setupNext then
		log:warn("calling setupNext=", self.setupNext)
		return self.setupNext()
	end

	log:warn("hideToTop window=", self.topWindow)
	self.topWindow:hideToTop(Window.transitionPushLeft)
end


function _hideToTop(self, dontSetupNext)
	if Framework.windowStack[1] == self.topWindow then
		return
	end

	while #Framework.windowStack > 2 and Framework.windowStack[2] ~= self.topWindow do
		log:warn("hiding=", Framework.windowStack[2], " topWindow=", self.topWindow)
		Framework.windowStack[2]:hide(Window.transitionPushLeft)
	end

	Framework.windowStack[1]:hide(Window.transitionPushLeft)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
