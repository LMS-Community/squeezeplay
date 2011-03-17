
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

-- naughty polluting global table, but I don't want to store this
-- in the applet settings as this value does not need to be persisted


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSetupFirmwareUpgrade', 'advancedSettings', "UPDATE", function(applet) applet:showFirmwareUpgradeMenu() end, 115))

	meta:registerService("firmwareUpgrade")
	meta:registerService("showFirmwareUpgradeMenu")
	meta:registerService("wasFirmwareUpgraded")
	meta:registerService("mmFindFirmware")

	-- check for firmware upgrades when we connect to a new player
	-- we don't want the firmware upgrade applets always loaded so
	-- do this in the meta class
	jnt:subscribe(meta)
end


function configureApplet(meta)
	appletManager:callService("wasFirmwareUpgraded")
       -- software update should be a media manager menu item when applicable
        appletManager:callService("mmRegisterMenuItem",
                {
                        serviceMethod     = "showFirmwareUpgradeMenu",
                        menuText          = meta:string("UPDATE"),
			onlyIfTrue        = "mmFindFirmware",
                        weight            = 100, -- default is 50, so this will put it at/near the bottom
                }
        )
end


function notify_playerCurrent(meta, player)
	local server = player and player:getSlimServer()

	if not server then
		return
	end

	local url, force = server:getUpgradeUrl()

	if force then
		appletManager:callService("firmwareUpgrade", server)
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

