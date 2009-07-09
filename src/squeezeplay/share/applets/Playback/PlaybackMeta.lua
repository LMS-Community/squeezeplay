
local assert, getmetatable = assert, getmetatable

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

local LocalPlayer   = require("jive.slim.LocalPlayer")
local SlimServer    = require("jive.slim.SlimServer")

local Decode        = require("squeezeplay.decode")

local debug         = require("jive.utils.debug")

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

		-- alsa settings
		alsaPlaybackDevice = "default",
		alsaPlaybackBufferTime = 60000,
		alsaPlaybackPeriodCount = 3,

		alsaEffectsDevice = nil,
		alsaEffectsBufferTime = nil,
		alsaEffectsPeriodCount = nil,
	}
end


function registerApplet(meta)
	local settings = meta:getSettings()

	-- this allows us to share state with the applet
	meta.state = {}

	if not Decode:open(settings) then
		-- no audio device
		return
	end

	jiveMain:addItem(meta:menuItem('audioPlayback', 'advancedSettingsBetaFeatures', "AUDIO_PLAYBACK", function(applet, ...) applet:settingsShow(meta.state) end))
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

	meta.state.player:setLastSqueezeCenter(server)
	
	-- Init player
	if settings.playerInit then
	--always try to go back to last SC - good/bad?
--		if settings.squeezeNetwork then
--		meta.state.player:updateInit(nil, settings.playerInit)
--		else
--		meta.state.player:updateInit(server, settings.playerInit)
--		end

		meta.state.player:updateInit(server, settings.playerInit)
	end

	-- Subscribe to changes in player status
	jnt:subscribe(meta)
end


function _updateSettings(meta, player, force)
	local settings = meta:getSettings()

	local server = player and player:getSlimServer() or false
	local serverName = server and server:getName() or false

	if not player:isConnected() then
		return
	end

	local ipChanged = false

	local settingsIp
	if meta:getSettings().serverInit then
		settingsIp = meta:getSettings().serverInit.ip
	end
	if player and player:getSlimServer() and player:getSlimServer().ip ~= settingsIp then
		--actual server ip might have changed from what Playback's settings has (re-dhcp, moving locations, etc)
		log:debug("Updating Playback server on new ip address: ", player:getSlimServer().ip)
		ipChanged = true
	end

	if not ipChanged and not force and
	   settings.serverName == serverName then
		-- no change
		return
	end

	if ipChanged or (server and
		( settings.squeezeNetwork ~= server:isSqueezeNetwork()
		  or settings.serverName ~= server:getName() )) then
		settings.squeezeNetwork = server:isSqueezeNetwork()

		-- remember server if it's not SN
		if not settings.squeezeNetwork then
			settings.serverName = server:getName()
			settings.serverInit = server:getInit()
		end

		saveSettings = true
	end
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

