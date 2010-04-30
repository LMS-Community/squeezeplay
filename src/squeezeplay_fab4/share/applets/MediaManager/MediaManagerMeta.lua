local oo            = require("loop.simple")

local System        = require("jive.System")
local AppletMeta    = require("jive.AppletMeta")
local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(self)
	return {
		mountedDevices = {},
	}
end


function registerApplet(meta)
	meta:registerService("mmRegisterMenuItem")
	meta:registerService("mmRegisterOnEjectHandler")
	meta:registerService("mmRegisterOnMountHandler")
	meta:registerService("mmStartupCheck")
	meta:registerService("udevEventHandler")
	meta:registerService("mmConfirmEject")
	meta:registerService("mmGetMountedDevices")
	meta:registerService("isReadOnlyMedia")
	meta:registerService("isWriteableMedia")
end

function configureApplet(meta)
	meta:registerService("mmRegisterMenuItem")

        -- add an eject item to the submenu
        appletManager:callService("mmRegisterMenuItem", 
                {
                        serviceMethod     = "mmConfirmEject",
                        menuToken         = "EJECT_DRIVE",
                        devNameAsTokenArg = true,
			weight            = 1000, -- default is 50, so this will put it at/near the bottom
                }
        )

        appletManager:callService("mmStartupCheck")

	-- listen for attached drives after boot
	appletManager:callService("addUeventListener", "", 
		function(evt, msg)
			appletManager:callService("udevEventHandler", evt, msg)
		end
	)

end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

