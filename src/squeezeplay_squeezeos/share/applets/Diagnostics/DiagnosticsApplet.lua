
local ipairs, tostring = ipairs, tostring

-- stuff we use
local oo               = require("loop.simple")
local string           = require("string")
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
      "ETH_CONNECTION",
      "IP_ADDRESS",
      "SUBNET_MASK",
      "GATEWAY",
      "DNS_SERVER",
      "SN_ADDRESS",
      "SN_PING",
      "SN_PORT_3483",
      "SN_PORT_9000",
      "SC_ADDRESS",
      "SC_NAME",
      "SC_PING",
      "SC_PORT_3483",
      "SC_PORT_9000",
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


function ethStatus(self, iface)
	Task("Netstatus", self, function()
		local status = iface:t_wpaStatus()

		if status.link then
			if status.fullduplex then
				self:setValue("ETH_CONNECTION", self:string("ETH_FULL_DUPLEX", status.speed))
			else
				self:setValue("ETH_CONNECTION", self:string("ETH_HALF_DUPLEX", status.speed))
			end

			if status.ip_address then
				self:setValue("IP_ADDRESS", tostring(status.ip_address))
				self:setValue("SUBNET_MASK", tostring(status.ip_subnet))
				self:setValue("GATEWAY", tostring(status.ip_gateway))
				self:setValue("DNS_SERVER", tostring(status.ip_dns))
			end
		else
			self:setValue("ETH_CONNECTION", "NOT_CONNECTED")
		end
	end):addTask()
end


function dovalues(self, menu)
	-- fixed values
	self:setValue("FIRMWARE_VERSION", JIVE_VERSION)
	self:setValue("MAC_ADDRESS", System:getMacAddress())

	-- networks
	local wlanIface = Networking:wirelessInterface(jnt)
	local ethIface = Networking:wiredInterface(jnt)

	self:wlanStatus(wlanIface)
	self:ethStatus(ethIface)


	-- servers
	local sn = false
	for name, server in SlimServer:iterate() do
		if server:isSqueezeNetwork() then
			sn = server
		end
	end

	local sc = SlimServer:getCurrentServer()


	self:serverPing(sn, "SN_ADDRESS", "SN_PING")
	self:serverPort(sn, 3483, "SN_PORT_3483")
	self:serverPort(sn, 9000, "SN_PORT_9000")

	if not sc or sc:isSqueezeNetwork() then
		-- connected to SN
		self:setValue("SC_NAME", "NOT_CONNECTED")
		self:setValue("SC_ADDRESS", "NOT_CONNECTED")
		self:setValue("SC_PING", "NOT_CONNECTED")
		self:setValue("SC_PORT_3483", "NOT_CONNECTED")
		self:setValue("SC_PORT_9000", "NOT_CONNECTED")
	else
		self:setValue("SC_NAME", sc:getName())
		self:serverPing(sc, "SC_ADDRESS", "SC_PING")
		self:serverPort(sc, 3483, "SC_PORT_3483")
		self:serverPort(sc, 9000, "SC_PORT_9000")
	end
end


function diagnosticsMenu(self)
	local window = Window("text_list", self:string("DIAGNOSTICS"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(tests) do
		self.labels[name] = Label("choice", "")

		menu:addItem({
			text = self:string(name),
			check = self.labels[name],
			style = 'item_choice',
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


function supportMenu(self)
	local window = Window("help_list", self:string("SUPPORT"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("DIAGNOSTICS"),
		sound = "WINDOWSHOW",		
		callback = function()
			self:diagnosticsMenu()
		end,
	})

	window:addWidget(Textarea("help_text", self:string("SUPPORT_HELP")))
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

