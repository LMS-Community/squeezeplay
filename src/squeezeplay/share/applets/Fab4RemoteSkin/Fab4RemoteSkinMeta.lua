
--[[
=head1 NAME

applets.Fab4RemoteSkin.Fab4RemoteMeta - Remote Skin meta-info

=head1 DESCRIPTION

See L<applets.Fab4RemoteSkin.Fab4RemoteSkinApplet>.

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

function defaultSettings(self)
        self.params = {
		THUMB_SIZE = 64,
		nowPlayingBrowseArtworkSize = 190,
		nowPlayingSSArtworkSize     = 190,
		nowPlayingLargeArtworkSize  = 190,
        }
	return self.params
end

function registerApplet(self)
	jiveMain:registerSkin(self:string("SQUEEZEBOX_REMOTE_SKIN"), "Fab4RemoteSkin", "skin", self.params)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

