
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
	local params = {
		THUMB_SIZE = 125,
		nowPlayingBrowseArtworkSize = 350,
		nowPlayingSSArtworkSize = 350,
	}
	jiveMain:registerSkin(self:string("DESKTOP_SKIN"), 'FullscreenSkin', 'skin', params)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

