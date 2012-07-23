
--[[
=head1 NAME

applets.BlankScreen.BlankScreenMeta - BlankScreen meta-info

=head1 DESCRIPTION

See L<applets.BlankScreen.BlankScreenApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	local defaultSetting = {}
	return defaultSetting
end


function registerApplet(self)

end

function configureApplet(self)
	-- BlankScreen implements a screensaver
	appletManager:callService("addScreenSaver",
		self:string("SCREENSAVER_BLANKSCREEN"), 
		"BlankScreen", 
		"openScreensaver", _, _, 100, 
		"closeScreensaver"
	)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
