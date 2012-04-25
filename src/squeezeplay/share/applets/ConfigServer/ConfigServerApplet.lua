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

local CONFIG_SERVER	= "config.nightly.belsonic.squeezenetwork.com"
local CONFIG_PORT	= 80
local DEFAULT_SN	= "baby.squeezenetwork.com"


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	log:info("Initialize ConfigServerApplet")

	local mac = System:getMacAddress()
	local machine, revision = System:getMachine()

	self.configPath = "/config/id/" .. URL.escape(mac) .. "?firmware/" .. URL.escape(JIVE_VERSION)
end


function developerMenu(self)
	local window = Window("text_list", self:string("DEVELOPER"))
	local menu = SimpleMenu("menu")

	menu:addItem({
		text = tostring(self:string("DEVELOPER_CURRENT_SN")) .. "\n" .. tostring(jnt:getSNHostname()),
		style = 'item_info',
	})

	menu:addItem({
		text = self:string("DEVELOPER_UPDATE_CHANNEL"),
		sound = "WINDOWSHOW",
		style = 'item',
		callback = function ()
			self:_updateChannelMenu()
		end
	})

	menu:addItem({
		text = self:string("DEVELOPER_OUTOFBOX"),
		sound = "WINDOWSHOW",
		style = 'item',
		callback = function ()
			self:_outOfBoxMenu()
		end
	})

--[[
	-- This is for debugging purposes only
	menu:addItem({
		text = self:string("DEVELOPER_TEST_FETCH"),
		sound = "WINDOWSHOW",
		style = 'item',
		callback = function ()
			self:fetchUpdateChannelList(false, false, false)  -- no set, no register, no callback
		end
	})
--]]

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _updateChannelMenu(self)
	local window = Window("text_list", self:string("DEVELOPER_UPDATE_CHANNEL"))
	local menu = SimpleMenu("menu")

	for k, v in pairs(menu) do
		menu:removeItem(v)
	end

	local settings = self:getSettings()

	if #settings.updateChannelList > 0 then
		for k, v in pairs(settings.updateChannelList) do
			menu:addItem({
				text = v[1],
				sound = "WINDOWSHOW",
				style = 'item',
				callback = function ()
					self:_switchSN(v[2])
				end
			})
		end
	else
		menu:addItem({
			text = self:string("DEVELOPER_NO_OPTION_AVAILABLE"),
			sound = "WINDOWSHOW",
			style = 'item',
	})
	end

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _outOfBoxMenu(self)
	local window = Window("text_list", self:string("DEVELOPER_OUTOFBOX"))
	local menu = SimpleMenu("menu", {
					{
						text = self:string("DEVELOPER_OUTOFBOX_CANCEL"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("DEVELOPER_OUTOFBOX_CONTINUE"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_outOfBox()
							   end
					},
				})
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
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


-- Switching SN always forces a registration
-- Only called from the Update Channel menu
function _switchSN(self, url)
	log:info("Switch SN to: ", url)

	local squeezenetwork = false
	for name, server in SlimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end

	jnt:setSNHostname(url)
	--                           url  port  name (visible to user)
	squeezenetwork:updateAddress(url, 9000, "mysqueezebox.com")

	local settings = self:getSettings()
	settings.currentSN = url
	self:storeSettings()

	self:_registerSN(2000)
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

-- Contact config server, fill Update Channel list,
-- Service method
-- Called during boot time
function fetchUpdateChannelList(self, doSet, doRegister, callback)

	if not self.configPath then
		self:init()
	end

	log:info("Config server: ", CONFIG_SERVER)
	log:info("Config path: ", self.configPath)

	Task("fetchUpdateChannelList", abc, function()
		local updateChannelList = {}
		local url = false
		local weAreDone = false
		local socket = SocketHttp(jnt, CONFIG_SERVER, CONFIG_PORT, "getconfig")
		local req = RequestHttp(
			function(chunk, err)
				if chunk then
					local obj = json.decode(chunk)
					if not obj then
						return
					end
					log:info("Decoded JSON: ", obj)
					if not obj.channels then
						return
					end
					for k2,v2 in pairs(obj.channels) do
						if obj.channels[k2] then
							log:info("text   : ", obj.channels[k2].text)
							log:info("service: ", obj.channels[k2].service)

							if obj.channels[k2].text and obj.channels[k2].service then
								table.insert(updateChannelList, {
									obj.channels[k2].text,
									obj.channels[k2].service})
							end
						end
					end
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
		settings.updateChannelList = updateChannelList
		self:storeSettings()

		-- no current SN stored (OOB)
		-- - config not reachable:	connect to prod
		-- - only one option:		use option
		-- - more than one option:	connect to prod, show Update Channel list
		-- current SN stored
		-- - config not reachable:	connect to current SN
		-- - only one option:		use option
		-- - more than one option:	connect to current SN, show Update Channel list

		log:info("UpdateChannelList has ", #updateChannelList, " entries")

		if #updateChannelList == 0 then
			url = settings.currentSN
			if not url then
				url = DEFAULT_SN
			end
		end

		if #updateChannelList == 1 then
			url = updateChannelList[1][2]
		end

		if #updateChannelList > 1 then
			url = settings.currentSN
			if not url then
				url = DEFAULT_SN
			end

			-- More than one entry -> add developer menu
			local menuItem = {
				id = "developer",
				node = "advancedSettings",
				text = self:string("DEVELOPER"),
				sound = "WINDOWSHOW",
				callback = function() self:developerMenu() end,
			}
			jiveMain:addItem(menuItem)

		end

		log:info("SN url to use: ", url)

		if doSet then
			self:_setSN(url, doRegister)
		end

		if callback then
			callback()
		end

	end):addTask()

end


-- Fake out of box - similar to factory reset, but with stored SN
-- Delete all settings (exept our own) in /etc/squeezeplay/userpath/settings
--  and replace /etc/wpa_supplicant.conf with a pristine copy
function _outOfBox(self)
	-- disconnect from Player/SqueezeCenter
	appletManager:callService("disconnectPlayer")

	local popup = Popup("waiting_popup")
	popup:addWidget(Icon("icon_connected"))
	popup:addWidget(Label("text", self:string("DEVELOPER_OUTOFBOX_REBOOTING")))

	-- make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)

	-- we're shutting down, so prohibit any key presses or holds
	Framework:addListener(EVENT_ALL_INPUT,
			      function ()
				      return EVENT_CONSUME
			      end,
			      true)

	-- Temprarily get our settings
	local settings = self:getSettings()
	-- Clean out all custom settings
	os.execute("rm /etc/squeezeplay/userpath/settings/*")
	os.execute("echo 'update_config=1' > /etc/wpa_supplicant.conf")
	os.execute("echo 'ctrl_interface=/var/run/wpa_supplicant' >> /etc/wpa_supplicant.conf")
	-- Set our settings again
	self:storeSettings()
	-- Make sure all changes are written
	os.execute("sync")
	-- Reboot
	popup:addTimer(2000, function()
				     log:info("Out of box - rebooting ...")

				     appletManager:callService("reboot")
			      end)

	self:tieAndShowWindow(popup)
end

--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
