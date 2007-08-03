
--[[
=head1 NAME

applets.ScreenSavers.ScreenSaversMeta - ScreenSavers meta-info

=head1 DESCRIPTION

See L<applets.ScreenSavers.ScreenSaversApplet>.

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


function defaultSettings(self)
	return {
		whenStopped = "None",
		whenPlaying = "None",
		whenDocked = "None",
		timeout = 60000,
	}
end


function registerApplet(self)
	
	-- ScreenSaver is a resident Applet
	appletManager:loadApplet("ScreenSavers")
	
	-- Menu for configuration
	jiveMain:subMenu("Settings"):subMenu("Remote Settings"):addItem(
		appletManager:menuItem(self:string('SCREENSAVERS'), "ScreenSavers", "openSettings")
	)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

