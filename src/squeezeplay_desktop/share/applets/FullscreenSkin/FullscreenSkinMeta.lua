
--[[
=head1 NAME

applets.FullscreenSkin.FullscreenSkinMeta - FullscreenSkin meta-info

=head1 DESCRIPTION

See L<applets.FullscreenSkin.FullscreenSkinApplet>.

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
	return 1, 1
end


function registerApplet(self)
	-- This skin is basically broken right now. Disabling...
	--jiveMain:registerSkin(self:string("DESKTOP_SKIN"), 'FullscreenSkin', 'skin')
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

