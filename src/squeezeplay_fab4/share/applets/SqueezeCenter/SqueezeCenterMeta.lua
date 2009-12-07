
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSqueezeCenter', 'advancedSettings', "Squeezebox Server", function(applet, ...) applet:settingsShow(...) end))
	meta:registerService("udevEventHandler")
	meta:registerService("squeezecenterStartupCheck")
	meta:registerService("isBuiltInSCRunning")
end

function configureApplet(meta)

	appletManager:callService("squeezecenterStartupCheck")

	-- listen for attached drives after boot
	appletManager:callService("addUeventListener", "", 
		function(evt, msg)
			appletManager:callService("udevEventHandler", evt, msg)
		end
	)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

