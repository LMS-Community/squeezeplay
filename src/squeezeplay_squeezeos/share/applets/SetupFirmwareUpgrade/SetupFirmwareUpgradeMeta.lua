
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain

-- naughty polluting global table, but I don't want to store this
-- in the applet settings as this value does not need to be persisted


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
--	jiveMain:addItem(meta:menuItem('appletSetupFirmwareUpgrade', 'advancedSettings', "UPDATE", function(applet) applet:showFirmwareUpgradeMenu() end, 115))

	meta:registerService("firmwareUpgrade")
	meta:registerService("firmwareUpgradeWithUrl")
	meta:registerService("showFirmwareUpgradeMenu")
	meta:registerService("wasFirmwareUpgraded")
	meta:registerService("mmFindFirmware")
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


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

