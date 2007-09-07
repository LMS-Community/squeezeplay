
--[[
=head1 NAME

applets.SetupWallpaper.SetupWallpaperMeta - SetupWallpaper meta-info

=head1 DESCRIPTION

See L<applets.SetupWallpaper.SetupWallpaperApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


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
		wallpaper = "Chapple_1.jpg",
	}
end


function registerApplet(meta)
	-- load default wallpaper
	local obj = appletManager:loadApplet("SetupWallpaper")
	obj:_setBackground(nil) -- nil is default from settings
	appletManager:freeApplet("SetupWallpaper")

	-- add a menu item for configuration
	local remoteSettings = jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS"))
	remoteSettings:addItem(meta:menuItem('WALLPAPER', function(applet, ...) applet:settingsShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

