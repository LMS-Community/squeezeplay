
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
	return 1, 1
end


function registerApplet(self)

	-- Bounce implements a screensaver
	local ssMgr = appletManager:loadApplet("ScreenSavers")
	if ssMgr ~= nil then
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

