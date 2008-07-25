

-- stuff we use
local pairs, setmetatable, tostring, tonumber  = pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local SlimServers   = require("jive.slim.SlimServer")

local Framework     = require("jive.ui.Framework")
local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")

local SlimProto     = require("jive.net.SlimProto")
local Playback      = require("jive.audio.Playback")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("applets.setup")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local CONNECT_TIMEOUT = 30


-- main setting menu
function settingsShow(self)

	local window = Window("window", self:string("TEST_PLAYBACK"))
	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)


	self.serverMenu = menu
	self.serverWindow = window


	-- Discover slimservers in this window
	appletManager:callService("discoverPlayers")
	window:addTimer(1000, function() appletManager:callService("discoverPlayers") end)


	-- slimservers on the poll list
	local poll = appletManager:callService("getPollList")
	for address,_ in pairs(poll) do
		if address ~= "255.255.255.255" then
			self:_addServerItem(nil, address)
		end
	end


	-- discovered slimservers
	for _,server in appletManager:callService("iterateSqueezeCenters") do
		if not server:isSqueezeNetwork() then
			self:_addServerItem(server)
		end
	end

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
			   function()
				   self:storeSettings()
			   end
		   )

	self:tieAndShowWindow(window)
end


function _addServerItem(self, server, address)
	log:debug("_addServerItem ", server, " " , port)

	local id = server or address

	-- new entry
	local item = {
		text = server and server:getName() or address,
		sound = "WINDOWSHOW",
		callback = function()
			self:_connectToServer(server)
			self.serverWindow:hide()
		end,
		weight = 1,
	}

	self.serverMenu:addItem(item)
end


function _connectToServer(self, server)
	local ip = server:getIpPort()

	local slimProto = SlimProto(jnt, ip, {
		opcode = "HELO",
		deviceID = "4",
		revision = "0",
	})

	self.id = slimProto:getId()

	Playback(jnt, slimProto)
	slimProto:connect()


	for id, player in appletManager:callService("iteratePlayers") do
		if self.id == id then
			appletManager:callService("setCurrentPlayer", player)
			return
		end
	end

	jnt:subscribe(self)
end


function notify_playerNew(self, player)
	if self.id == player:getId() then
		appletManager:callService("setCurrentPlayer", player)
		jnt:unsubscribe(self)
	end
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

