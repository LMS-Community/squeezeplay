local tostring, pairs, ipairs = tostring, pairs, ipairs

-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local SlimServer	= require("jive.slim.SlimServer")
local Task		= require("jive.ui.Task")
local SocketHttp	= require("jive.net.SocketHttp")
local RequestHttp	= require("jive.net.RequestHttp")
local json		= require("json")
local table		= require("jive.utils.table")
local System		= require("jive.System")
local URL		= require("socket.url")

local appletManager	= appletManager
local jiveMain		= jiveMain
local jnt		= jnt
local JIVE_VERSION      = jive.JIVE_VERSION

local CONFIG_PORT	= 80
local DEFAULT_SN	= "baby.squeezenetwork.com"


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
	squeezenetwork:updateAddress(url, 9000, "mysqueezebox.com")

	local player = appletManager:callService("getCurrentPlayer")

-- TODO: Issue to solve: If player is on LMS and SN changes from prod to test,
--  switch to SN (via menu) fails because LMS is handling the switch and
--  doesn't know the correct SN, sending the player to prod instead.
	local server = appletManager:callService("getInitialSlimServer")
	log:info("Initial server to connect to: ", server)
	-- LMS in use -> connect to LMS
	if server and not server:isSqueezeNetwork() then
		player:connectToServer(server)
		return
	end

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
	if obj.firmware and obj.firmware.url then
		self.firmwareUrl = obj.firmware.url
	end

	log:info("text    : ", self.channelText)
	log:info("service : ", self.channelService)
	log:info("firmware: ", self.firmwareUrl)
end


-- Service method
function getConfigServerFirmwareUrl(self)
	return self.firmwareUrl
end


-- Contact config server, fill Update Channel list, get firmware url
-- Service method
-- Called during boot time
function fetchConfigServerData(self, doSet, doRegister, doFirmwareUpgrade, callback)

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

	Task("fetchConfigServerData", abc, function()
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
				url = DEFAULT_SN
			end
		end

		log:info("SN url to use: ", url)

		if doFirmwareUpgrade and self.firmwareUrl and appletManager:hasService("firmwareUpgradeWithUrl") then
			appletManager:callService("firmwareUpgradeWithUrl", self.firmwareUrl)
			return
		end

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
