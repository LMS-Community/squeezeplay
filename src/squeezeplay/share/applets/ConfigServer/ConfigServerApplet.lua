local tostring, pairs, ipairs = tostring, pairs, ipairs

-- stuff we use
local oo                     = require("loop.simple")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Timer                  = require("jive.ui.Timer")
local Networking             = require("jive.net.Networking")

local SlimServer	= require("jive.slim.SlimServer")
local Task		= require("jive.ui.Task")
local SocketHttp	= require("jive.net.SocketHttp")
local RequestHttp	= require("jive.net.RequestHttp")
local json		= require("json")
local URL		= require("socket.url")

local appletManager	= appletManager
local jiveMain		= jiveMain
local jnt		= jnt
local JIVE_VERSION      = jive.JIVE_VERSION

local CONFIG_PORT	= 80


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	log:info("Initialize ConfigServerApplet")

	local mac = System:getMacAddress()
	local machine, revision = System:getMachine()

	self.configServer = "config.logitechmusic.com"
	self.configPath = "/config/id/" .. URL.escape(mac) .. "?firmware=" .. URL.escape(JIVE_VERSION)

	self.channelText = false
	self.channelService = false
	self.firmwareUrl = false
	self.firmwarePrompt = false
end


function _handleFirmwareUpgradeMenuItem(self)
	if self.firmwareUrl and self.firmwarePrompt and self.firmwarePrompt != "required" then
		if appletManager:hasService("firmwareUpgradeWithUrl") then
			-- show firmware upgrade menu in home screen
			appletManager:callService("firmwareUpgradeWithUrl", self.firmwareUrl, false)
		end

	else
		if appletManager:hasService("firmwareUpgradeWithUrl") then
			-- remove firmware upgrade menu in home screen
			appletManager:callService("firmwareUpgradeWithUrl", false, false)
		end

	end
end


function _registerSN(self, delay)
	if not delay then
		delay = 1000
	end

	local timer1 = Timer(delay,
		function ()
			appletManager:callService("startRegister")
		end,
		true	-- once
	)
	timer1:start()
end


-- Set SN with optional registering
-- Called during boot time
function _setSN(self, url, doRegister)
	log:info("Set SN to: ", url, " call register: ", doRegister)

	local squeezenetwork = false
	for name, server in SlimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end

	jnt:setSNHostname(url)
	--                           url  port  name (visible to user)
	squeezenetwork:updateAddress(url, 9000, "UEsmartradio.com")

	local player = appletManager:callService("getCurrentPlayer")

-- This is not used anymore - the player always only connects to the backend
-- Local servers (UEML) (i.e. attached servers) are only browsed
--	local server = appletManager:callService("getInitialSlimServer")
--	log:info("Initial server to connect to: ", server)
--	-- LMS in use -> connect to LMS
--	if server and not server:isSqueezeNetwork() then
--		player:connectToServer(server)
--		return
--	end

	-- SN in use
	local settings = self:getSettings()
	-- Same SN as last time, no need to register
	if settings.currentSN == url then
		player:connectToServer(squeezenetwork)
		return
	end

	settings.currentSN = url
	self:storeSettings()

	if doRegister then
		self:_registerSN(2000)
	else
		-- FIXME: workaround until filesystem write issue resolved
		os.execute("sync")
	end
end


function _parseConfigData(self, chunk)
	local obj = json.decode(chunk)
	if not obj then
		log:warn("JSON config data invalid (parse error)")
		return
	end
	log:debug("Decoded JSON: ", obj)

	if obj.channel and obj.channel.text and obj.channel.service then
		self.channelText = obj.channel.text
		self.channelService = obj.channel.service
	end
	if obj.firmware and obj.firmware.url and obj.firmware.prompt then
		self.firmwareUrl = obj.firmware.url
		self.firmwarePrompt = obj.firmware.prompt
	end

	log:info("text    : ", self.channelText)
	log:info("service : ", self.channelService)
	log:info("firmware: ", self.firmwareUrl)
	log:info("prompt  : ", self.firmwarePrompt)
end


-- Service method
function checkRequiredFirmwareUpgrade(self)
	if self.firmwareUrl and self.firmwarePrompt then
		if self.firmwarePrompt == "required" then
			-- Upgrade required firmware without asking
			log:info("Upgrade required firmware without asking")
			if appletManager:hasService("firmwareUpgradeWithUrl") then
				appletManager:callService("firmwareUpgradeWithUrl", self.firmwareUrl, true)
				return true
			end
		end
	end
	return false
end


-- Contact config server, fill Update Channel list, get firmware url
-- Service method
-- Called during boot time
function fetchConfigServerData(self, doSet, doRegister, doRequiredFirmwareUpgrade, callback)

	if not self.configServer then
		self:init()
	end

	if not self.configPath then
		self:init()
	end

	log:info("Config server: ", self.configServer)
	log:info("Config path: ", self.configPath)

	self.channelText = false
	self.channelService = false
	self.firmwareUrl = false
	self.firmwarePrompt = false

	Task("fetchConfigServerData", abc, function()

		-- Wait for the network to be ready before trying to contact the config server
		-- Proceed if after 3 minutes the network is still not ready
		if Networking:waitNetworkReady(3*60) == false then
			log:info("Network still not ready after waiting 3 minutes. Proceeding... ")
		end

		local url = false
		local weAreDone = false
		local socket = SocketHttp(jnt, self.configServer, CONFIG_PORT, "getconfig")
		local req = RequestHttp(
			function(chunk, err)
				if chunk then
					self:_parseConfigData(chunk)
				end
				weAreDone = true
			end,
			'GET',
		self.configPath)

		socket:fetch(req)

		while weAreDone == false do
			Task:yield()
		end

		local settings = self:getSettings()

		-- no current SN stored (OOB)
		-- - config not reachable:	connect to prod
		-- - option available:		use option
		-- current SN stored
		-- - config not reachable:	connect to current SN
		-- - option available:		use option

		-- option available - use it
		if self.channelService then
			url = self.channelService

		-- option not available - try stored SN
		else
			url = settings.currentSN
			-- stored SN not available - use default SN
			if not url then
				url = jnt:getSNDefaultHostname()
			end
		end

		log:info("SN url to use: ", url)

		-- Do required firmware upgrade
		if doRequiredFirmwareUpgrade then
			if self:checkRequiredFirmwareUpgrade() then
				return
			end
		end

		-- Handle firmware upgrade menu for non required upgrades
		self:_handleFirmwareUpgradeMenuItem()

		if doSet then
			self:_setSN(url, doRegister)
		end

		if callback then
			callback()
		end

	end):addTask()

end


--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
