
local assert, getmetatable = assert, getmetatable

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

local LocalPlayer   = require("jive.slim.LocalPlayer")
local SlimServer    = require("jive.slim.SlimServer")

local debug          = require("jive.utils.debug")
local log            = require("jive.utils.log").logger("applet")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	return {
		-- Enable audio playback
		-- 0 == default off
		-- 1 == default on
		-- 2 == user off
		-- 3 == user on
		enableAudio = 0,
	}
end


function registerApplet(meta)
	-- this allows us to share state with the applet
	meta.state = {}

	jiveMain:addItem(meta:menuItem('audioPlayback', 'advancedSettings', "AUDIO_PLAYBACK", function(applet, ...) applet:settingsShow(meta.state) end))
end


function configureApplet(meta)
	local settings = meta:getSettings()

	if settings.enableAudio & 1 == 0 then
		-- no audio playback
		return
	end


	-- Create player instance
	local uuid = System:getUUID()
	local playerid = System:getMacAddress()
	assert(uuid)
	assert(playerid)

	meta.state.player = LocalPlayer(jnt, playerid, uuid)

	-- Connect player
	local server = nil
	if settings.serverName then
		server = SlimServer(jnt, settings.serverName)
		server:updateInit(settings.serverInit)
	end

	-- Init player
	if settings.playerInit then
		meta.state.player:updateInit(server, settings.playerInit)
	end

	-- Subscribe to changes in player status
	jnt:subscribe(meta)
end


function _updateSettings(meta, player, force)
	local settings = meta:getSettings()

	local server = player and player:getSlimServer() or false
	local serverName = server and server:getName() or false

	if not force and
	   settings.serverName == serverName then
		-- no change
		return
	end

	settings.serverName = serverName
	settings.serverInit = server:getInit()
	settings.playerInit = player:getInit()

	meta:storeSettings()
end


function notify_playerConnected(meta, player)
	if meta.state.player ~= player then
		return
	end

	_updateSettings(meta, player)
end


function notify_playerNewName(meta, player, playerName)
	if meta.state.player ~= player then
		return
	end

	_updateSettings(meta, player, true)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

