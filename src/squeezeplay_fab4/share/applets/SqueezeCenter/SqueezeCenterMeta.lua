
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
	meta:registerService("mmSqueezeCenterMenu")
	meta:registerService("squeezecenterStartupCheck")
	meta:registerService("isBuiltInSCRunning")
	meta:registerService("stopSqueezeCenter")
	meta:registerService("startSqueezeCenter")
	meta:registerService("mmStopSqueezeCenter")
	jiveMain:addItem(meta:menuItem('appletSqueezeCenter', 'advancedSettings', "Squeezebox Server", function(applet, ...) applet:settingsShow(...) end))

end

function configureApplet(meta)

	appletManager:callService("mmRegisterMenuItem", 
		{
		serviceMethod = "mmSqueezeCenterMenu",
		menuText      = meta:string('SQUEEZEBOX_SERVER'),
		onlyIfTrue    = "isBuiltInSCRunning",
		onlyIfFalse   = "isReadOnlyMedia",
		weight        = 20,
		}
	)
	appletManager:callService("mmRegisterMenuItem", 
		{
		serviceMethod = "startSqueezeCenter",
		menuText      = meta:string('START'),
		onlyIfFalse   = "isBuiltInSCRunning",
		weight        = 20,
		}
	)
	appletManager:callService("mmRegisterOnEjectHandler", 
		{
		serviceMethod =	"mmStopSqueezeCenter",
		ejectWarningText = meta:string('SQUEEZEBOX_SERVER_DISK_EJECT_WARNING'),
		ejectWarningTextOnlyIfTrue = "isBuiltInSCRunning",
		}
	)
	appletManager:callService("squeezecenterStartupCheck")

end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

