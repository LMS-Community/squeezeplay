


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
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local Player                 = require("jive.slim.Player")
local LocalPlayer            = require("jive.slim.LocalPlayer")

local Udap                   = require("jive.net.Udap")
local hasNetworking, Networking  = pcall(require, "jive.net.Networking")

local jnt                    = jnt
local appletManager          = appletManager
local socket                 = require("socket")

local setupsqueezeboxTitleStyle = 'settingstitle'
local SETUP_TIMEOUT = 45 -- 45 second timeout for each action
local SETUP_EXTENDED_TIMEOUT = 180  -- 180 second timeout in case Squeezebox is upgrading after first connecting to SC
local _updatingPlayerPopup = false

module(..., Framework.constants)
oo.class(_M, Applet)


-- XXXX
--
-- This applet used to setup the Squeezebox network and also connect it to an available server. The flow has
-- changed, so this now only sets the Squeezebox up on the network. BUT the old code has not yet been removed.



-- _updatingPlayer
-- full screen popup that appears while player is getting fw update
local function _updatingPlayer(self)
	log:info("_updating popup show")

	if _updatingPlayerPopup then
		-- don't open this popup twice
		return
	end

	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	local label = Label("text", self:string('SQUEEZEBOX_UPDATING_FIRMWARE_SQUEEZEBOX'))
	popup:addWidget(icon)
	popup:addWidget(label)
	popup:setAlwaysOnTop(true)

	local disconnectPlayerAction = function (self, event) 
		appletManager:callService("setCurrentPlayer", nil)
		popup:hide()
	end

	-- add a listener for back that disconnects from the player and returns to home
	popup:addActionListener("back", self, disconnectPlayerAction)
	
	popup:show()

	_updatingPlayerPopup = popup
end

-- _hidePlayerUpdating
-- hide the full screen popup that appears until player is updated
local function _hidePlayerUpdating()
	if _updatingPlayerPopup then
		log:info("_updatingPlayer popup hide")
		_updatingPlayerPopup:hide()
		_updatingPlayerPopup = false
	end
end

function init(self)
	self.data1 = {}
	self.data2 = {}
	self.seqno = math.random(65535)
	self.lastActionTicks = Framework:getTicks()

	if not appletManager:hasService("discoverPlayers") then
		error("No player discovery")
	end

	if hasNetworking then
		self.wireless = Networking:wirelessInterface(jnt)
	end

	-- socket for udap discovery
	self.udap = Udap(jnt)
	self.udapSink = self.udap:addSink(function(chunk, err)
						  self:t_udapSink(chunk, err)
					  end)
end


function free(self)
	-- Make sure we are unsubscribed
	jnt:unsubscribe(self)

	self.udap:removeSink(self.udapSink)
	return true
end


-- setup squeezebox
function setupSqueezeboxSettingsShow(self, setupNext)
	self.setupNext = setupNext

	local window = Window("text_list", self:string("SQUEEZEBOX_SETUP"), setupsqueezeboxTitleStyle)

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
	if self.wireless then
		self:_scanComplete(self.wireless:scanResults(), true)
	end

	window:addListener(EVENT_WINDOW_ACTIVE,
			   function()
				   -- network scan now
				   _scan(self)
			   end)

	-- schedule network scan 
	self.scanMenu:addTimer(10000, function()
					     -- only scan if this window is on top, not under a transparent popup
					     if Framework.windowStack[1] ~= window then
						     return
					     end
					     _scan(self)
				     end)

	local help = Textarea("help_text", self:string("SQUEEZEBOX_HELP"))
	self.scanMenu:setHeaderWidget(help)
	window:addWidget(self.scanMenu)

	self:tieAndShowWindow(window)
	return window
end


-- bridge jive via a squeezebox
function setupAdhocShow(self, setupNext)
	self.bridged = true

	local window = setupSqueezeboxSettingsShow(self, setupNext)
	window:setAllowScreensaver(false)

	return window
end


-- setup squeezebox
function setupSqueezeboxShow(self, setupNext)
	local window = setupSqueezeboxSettingsShow(self, setupNext)
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
	if self.wireless then
		self.wireless:scan(function(scanTable)
					   _scanComplete(self, scanTable)
				   end)
	end

	self.seqno = self.seqno + 1
	local packet = Udap.createAdvancedDiscover(nil, self.seqno)
	self.udap:send(function() return packet end, "255.255.255.255")
end


function t_scanDiscover(self, pkt)
	if not self.scanResults then
		-- we are not scanning
		return
	end

	if pkt.uapMethod ~= "adv_discover"
		or pkt.ucp.device_status ~= "wait_slimserver"
		or pkt.ucp.type ~= "squeezebox" then
		return
	end
	
	local mac = string.lower(pkt.source)
			      
	if not self.scanResults[mac] then
		local item = {
			text = self:string("SQUEEZEBOX_BRIDGED_NAME", string.sub(mac, 7)),
			sound = "WINDOWSHOW",
			icon = Icon("icon"),
			callback = function()
					   startSqueezeboxSetup(self, mac)
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
end


function _scanComplete(self, scanTable, keepOldEntries)
	local now = Framework:getTicks()

	local seen = {}

	for ssid, entry in pairs(scanTable) do
		local mac, ether = Player:ssidIsSqueezebox(ssid)
		log:debug("ether=", ether, " mac=", mac)

		if mac ~= nil then
			seen[mac] = true

			if not self.scanResults[mac] then
				local item = {
					text = self:string("SQUEEZEBOX_BRIDGED_NAME", string.sub(mac, 10)),
					sound = "WINDOWSHOW",
					icon = Icon("icon"),
					callback = function()
							   startSqueezeboxSetup(self, mac, ssid)
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
		end
	end

	-- remove old networks
	for mac, entry in pairs(self.scanResults) do
		if not seen[mac] and not keepOldEntries then
			entry.adhoc = nil

			if entry.udap ~= true then
				self.scanMenu:removeItem(entry.item)
				self.scanResults[mac] = nil
			end
		end
	end
end


--[[
This function is the entry point after a squeezebox has been choosen
for setup, may be called from outside this applet.

I<mac> is the mac address of the squeezebox
I<adhoc> is the ad-hoc ssid for setup, or nil if already on the network
I<setupNext> if given, is a function to call once setup is complete

--]]
function startSqueezeboxSetup(self, mac, adhoc, setupNext)
	log:info("startSqueezeboxSetup()")

	mac = string.gsub(mac, ":", "")

	if setupNext then
		self.setupNext = setupNext
	end

	if not self.topWindow then
		-- remember the top window
		self.topWindow = Framework.windowStack[1]
	end

	-- disconnect from current player, if any. after a successful setup
	-- we will be connected to mac
	appletManager:callService("setCurrentPlayer", nil)

	if adhoc then
		-- full configuration via adhoc network
		local _, hasEthernet = Player:ssidIsSqueezebox(adhoc)

		-- find jive network configuration
		Task("readConfig", self,
		     function(self)
			     -- read jive network config
			     _readJiveConfig(self)

			     -- complete setup data
			     _setupInit(self, mac, hasEthernet)
			     _setupConfig(self)
		     end):addTask()

	else
		-- SqueezeCenter configuration with udap
		_setupInit(self, mac, nil)

		self.interface = ''
		self.ipAddress = ''

		_setAction(self, "t_waitSqueezeboxNetwork", "find_slimserver")
		_setupSqueezebox(self)
	end
end


-- allow the user to choose between wired or wireless connection
function _wiredOrWireless(self)
	local window = Window("text_list", self:string("SQUEEZEBOX_NETWORK_CONNECTION"), setupsqueezeboxTitleStyle)
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

	local help = Textarea("help_text", self:string("SQUEEZEBOX_CONNECT_HELP"))
	menu:setHeaderWidget(help)
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

	local window = Window("text_list", self:string("SQUEEZEBOX_IP_ADDRESS"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	window:addWidget(Textarea("help_text", self:string("SQUEEZEBOX_IP_ADDRESS_HELP")))
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

	-- remove squeezebox from scan results
	if self.scanResults and self.scanResults[mac] then
		self.scanMenu:removeItem(self.scanResults[mac].item)
		self.scanResults[mac] = nil
	end

	-- task for performing setup
	if self.actionTask then
		self.actionTask:removeTask()
	end
	self.actionTask = Task("setupSqueezebox", self, t_nextAction, _setupFailed)
	self.statusText = ""

	log:info("_setupInit mac=", mac, " ether=", ether)
end


-- prompt the user to comple the Squeezebox configuration, based on
-- the information needed for the Jive network configuration.
function _setupConfig(self)
	log:info("_setupConfig interface=", self.interface, " ipaddr=", self.networkMethod)

	if self.bridged then
		self.interface = 'bridged'

	elseif self.interface == nil then
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

	-- network name
	if self.interface  == 'wireless' then
		self.networkName = self.networkSSID
	elseif self.interface == 'wired' then
		self.networkName = tostring(self:string("SQUEEZEBOX_ETHERNET"))
	elseif self.interface == 'bridged' then
		self.networkName = self:string("SQUEEZEBOX_BRIDGED_NAME", string.sub(self.mac, 7))
	end

	-- begin setup
	_setAction(self, "t_setupBegin", "connect_network")
	self.actionTask:addTask()

	-- start spinny
	_setupSqueezebox(self)
end


-- initial task in the thread, configure the network data needed
function t_setupBegin(self)
	log:info("t_setupBegin interface=", self.interface)

	if self.interface  == 'wireless' then
		t_wirelessConfig(self)
	elseif self.interface == 'wired' then
		t_wiredConfig(self)
	elseif self.interface == 'bridged' then
		t_bridgedConfig(self)
	end

	_setAction(self, "t_disconnectSlimserver")
end


-- configure Squeezebox for wirless network
function t_wirelessConfig(self)

	local statusStr = self.wireless:request("STATUS")
	log:info("status ", statusStr)

	local status = {}
	for k,v in string.gmatch(statusStr, "([^=]+)=([^\n]+)\n") do
		status[k] = v
	end

	assert(status.wpa_state, "COMPLETED")

	local data = self.data1

	-- no slimserver
	data.server_address = Udap.packNumber(0, 4)
	data.slimserver_address = Udap.packNumber(0, 4) -- none existant server

	data.interface = Udap.packNumber(0, 1) -- wireless
	data.bridging = Udap.packNumber(0, 1) -- off
	if self.networkMode == 0 then
		data.wireless_mode = Udap.packNumber(0, 1) -- infrastructure
	else
		data.wireless_mode = Udap.packNumber(1, 1) -- adhoc
	end

	self:_ipConfig(data) -- ip config

	data.SSID = status.ssid

	-- wireless region
	local region = self.wireless:getAtherosRegionCode()
	log:info("data.region_id=", data.region)
	data.region_id = Udap.packNumber(region, 1)

	-- default to encryption disabled
	data.wepon = Udap.packNumber(0, 1)
	data.wpa_enabled = Udap.packNumber(0, 1)

	if status.key_mgmt == "WPA2-PSK" then
		data.wpa_enabled = Udap.packNumber(1, 1)
		data.wpa_mode = Udap.packNumber(2, 1)

		data.wpa_psk = _readPSK(self, status.ssid)

	elseif status.key_mgmt == "WPA-PSK" then
		data.wpa_enabled = Udap.packNumber(1, 1)
		data.wpa_mode = Udap.packNumber(1, 1)

		data.wpa_psk = _readPSK(self, status.ssid)

	end

	if status.pairwise_cipher == "CCMP" then
		data.wpa_cipher = Udap.packNumber(2, 1) -- CCMP

	elseif status.pairwise_cipher == "TKIP" then
		data.wpa_cipher = Udap.packNumber(1, 1) -- TKIP

	end

	if status.pairwise_cipher == "WEP-104" then
		data.wepon = Udap.packNumber(1, 1)
		data.keylen = Udap.packNumber(1, 1)
		data.wep_key = _readWepKey(self, status.ssid)

	elseif status.pairwise_cipher == "WEP-40" then	
		data.wepon = Udap.packNumber(1, 1)
		data.keylen = Udap.packNumber(0, 1)
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

			log:debug("k=", k, " v=", v)
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
function t_wiredConfig(self)
	local data = self.data1

	-- no slimserver
	data.server_address = Udap.packNumber(0, 4)
	data.slimserver_address = Udap.packNumber(0, 4)

	data.interface = Udap.packNumber(1, 1) -- wired
	data.bridging = Udap.packNumber(0, 1) -- off

	self:_ipConfig(data) -- ip config
end


-- configure both Squeezebox and Jive for bridged configuration
function t_bridgedConfig(self)
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
		encryption = "wep104",
		key = table.concat(key)
	}

	self.networkId = self.wireless:t_addNetwork(ssid, option)

	self.networkSSID = ssid
	self.networkMode = 1 -- adhoc
	self.networkMethod = 'dhcp'
	self.networkOption = {}


	-- Squeezebox config:

	-- no slimserver
	data.server_address = Udap.packNumber(0, 4)
	data.slimserver_address = Udap.packNumber(0, 4)

	data.interface = Udap.packNumber(0, 1) -- wireless
	data.bridging = Udap.packNumber(1, 1) -- on
	data.wireless_mode = Udap.packNumber(1, 1) -- adhoc
--	data.channel = Udap.packNumber(6, 1) -- fixed channel

	data.lan_ip_mode = Udap.packNumber(1, 1) -- 1 dhcp

	data.SSID = ssid

	-- wireless region
	local region = self.wireless:getAtherosRegionCode()
	log:info("data.region_id=", data.region)
	data.region_id = Udap.packNumber(region, 1)

	-- secure network
	data.wpa_enabled = Udap.packNumber(0, 1)
	data.wepon = Udap.packNumber(1, 1)
	data.keylen = Udap.packNumber(1, 1)
	data.wep_key = table.concat(binkey)
end


function _ipConfig(self, data)
	if self.networkMethod == 'static' then
		log:info("ipAddress=", self.ipAddress)
		log:info("netmask=", self.networkOption.netmask)
		log:info("gateway=", self.networkOption.gateway)
		log:info("dns=", self.networkOption.dns)

		data.lan_ip_mode = Udap.packNumber(0, 1) -- 0 static ip
		data.lan_network_address = Udap.packNumber(_parseip(self.ipAddress), 4)
		data.lan_subnet_mask = Udap.packNumber(_parseip(self.networkOption.netmask), 4)
		data.lan_gateway = Udap.packNumber(_parseip(self.networkOption.gateway), 4)
		data.primary_dns = Udap.packNumber(_parseip(self.networkOption.dns), 4)
	else
		data.lan_ip_mode = Udap.packNumber(1, 1) -- 1 dhcp or auto ip
	end
end


-- reads the existing network configuraton on Jive, including ssid,
-- network id, dhcp/static ip information.
function _readJiveConfig(self)
	-- read the existing network configuration
	local statusStr = self.wireless:request("STATUS-VERBOSE")
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
	local mode = self.wireless:request("GET_NETWORK " .. status.id .. " mode")
	log:info("mode=", mode)
	self.networkMode = tonumber(mode) or 0


	-- read dhcp/static from interfaces file
	-- the interfaces file uses " \t" as word breaks so munge the ssid
	-- FIXME ssid's with \n are not supported
	local ssid = string.gsub(self.networkSSID, "[ \t]", "_")
	log:info("munged ssid=", ssid)

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
				log:info("option=", option, " value=", value)

				self.networkOption[option] = value
			end
		end
	end

	-- use audo-ip?
	if self.networkMethod == 'dhcp' and string.match(status.ip_address, "^169.254.") then
		self.networkMethod = 'autoip' 
	end

	log:info("network_id=", self.networkId)
	log:info("network_ssid=", self.networkSSID)
	log:info("network_method=", self.networkMethod)

	fh:close()
end


-- disconnect from all slimservers
function t_disconnectSlimserver(self)
	log:debug("t_disconnectSlimserver")

	-- we must have a network connection now, either to an
	-- access point or bridged.
	assert(self.networkId, "jive not connected to network")

	-- disconnect from Player/SqueezeCenter
	LocalPlayer:disconnectServerAndPreserveLocalPlayer()

--	_setAction(self, "t_waitDisconnectSlimserver")
	-- FIXME: Waiting (i.e. next step) never succeeds if a local SC is present
	--  as some other functionality (SlimMenus?) reconnects immediately
	-- Skipping the wait step for now
	_setAction(self, "t_connectJiveAdhoc")
end


-- wait until we have disconnected from all slimservers
function t_waitDisconnectSlimserver(self)
	log:debug("t_waitDisconnectSlimserver")

	local connected = false

	for i,server in appletManager:callService("iterateSqueezeCenters") do
		if server:isSqueezeNetwork() then
			log:info("excluding SN")
		else
			connected = connected or server:isConnected()
			log:info("server=", server:getName(), " connected=", connected)
		end
	end		

	if not connected then
		_setAction(self, "t_connectJiveAdhoc")
	end
end


-- connects jive to the squeezebox adhoc network. we also capture the existing
-- network id for later.
function t_connectJiveAdhoc(self)
	log:debug("connectSqueezebox")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_CONNECTION"

	local request, response, id

	-- connect to squeezebox ah-hoc network
	-- Note we must use upper case mac addresses in the ad-hoc ssid
	local ssid = 'logitech' .. self.ether .. 'squeezebox' .. self.ether .. string.upper(self.mac)
	local option = {
		ibss = true,
		encryption = "none"
	}

	-- disconnect from existing network
	self.wireless:t_disconnectNetwork()

	-- configure ad-hoc network
	local id = self.wireless:t_addNetwork(ssid, option)

	-- We need a valid IP address to be able to send out UDAP commands, but since
	--  Squeezebox doesn't have an IP address yet it doesn't really matter what
	--  our IP address is.
	-- Using a static IP address (instead of DHCP) here makes the process about
	--  20 seconds shorter as we do not have to wait for a self-assigned IP
	self.wireless:t_setStaticIP(ssid, "192.168.144.120", "255.255.255.0", "192.168.144.1", "192.168.144.1")

	-- select new network
	self.wireless:t_selectNetwork(ssid)

	self.adhoc_ssid = ssid

	_setAction(self, "t_waitJiveAdhoc")
end


-- polls jive network status, waiting until we have connected to the ad-hoc network.
function t_waitJiveAdhoc(self)
	log:debug("waitSqueezebox")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_CONNECTION"

	local status = self.wireless:t_wpaStatus("STATUS")

	if status.wpa_state ~= "COMPLETED" or not status.ip_address then
		return
	end

	-- we're connected
	_setAction(self, "t_udapDiscover")
end


function t_udapSend(self, packet)
	-- send three udp packets in case the wireless network drops them
	self.udap:send(function() return packet end, "255.255.255.255")
	self.udap:send(function() return packet end, "255.255.255.255")
	self.udap:send(function() return packet end, "255.255.255.255")
end


-- discover the Squeezebox over udap. this makes sure that the Squeezebox exists.
function t_udapDiscover(self)
	log:debug("udapDiscover")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	-- check squeezebox exists via udap
	self.seqno = self.seqno + 1
	local packet = Udap.createDiscover(self.mac, self.seqno)
	self:t_udapSend(packet)
end


-- set Squeezebox configuration over udap. this configures the wired or wireless
-- network settings, and the dhcp or static ip settings. we don't configure the
-- slimserver yet.
function t_udapSetData(self)
	log:debug("udapSetData")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	for k,v in pairs(self.data1) do
		local hex = ""
		for i = 1,#v do
			hex = hex .. string.format("%02x", string.byte(string.sub(v, i, i)))
		end

		log:info("\tk=", k, " v=", hex)
	end

	-- configure squeezebox network
	self.seqno = self.seqno + 1
	local packet = Udap.createSetData(self.mac, self.seqno, self.data1)
	self:t_udapSend(packet)
end


-- reset Squeezebox over udap
function t_udapReset(self)
	log:debug("udapReset")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	-- reset squeezebox
	self.seqno = self.seqno + 1
	local packet = Udap.createReset(self.mac, self.seqno)
	self:t_udapSend(packet)

	-- if the reset udp reply is lost we won't know the squeezebox has reset ok
	-- let's assume that after ten requests it must have reset, if we haven't
	-- by now we are probably about to fail anyway
	if self._timeout >= 10 then
		log:warn("missing reset response, assuming squeezebox has rebooted")
		_setAction(self, "t_connectJiveNetwork")
	end
end


-- Get Squeezebox UUID
function t_udapGetUUID(self)
	log:debug("udapGetUUID")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	self.seqno = self.seqno + 1
	local packet = Udap.createGetUUID(self.mac, self.seqno)
	self:t_udapSend(packet)
end


-- Get Squeezebox IP address
function t_udapGetIPAddr(self)
	log:debug("udapGetIPAddr")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_SQUEEZEBOX"

	self.seqno = self.seqno + 1
	local packet = Udap.createGetIPAddr(self.mac, self.seqno)
	self:t_udapSend(packet)
end


-- sink for udap replies. based on the replies this sets up the next action to call.
function t_udapSink(self, chunk, err)
	if chunk == nil then
		-- ignore errors, and try again
		return
	end

	local pkt = Udap.parseUdap(chunk.data)

	-- We are only interested in udap responses
	if pkt.udapFlag ~= 0x00 then
		return
	end

	log:debug("seqno=", self.seqno, " pkt=", Udap.tostringUdap(pkt))

	if self.seqno ~= pkt.seqno then
		log:info("discarding old packet")
		return
	end

	if pkt.uapMethod == "discover" then
		if self._action == t_udapDiscover then
			_setAction(self, "t_udapSetData")
		end

	elseif pkt.uapMethod == "set_data" then
		if self._action == t_udapSetData then
			_setAction(self, "t_udapReset")
		elseif self._action == t_udapSetSlimserver then
			_setAction(self, "t_waitSlimserver")
		end

	elseif pkt.uapMethod == "reset"
		and self._action == t_udapReset then

		_setAction(self, "t_connectJiveNetwork")

	elseif pkt.uapMethod == "adv_discover" then
		if self._action == t_waitSqueezeboxNetwork then

			if pkt.ucp.device_status == "wait_wireless" then
				-- we won't see this, the Squeezebox network is not up yet

			elseif pkt.ucp.device_status == "wait_dhcp" then
				self.errorMsg = "SQUEEZEBOX_PROBLEM_DHCP_ERROR"

			elseif pkt.ucp.device_status == "wait_slimserver" then
				_setAction(self, "t_udapGetUUID")

			elseif pkt.ucp.device_status == "connected" then
				-- we should not get this far yet
				error("squeezebox connected to slimserver")
			end
		else
			-- FIXME: Still needed? Calling t_scanDiscover() here causes
			--  an error in SimpleMenu where weight is nil
			--t_scanDiscover(self, pkt)
		end

	-- Get Squeezebox UUID
	elseif pkt.uapMethod == "get_uuid"
		and self._action == t_udapGetUUID then
		
		log:info("squeezebox uuid=", pkt.uuid)

		self.uuid = pkt.uuid

		local player = _findMyPlayer(self)
		player.info.uuid = pkt.uuid

		_setAction(self, "t_udapGetIPAddr")

	-- Get Squeezebox IP address to be shown to user
	elseif pkt.uapMethod == "get_ip"
		and self._action == t_udapGetIPAddr then

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

		-- and then we're done
		_setupOK(self)
	end
end


-- reconnect Jive to it's network. we also remove the ad-hoc network from the
-- wpa-supplicant configuration.
function t_connectJiveNetwork(self)
	log:info("connectJiveNetwork adhoc_ssid=", self.adhoc_ssid)

	-- disconnect from existing network
	self.wireless:t_disconnectNetwork()

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_NETWORK"

	if self.adhoc_ssid then
		self.wireless:t_removeNetwork(self.adhoc_ssid)
		self.adhoc_ssid = nil
	end

	self.wireless:t_selectNetwork(self.networkSSID)
	_setAction(self, "t_waitJiveNetwork")
end


-- polls jives network status, waiting until we have connected to the network again.
function t_waitJiveNetwork(self)
	log:debug("waitJiveNetwork")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_LOST_NETWORK"

	local status = self.wireless:t_wpaStatus()
	if status.wpa_state == "COMPLETED" and status.ip_address then
		if self.networkMethod == 'dhcp' and string.match(status.ip_address, "^169.254.") then
			-- waiting for dhcp
			return
		end

		-- reconnect to Player/SqueezeCenter
		appletManager:callService("connectPlayer")

		_setAction(self, "t_waitSqueezeboxNetwork")
	end
end


-- check for Squeezebox status over udap. we use the advanced status request, this
-- replies with a status string so we know when the Squeezebox is ready to connect
-- to slimserver.
function t_waitSqueezeboxNetwork(self)
	log:debug("waitSqueezeboxNetwork")

	self.errorMsg = "SQUEEZEBOX_PROBLEM_CONNECTION_ERROR"

	-- check squeezebox status via udap
	self.seqno = self.seqno + 1
	local packet = Udap.createAdvancedDiscover(self.mac, self.seqno)
	self:t_udapSend(packet)
end


function parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
end


-- make sure Jive is reconnected to it's network when setup fails.
function t_connectJiveOnFailure(self)
	log:info("connectJiveOnFailure adhoc_ssid=", self.adhoc_ssid)

	if not self.adhoc_ssid then
		-- we're not connected to the ad-hoc network
		return
	end

	-- disconnect from existing network
	self.wireless:t_disconnectNetwork()

	-- remove ad-hoc network
	self.wireless:t_removeNetwork(self.adhoc_ssid)
	self.adhoc_ssid = nil

	-- connect to jive network
	self.wireless:t_selectNetwork(self.networkSSID)
end


function _setAction(self, action, label)
	log:info("next action: ", action)

	self._action = self[action]
	self._timeout = 1
	self._totalTimeout = SETUP_TIMEOUT

	-- update status
	if label == "connect_slimserver" then
		self.statusText = self:string("SQUEEZEBOX_CONNECTING_TO")
		self.statusSubtext = tostring(self.slimserver)
	elseif label == "find_slimserver" then
		-- displayed when setting squeezebox follow udap discovery
		-- e.g. when squeezebox is discovered with blue led
		self.statusText = self:string("SQUEEZEBOX_FINDING_SOURCES")
		self.statusSubtext = ''
	elseif label == "connect_network" then
		self.statusText = self:string("SQUEEZEBOX_CONNECTING_TO")
		self.statusSubtext = tostring(self.networkName)
	end
end


-- task to call the next action require to setup the Squeezebox
function t_nextAction(self)
	while true do
		local action = self._action

		log:debug("t_nextAction timeout=", self._timeout, " total=", self._totalTimeout)

		-- action timeout?
		self._timeout = self._timeout + 1
		if self._timeout == self._totalTimeout then
			log:warn("action timeout")
			return _setupFailed(self)
		end

		-- run action
		self.idle = false
		if action ~= nil then
			action(self)
		end

		self.idle = true
		Task:yield(false)
	end
end


-- display the connecting popup
-- when this popup is displayed the _nextAction() function walks through the actions
-- required to setup the Squeezebox.
function _setupSqueezebox(self)
	local window = Popup("waiting_popup")

	window:addWidget(Icon("icon_connecting"))

	local statusLabel = Label("text", self.statusText)
	local statusSublabel = Label("subtext", self.statusSubtext)
	window:addWidget(statusLabel)
	window:addWidget(statusSublabel)

	-- run action now, and then every second
	self.actionTask:addTask()
	window:addTimer(1000,
			function()
				-- self.idle is to make sure we don't wake
				-- up a network task by mistake
				if self.idle then
					self.actionTask:addTask()
				end

				statusLabel:setValue(self.statusText)
				statusSublabel:setValue(self.statusSubtext)
			end)

	window:ignoreAllInputExcept()

	-- subscribe to the jnt so that we get notifications of players added
	window:addListener(EVENT_WINDOW_ACTIVE,
		function(event)
			jnt:subscribe(self)
		end)

-- This is not working for standard wireless / wired setup when
--  connecting to SN as this evnet is then happening too early
--  and we are missing the player new notification
-- Moved unsubscribe to free() and _setupOK()
--
--	window:addListener(EVENT_WINDOW_INACTIVE,
--		function(event)
--			jnt:unsubscribe(self)
--		end) 

	self:tieAndShowWindow(window)
end


function _findMyPlayer(self)
	for mac, player in appletManager:callService("iteratePlayers") do
		if string.gsub(mac, ":", "") == self.mac then
			return player
		end
	end

	return false
end


-- Squeezebox setup completed
function _setupOK(self)
	-- Unsubscribe since setup is done
	jnt:unsubscribe(self)

	-- Select the player as the current player
	local player = _findMyPlayer(self)
	if player then
		appletManager:callService("setCurrentPlayer", player)
	end

	local window = Popup("waiting_popup")
	window:setAllowScreensaver(false)

	window:addWidget(Icon("icon_connected"))

	local text = Label("text", self:string("SQUEEZEBOX_SETUP_COMPLETE"))
	window:addWidget(text)

	local status = Label("subtext", self.squeezeboxIPAddr)
	window:addWidget(status)

	window:addTimer(2000,
			function(event)
				self:_setupDone()
			end,
			true)	-- trigger only once

	window:addListener(ACTION,
			   function(event)
				   self:_setupDone()
				   return EVENT_CONSUME
			   end)


	self:tieAndShowWindow(window)
end


-- Squeezebox setup failed
function _setupFailed(self)
	if self.adhoc_ssid then
		-- reconnect to network
		Task("setupFailed", self, t_connectJiveOnFailure):addTask()
	end

	local window = Window("error", self:string("SQUEEZEBOX_PROBLEM"), setupsqueezeboxTitleStyle)
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


	local helpText = self:string("SQUEEZEBOX_PROBLEM_HELP", self.networkSSID)
	if self.interface == 'wired' then
		helpText = self:string("SQUEEZEBOX_ETHERNET_PROBLEM_HELP")
	end

	if self.errorMsg then
		helpText = tostring(helpText) .. tostring(self:string(self.errorMsg))
	end

	local help = Textarea("help_text", helpText)

	menu:setHeaderWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
end


function _setupDone(self)
	-- Make sure we are unsubscribed
	jnt:unsubscribe(self)

	if self.setupNext then
		return self.setupNext()
	end

	self.topWindow:hideToTop(Window.transitionPushLeft)
end


function _hideToTop(self, dontSetupNext)
	if Framework.windowStack[1] == self.topWindow then
		return
	end

	while #Framework.windowStack > 2 and Framework.windowStack[2] ~= self.topWindow do
		Framework.windowStack[2]:hide(Window.transitionPushLeft)
	end

	Framework.windowStack[1]:hide(Window.transitionPushLeft)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
