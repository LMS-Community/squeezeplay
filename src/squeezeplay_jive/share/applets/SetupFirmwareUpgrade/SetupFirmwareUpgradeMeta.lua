
local error, tonumber = error, tonumber

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")
local log           = require("jive.utils.log").logger("applets.setup")
local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

local JIVE_VERSION  = jive.JIVE_VERSION

-- naughty polluting global table, but I don't want to store this
-- in the applet settings as this value does not need to be persisted
upgradeUrl          = { false }
local upgradeUrl    = upgradeUrl

module(...)
oo.class(_M, AppletMeta)

function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSetupFirmwareUpgrade', 'advancedSettings', "UPDATE", function(applet) applet:settingsShow() end))

	-- check for firmware upgrades when we connect to a new player
	-- we don't want the firmware upgrade applets always loaded so
	-- do this in the meta class
	jnt:subscribe(meta)
end


function notify_playerDelete(meta, player)
	if meta.player ~= player then
		return
	end

	meta.player:unsubscribe('/slim/firmwarestatus/' .. meta.player:getId())
	meta.player = false
end


function notify_playerCurrent(meta, player)
	-- FIXME
	-- if the player remains the same we need to resubscribe. This should
	-- not be needed when the player subscription bug 8587 is fixed.

	if meta.player then
		meta.player:unsubscribe('/slim/firmwarestatus/' .. meta.player:getId())
	end

	meta.player = player

	if not player then
		return
	end
	
	local firmwareUpgradeSink =
		function(chunk, err)
			if err then
				log:warn(err)
				return
			end
			
			if not meta.player or not meta.player:getSlimServer() then
				log:warn("Firmware upgrade response but not connected to server")
				return
			end

			-- store firmware upgrade url
			-- Bug 6828, use a relative URL from SC to handle dual-homed servers
			if chunk.data.relativeFirmwareUrl then
				local ip, port = meta.player:getSlimServer():getIpPort()
				upgradeUrl[1] = 'http://' .. ip .. ':' .. port .. chunk.data.relativeFirmwareUrl
				log:info("Relative Firmware URL=", upgradeUrl[1])
			elseif chunk.data.firmwareUrl then
				upgradeUrl[1] = chunk.data.firmwareUrl
				log:info("Firmware URL=", upgradeUrl[1])
			end

			-- are we offering or forcing an upgrade
			if tonumber(chunk.data.firmwareUpgrade) == 1 then
				log:info("Firmware upgrade")
				local applet = appletManager:loadApplet("SetupFirmwareUpgrade")
				applet:forceUpgrade(tonumber(chunk.data.firmwareOptional) == 1, upgradeUrl[1], chunk.data.firmwareHelp)

				meta.player:unsubscribe('/slim/firmwarestatus/' .. meta.player:getId())
			end

		end

	local fwcmd = { 'firmwareupgrade', 'firmwareVersion:' .. JIVE_VERSION, 'subscribe:0' }
	player:subscribe(
			 '/slim/firmwarestatus/' .. player:getId(),
			 firmwareUpgradeSink,
			 player:getId(),
			 fwcmd
		 )
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

