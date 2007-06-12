
--[[
=head1 NAME

applets.DefaultSkin.DefaultSkinMeta - DefaultSkin meta-info

=head1 DESCRIPTION

See L<applets.DefaultSkin.DefaultSkinApplet>.

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


function jiveVersion(self)
	return 0.1, 0.1
end


function registerApplet(self)

	-- splash screen
	appletManager:openWindow("DefaultSkin", "splash")

	-- load ourselves indirectly through jiveMain
	jiveMain:loadSkin("DefaultSkin", "skin")

	-- add a menu item for configuration
	jiveMain:subMenu("Settings"):subMenu("Skin"):addItem(
		appletManager:menuItem("Wallpaper", "DefaultSkin", "wallpaperSetting")
	)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

