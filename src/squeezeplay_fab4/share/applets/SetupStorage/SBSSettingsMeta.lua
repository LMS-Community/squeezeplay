
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Framework     = require("jive.ui.Framework")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		[ "sharingAccount" ] = "Squeezebox",
		[ "sharingPassword" ] = "1234",
	}
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('sbs_settings', 'advancedSettings', "USB_SD_STORAGE", function(applet, ...) applet:SBSSettingsMenu() end))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

