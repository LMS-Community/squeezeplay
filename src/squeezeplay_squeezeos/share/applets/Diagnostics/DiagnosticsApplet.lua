
local ipairs, tostring = ipairs, tostring, tonumber

-- stuff we use
local oo               = require("loop.simple")
local io               = require("io")
local math             = require("math")
local string           = require("string")
local table            = require("jive.utils.table")
local lfs              = require("lfs")

local Applet           = require("jive.Applet")
local System           = require("jive.System")
local DNS              = require("jive.net.DNS")
local Networking       = require("jive.net.Networking")
local Process          = require("jive.net.Process")
local SocketTcp        = require("jive.net.SocketTcp")
local SlimServer       = require("jive.slim.SlimServer")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")

local debug            = require("jive.utils.debug")


local jnt = jnt
local appletManager    = appletManager
local JIVE_VERSION  = jive.JIVE_VERSION


module(..., Framework.constants)
oo.class(_M, Applet)


local tests = {
      "FIRMWARE_VERSION",
      "HARDWARE_VERSION",
      "MAC_ADDRESS",
      "WLAN_SSID",
      "WLAN_ENCRYPTION",
      "WLAN_STRENGTH",
      -- (for testing): "WLAN_SNR",
      "ETH_CONNECTION",
      "IP_ADDRESS",
      "SUBNET_MASK",
      "GATEWAY",
      "DNS_SERVER",
      "SN_ADDRESS",
      "SN_PING",
      "SN_PORT_3483",
      "SN_PORT_9000",
      "SN_REG",
      "SC_ADDRESS",
      "SC_NAME",
      "SC_PING",
      "SC_PORT_3483",
      "SC_PORT_9000",
      "CURRENT_PLAYER",
      "PLAYER_TYPE",
      "UPTIME",
      "MEMORY",
}

local powerTests = {
      "MSP_VERSION",
      "BATTERY_VOLTAGE",
      "BATTERY_VMON1",
      "BATTERY_VMON2",
      "WALL_VOLTAGE",
      "BATTERY_TEMPERATURE",
      "POWER_MODE",
      "CHARGE_STATE",
}

local powerMode = {
	  ["3"] = "POWER_ON_AC",
	  ["7"] = "POWER_ON_AC_AND_BATT",
	  ["5"] = "POWER_ON_BATT",
}

local chargerState = {
	  ["1"]  = "BATT_NONE",
	  ["2"]  = "BATT_IDLE",
	  ["3"]  = "BATT_DISCHARGING",
	  ["35"] = "BATT_DISCHARGING_WARNING",
	  ["8"]  = "BATT_CHARGING",
	  ["24"] = "BATT_CHARGING_PAUSED",
}

function setValue(self, key, value)
	if not value then
		value = '-'
	end
	self.diagMenu:setText(self.labels[key], self:string(key, value))
end


function setPowerValue(self, key, value)
	if not value then
		value = '-'
	end
	self.powerDiagMenu:setText(self.labels[key], self:string(key, value))
end


function serverPort(self, server, port, key)
	if not server then
		self:setValue(key, self.notConnected)
		return
	end

	local portOk = tostring(self:string('PORT_OK'))
	local portFail = tostring(self:string('PORT_FAIL'))
	Task("ports", self, function()
		local serverip = server:getIpPort()

		local ip, err
		if DNS:isip(serverip) then
			ip = serverip
		else
			ip, err = DNS:toip(serverip)
		end

		if ip == nil then
			self:setValue(key, portFail)
			return
		end

		local tcp = SocketTcp(jnt, ip, port, "porttest")

		tcp:t_connect()
		tcp:t_addWrite(function(err)
			local res, err = tcp.t_sock:send(" ")

			if err then
				self:setValue(key, portFail)
			else
				self:setValue(key, portOk)
			end

			tcp:close()
		end)
	end):addTask()
end


function serverPing(self, server, dnsKey, pingKey, snRegKey)
	local serverip = server and server:getIpPort()

	local dnsFail            = tostring(self:string('DNS_FAIL'))
	local pingFailString     = tostring(self:string('PING_FAIL'))
	local pingOkString       = tostring(self:string('PING_OK'))
	local snRegYesString     = tostring(self:string('SN_REG_YES'))
	local snRegNoString      = tostring(self:string('SN_REG_NO'))

	if not serverip then
		self:setValue(dnsKey, self.notConnected)
		self:setValue(pingKey, self.notConnected)
		return
	end

	Task("ping", self, function()
		local ipaddr

		-- DNS lookup
		if DNS:isip(serverip) then
			ipaddr = serverip
		else
			ipaddr = DNS:toip(serverip)
		end

		if not ipaddr then
			self:setValue(dnsKey, dnsFail)
			self:setValue(pingKey, pingFailString)
			return
		end

		self:setValue(dnsKey, ipaddr)

		-- Ping
		local pingOK = false
		local ping = Process(jnt, "ping -c 1 " .. ipaddr)
		ping:read(function(chunk)
			if chunk then
				if string.match(chunk, "bytes from") then
					pingOK = true
				end
			else
				if pingOK then
					self:setValue(pingKey, pingOkString)
					if snRegKey then
						if server:getPin() == false then
							self:setValue(snRegKey, snRegYesString)
						elseif server:getPin() == nil then
							self:setValue(snRegKey, "")
						else
							self:setValue(snRegKey, snRegNoString)
						end
					end
				else
					self:setValue(pingKey, pingFailString)
				end
			end
		end)
	end):addTask()
end


function wlanStatus(self, iface)
	if not iface then
		return
	end

	Task("Netstatus", self, function()
		local status = iface:t_wpaStatus()
		local snr, minsnr, maxsnr = iface:getSNR()
		local signalStrength = iface:getSignalStrength()

		if status.ssid then
			local encryption = status.key_mgmt
			-- white lie :)
			if string.match(status.pairwise_cipher, "WEP") then
				encryption = "WEP"
			end

			self:setValue("WLAN_SSID", status.ssid)
			self:setValue("WLAN_ENCRYPTION", encryption)
			self:setValue("WLAN_STRENGTH", signalStrength .. "%")
			-- (for testing): self:setValue("WLAN_SNR", minsnr .. "/" .. snr .. "/" .. maxsnr)

			if status.ip_address then
				self:setValue("IP_ADDRESS", tostring(status.ip_address))
				self:setValue("SUBNET_MASK", tostring(status.ip_subnet))
				self:setValue("GATEWAY", tostring(status.ip_gateway))
				self:setValue("DNS_SERVER", tostring(status.ip_dns))
			end
		else
			self:setValue('WLAN_SSID', self.notConnected)
			self:setValue("WLAN_ENCRYPTION", nil)
			self:setValue("WLAN_STRENGTH", nil)
		end
	end):addTask()
end


function ethStatus(self, iface)
	if not iface then
		return
	end

	Task("Netstatus", self, function()
		local status = iface:t_wpaStatus()

		if status.link then
			if status.fullduplex then
				self:setValue("ETH_CONNECTION", tostring(self:string("ETH_FULL_DUPLEX", status.speed)))
			else
				self:setValue("ETH_CONNECTION", tostring(self:string("ETH_HALF_DUPLEX", status.speed)))
			end

			if status.ip_address then
				self:setValue("IP_ADDRESS", tostring(status.ip_address))
				self:setValue("SUBNET_MASK", tostring(status.ip_subnet))
				self:setValue("GATEWAY", tostring(status.ip_gateway))
				self:setValue("DNS_SERVER", tostring(status.ip_dns))
			end
		else
			self:setValue("ETH_CONNECTION", self.notConnected)
		end
	end):addTask()
end


function systemStatus(self)
	local uptime = ""
	local memory = ""
	
	local f = io.open("/proc/uptime")
	if f then
		local time = f:read("*all")
		f:close()
	
		time = string.match(time, "(%d+)")
	
		uptime = {}
		uptime.days = math.floor(time / 86400)
		time = math.fmod(time, 86400)
		uptime.hours = math.floor(time / 3600)
		time = math.fmod(time, 3600)
		uptime.minutes = math.floor(time / 60)
	
		local ut = {}
		if uptime.days > 0 then
		 	ut[#ut + 1] = tostring(self:string("UPTIME_DAYS", uptime.days))
		end
		if uptime.hours > 0 then
			ut[#ut + 1] = tostring(self:string("UPTIME_HOURS", uptime.hours))
		end
		ut[#ut + 1] = tostring(self:string("UPTIME_MINUTES", uptime.minutes))
		uptime = table.concat(ut, " ")
	end
	
	local f = io.open("/proc/meminfo")
	if f then
		local mem = {}
	
		while true do
			local line = f:read()
			if line == nil then
				break
			end
	
			local key, value = string.match(line, "(.+):%s+(%d+)")
		 	mem[key] = value
		end
		f:close()

		memory = math.ceil(((mem.MemTotal - (mem.MemFree + mem.Buffers + mem.Cached)) / mem.MemTotal) * 100) .. "%"
	end
	
	self:setValue("UPTIME", uptime)
	self:setValue("MEMORY", memory)
end

function _getSysValue(self, param)

	local f = io.open("/sys/bus/i2c/devices/1-0010/" .. param)

	local value = f:read("*all")
	f:close()

	return value
end

function _getPowerSysValue(self, param)

	local f = io.open("/sys/devices/platform/i2c-adapter:i2c-1/1-0010/" .. param)
	log:warn("opening: ", param)

	local value = f:read("*all")
	f:close()

	return value
end

function dovalues(self, menu)
	local machine, revision = System:getMachine();

	-- fixed values
	self:setValue("FIRMWARE_VERSION", JIVE_VERSION)
	if revision then
		self:setValue("HARDWARE_VERSION", tostring(revision))
	end
	self:setValue("MAC_ADDRESS", System:getMacAddress())

	-- networks
	local wlanIface = Networking:wirelessInterface(jnt)
	local ethIface = Networking:wiredInterface(jnt)

	self:wlanStatus(wlanIface)
	if System:hasWiredNetworking() then
		self:ethStatus(ethIface)
	end


	-- servers
	local sn = false
	for name, server in SlimServer:iterate() do
		if server:isSqueezeNetwork() then
			sn = server
		end
	end

	local sc = SlimServer:getCurrentServer()


	self:serverPing(sn, "SN_ADDRESS", "SN_PING", "SN_REG")
	self:serverPort(sn, 3483, "SN_PORT_3483")
	self:serverPort(sn, 9000, "SN_PORT_9000")

	if not sc or sc:isSqueezeNetwork() then
		-- connected to SN
		self:setValue("SC_NAME", self.notConnected)
		self:setValue("SC_ADDRESS", self.notConnected)
		self:setValue("SC_PING", self.notConnected)
		self:setValue("SC_PORT_3483", self.notConnected)
		self:setValue("SC_PORT_9000", self.notConnected)
	else
		self:setValue("SC_NAME", sc:getName())
		self:serverPing(sc, "SC_ADDRESS", "SC_PING")
		self:serverPort(sc, 3483, "SC_PORT_3483")
		self:serverPort(sc, 9000, "SC_PORT_9000")
	end


	local currentPlayer = appletManager:callService("getCurrentPlayer")
	if currentPlayer then
		self:setValue("CURRENT_PLAYER", currentPlayer:getName())
		if currentPlayer:isLocal() then
			self:setValue("PLAYER_TYPE", tostring(self:string("DIAGNOSTICS_LOCAL")))
		else
			self:setValue("PLAYER_TYPE", tostring(self:string("DIAGNOSTICS_REMOTE")))
		end
	else
		self:setValue("CURRENT_PLAYER", tostring(self:string("DIAGNOSTICS_NONE")))
		self:setValue("PLAYER_TYPE", "")

	end

	self:systemStatus()

end


function doPowerValues(self, menu)
	self:setValue("MSP_VERSION", self:_getSysValue("fw"))
	self:setValue("BATTERY_VOLTAGE"	   , tostring(self:_getPowerSysValue("battery_voltage")      /1000.0) .. " V")
	self:setValue("BATTERY_VMON1"  	   , tostring(self:_getPowerSysValue("battery_vmon1_voltage")/1000.0) .. " V")
	self:setValue("BATTERY_VMON2"  	   , tostring(self:_getPowerSysValue("battery_vmon2_voltage")/1000.0) .. " V")
	self:setValue("WALL_VOLTAGE"   	   , tostring(self:_getPowerSysValue("wall_voltage")         /1000.0) .. " V")
	self:setValue("BATTERY_TEMPERATURE", tostring(self:_getPowerSysValue("battery_temperature")  /32.0  ) .. " C")

	local mode = self:_getPowerSysValue("power_mode"):gsub("^%s*(.-)%s*$", "%1")
	self:setValue("POWER_MODE"         , tostring(self:string(powerMode[mode])))
	local mode = self:_getPowerSysValue("charger_state"):gsub("^%s*(.-)%s*$", "%1")
	self:setValue("CHARGE_STATE"       , tostring(self:string(chargerState[mode])))
end


function showPowerDiagnosticsMenu(self)
	local window = Window("text_list", self:string("POWER"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(powerTests) do
		self.labels[name] = {
			text = self:string(name, ''),
			style = 'item_info',
		}
		menu:addItem(self.labels[name])
	end

	self.powerDiagMenu = menu
	doPowerValues(self, menu)
	menu:addTimer(5000, function()
		doPowerValues(self, menu)
	end)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function diagnosticsMenu(self, suppressNetworkingItem)
	local window = Window("text_list", self:string("DIAGNOSTICS"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(tests) do
		if name ~= 'ETH_CONNECTION' or System:getMachine() ~= 'jive' then
			self.labels[name] = {
				text = self:string(name, ''),
				style = 'item_info',
			}
			menu:addItem(self.labels[name])
		end
	end

	if System:getMachine() == "baby" then
		menu:addItem({
			text = self:string("POWER"),
			style = 'item',
			callback = function ()
				self:showPowerDiagnosticsMenu()
			end
		})
	end
	
	if System:isHardware() then
		menu:addItem({
			text = self:string("SOFTWARE_UPDATE"),
			style = 'item',
			callback = function ()
				--todo: this does setup style FW upgrade only (since this menu is avilable from setup).  When we want different support for a non-setup version, make sure to leave the setup style behavior
				appletManager:callService("firmwareUpgrade", nil, true)
			end
		})

		if not suppressNetworkingItem then
			menu:addItem({
				text = self:string("DIAGNOSTICS_NETWORKING"),
				style = 'item',
				callback = function ()
					appletManager:callService("settingsNetworking")
				end
			})
		end
	end

	self.notConnected = tostring(self:string('NOT_CONNECTED'))

	self.diagMenu = menu
	dovalues(self, menu)
	menu:addTimer(5000, function()
		dovalues(self, menu)
	end)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function supportMenu(self)
	local window = Window("help_list", self:string("SUPPORT"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("DIAGNOSTICS"),
		sound = "WINDOWSHOW",		
		callback = function()
			self:diagnosticsMenu(true)
		end,
	})

	menu:setHeaderWidget(Textarea("help_text", self:string("SUPPORT_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

