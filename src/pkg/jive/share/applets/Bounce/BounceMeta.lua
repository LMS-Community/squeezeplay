
--[[
=head1 NAME

applets.Bounce.BounceMeta - Bounce meta-info

=head1 DESCRIPTION

See L<applets.Bounce.BounceApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 0.1, 0.1
end


function registerApplet(self)

	-- Bounce implements a screensaver
	local ssMgr = appletManager:load("ScreenSavers")
	if ssMgr ~= nil then
		-- Bounce uses its own log category
		-- defined here so that it can be changed using LogSettingsApplet before the applet is run.
		jul.addCategory("screensaver.bounce", jul.DEBUG)

		ssMgr:addScreenSaver(self:string('SCREENSAVER_BOUNCE'), "Bounce", "bounce")

		-- load our skin
		jiveMain:loadSkin("Bounce", "skin")

	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

