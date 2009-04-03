
local ipairs, tostring = ipairs, tostring

-- stuff we use
local io               = require("io")
local oo               = require("loop.simple")
local lfs              = require("lfs")
local math             = require("math")
local string           = require("string")
local table            = require("table")

local Applet           = require("jive.Applet")
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
local log              = require("jive.utils.log").logger("applets.misc")


local jnt = jnt
local JIVE_VERSION  = jive.JIVE_VERSION


module(..., Framework.constants)
oo.class(_M, Applet)


local tests = {
      "FIRMWARE_VERSION",
      "MAC_ADDRESS",
      "WLAN_SSID",
      "WLAN_ENCRYPTION",
      "WLAN_STRENGTH",
      "IP_ADDRESS",
      "SUBNET_MASK",
      "GATEWAY",
      "DNS_SERVER",
      "SN_ADDRESS",
      "SN_PING",
      "SN_PORT_3483",
      "SN_PORT_9000",
      "SC_ADDRESS",
      "SC_PING",
      "SC_PORT_3483",
      "SC_PORT_9000",
      "UPTIME",
      "MEMORY",
}


function setValue(self, key, value)
	if value then
		self.labels[key]:setValue(self:string(value))
	else
		self.labels[key]:setValue("")
	end
end


function serverPort(self, server, port, key)
	if not server then
		self:setValue(key, "NOT_CONNECTED")
		return
	end

	Task("ports", self, function()
		local serverip = server:getIpPort()

		local ip, err
		if DNS:isip(serverip) then
			ip = serverip
		else
			ip, err = DNS:toip(serverip)
		end

		if ip == nil then
			self:setValue(key, "PORT_FAIL")
			test.running = false
			return
		end

		local tcp = SocketTcp(jnt, ip, port, "porttest")

		tcp:t_connect()
		tcp:t_addWrite(function(err)
			local res, err = tcp.t_sock:send(" ")

			if err then
				self:setValue(key, "PORT_FAIL")
			else
				self:setValue(key, "PORT_OK")
			end

			tcp:close()
		end)
	end):addTask()
end


function serverPing(self, server, dnsKey, pingKey)
	local serverip = server and server:getIpPort()

	if not serverip then
		self:setValue(dnsKey, "NOT_CONNECTED")
		self:setValue(pingKey, "NOT_CONNECTED")
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
			self:setValue(dnsKey, "DNS_FAIL")
			self:setValue(pingKey, "PING_FAIL")
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
					self:setValue(pingKey, "PING_OK")
				else
					self:setValue(pingKey, "PING_FAIL")
				end
			end
		end)
	end):addTask()
end


function wlanStatus(self, iface)
	Task("Netstatus", self, function()
		local status = iface:t_wpaStatus()
		local snr = iface:getSNR()

		if status.ssid then
			local encryption = status.key_mgmt
			-- white lie :)
			if string.match(status.pairwise_cipher, "WEP") then
				encryption = "WEP"
			end

			self:setValue("WLAN_SSID", status.ssid)
			self:setValue("WLAN_ENCRYPTION", encryption)
			self:setValue("WLAN_STRENGTH", self:string("WLAN_SNR", snr))

			if status.ip_address then
				self:setValue("IP_ADDRESS", tostring(status.ip_address))
				self:setValue("SUBNET_MASK", tostring(status.ip_subnet))
				self:setValue("GATEWAY", tostring(status.ip_gateway))
				self:setValue("DNS_SERVER", tostring(status.ip_dns))
			end
		else
			self:setValue("WLAN_SSID", "NOT_CONNECTED")
			self:setValue("WLAN_ENCRYPTION", nil)
			self:setValue("WLAN_STRENGTH", nil)
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
		uptime.days = math.floor(time / 216000)
		time = math.fmod(time, 216000)
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


function dovalues(self, menu)
	local uuid, mac = jnt:getUUID()

	-- fixed values
	self:setValue("FIRMWARE_VERSION", JIVE_VERSION)
	self:setValue("MAC_ADDRESS", mac)

	-- networks
	local iface = Networking:wirelessInterface()
	local wlan = Networking(jnt, iface)

	self:wlanStatus(wlan)


	-- servers
	local sn = false
	for name, server in SlimServer:iterate() do
		if server:isSqueezeNetwork() then
			sn = server
		end
	end

	local sc = SlimServer:getCurrentServer()


	self:serverPing(sn, "SN_ADDRESS", "SN_PING")
	self:serverPing(sc, "SC_ADDRESS", "SC_PING")

	self:serverPort(sn, 3483, "SN_PORT_3483")
	self:serverPort(sn, 9000, "SN_PORT_9000")
	self:serverPort(sc, 3483, "SC_PORT_3483")
	self:serverPort(sc, 9000, "SC_PORT_9000")

	self:systemStatus()
end


function diagnosticsMenu(self)
	local window = Window("window", self:string("DIAGNOSTICS"))
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(tests) do
		self.labels[name] = Label("value", "")

		menu:addItem({
			text = self:string(name),
		})
		menu:addItem({
			text = "",
			icon = self.labels[name],
		})
	end

	dovalues(self, menu)
	menu:addTimer(5000, function()
		dovalues(self, menu)
	end)


	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

