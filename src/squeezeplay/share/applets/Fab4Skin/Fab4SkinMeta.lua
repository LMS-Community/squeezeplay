
--[[
=head1 NAME

applets.TouchSkin.TouchSkinMeta - TouchSkin meta-info

=head1 DESCRIPTION

See L<applets.TouchSkin.TouchSkinApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local log           = require('jive.utils.log').logger('applets.misc')


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(self)
	local params = {
		THUMB_SIZE = 43,
		nowPlayingBrowseArtworkSize = 190,
		nowPlayingSSArtworkSize     = 190,
		nowPlayingLargeArtworkSize  = 190,
        }
	jiveMain:registerSkin(self:string("TOUCH_SKIN"), "Fab4Skin", "skin", params)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

