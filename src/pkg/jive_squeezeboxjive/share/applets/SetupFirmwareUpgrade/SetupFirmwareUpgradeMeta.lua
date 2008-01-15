
local tonumber = tonumber

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
	-- Wifi uses its own log category
	-- defined here so that it can be changed using LogSettingsApplet before the applet is run.		
	jul.addCategory("applet.wifi", jul.DEBUG)
	
	jiveMain:addItem(meta:menuItem('appletSetupFirmwareUpgrade', 'advancedSettings', "UPDATE", function(applet) applet:settingsShow() end))

	-- check for firmware upgrades when we connect to a new player
	-- we don't want the firmware upgrade applets always loaded so
	-- do this in a closure
	local firmwareUpgradeSink =
		function(chunk, err)
			log:warn("FIRMWARE SINK")
			if err then
				log:warn(err)
				return
			end

			-- store firmware upgrade url
			if chunk.data.firmwareUrl then
				upgradeUrl[1] = chunk.data.firmwareUrl
			end

			-- are we forcing an upgrade
			if tonumber(chunk.data.firmwareUpgrade) == 1 then
				log:warn("New Firmware Available")
				local applet = appletManager:loadApplet("SetupFirmwareUpgrade")
				applet:forceUpgrade(upgradeUrl[1])
				--FIXME, the unsubscriptions do not work
				if player then
					log:warn("Unsubscribing from /slim/firmwarestatus/", player.id)
					player.slimServer.comet:unsubscribe('/slim/firmwarestatus/' .. player.id)
				end
				if self and self.player then
					log:warn("Unsubscribing from /slim/firmwarestatus/", self.player.id)
					self.player.slimServer.comet:unsubscribe('/slim/firmwarestatus/' .. self.player.id)
				end
			else
				log:warn("no new firmware needed")
			end

		end

	local monitor = {
		notify_playerCurrent =
			function(self, player)
				log:warn("PLAYER CURRENT!!")
				--FIXME, the unsubscription does not work
				if self.player and player and self.player ~= player then
					log:warn("Unsubscribing from /slim/firmwarestatus/", self.player.id)
					self.player.slimServer.comet:unsubscribe('/slim/firmwarestatus/' .. self.player.id)
				end

				if player then				
					local fwcmd = { 'firmwareupgrade', 'firmwareVersion:' .. JIVE_VERSION, 'subscribe:3600' }
		                        player.slimServer.comet:subscribe(
						'/slim/firmwarestatus/' .. player.id,
						firmwareUpgradeSink,
						player.id,
						fwcmd
					)
				end
			end,
		notify_playerDisconnect =
			function(self,player)
				if player then
					player.slimServer.comet:unsubscribe('/slim/firmwarestatus/' .. player.id)
				end
			end
	}

	jnt:subscribe(monitor)

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

