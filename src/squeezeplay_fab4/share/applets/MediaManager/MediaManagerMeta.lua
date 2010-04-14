
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		mountedDevices = {},
	}
end


function registerApplet(meta)
--[[ disabled in subversion until ready to go live
	meta:registerService("mmRegisterMenuItem")
	meta:registerService("mmStartupCheck")
	meta:registerService("udevEventHandler")
	meta:registerService("mmConfirmEject")
	meta:registerService("mmGetMountedDevices")
--]]
end

function configureApplet(meta)

--[[ disabled in subversion until ready to go live
        -- add an eject item to the submenu
        appletManager:callService("mmRegisterMenuItem", 
                {
                        serviceMethod     = "mmConfirmEject",
                        menuToken         = "EJECT_DRIVE",
                        devNameAsTokenArg = true,
                }
        )

        appletManager:callService("mmStartupCheck")

	-- listen for attached drives after boot
	appletManager:callService("addUeventListener", "", 
		function(evt, msg)
			appletManager:callService("udevEventHandler", evt, msg)
		end
	)
--]]

end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

