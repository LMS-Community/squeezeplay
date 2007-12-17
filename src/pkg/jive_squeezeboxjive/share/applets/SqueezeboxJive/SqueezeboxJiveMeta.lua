
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return { 
		brightness = 32,
		dimmedTimeout = 10000,
		sleepTimeout = 60000,
		hibernateTimeout = 300000,
		dimmedAC = false
	}
end


function registerApplet(meta)
	jul.addCategory("squeezeboxJive", jul.DEBUG)

	-- SqueezeboxJive is a resident Applet
	appletManager:loadApplet("SqueezeboxJive")

	jiveMain:addItem(meta:menuItem('backlightSetting', 'settings', "BSP_BACKLIGHT_TIMER", function(applet, ...) applet:settingsBacklightTimerShow(...) end, 60))
	jiveMain:addItem(meta:menuItem('brightnessSetting', 'settings', "BSP_BRIGHTNESS", function(applet, ...) applet:settingsBrightnessShow(...) end, 65))
	jiveMain:addItem(meta:menuItem('powerDown', 'settings', "POWER_DOWN", function(applet, ...) applet:settingsPowerDown(...) end, 150))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

