
--[[
=head1 NAME

applets.QVGAlandscapeSkin.QVGAlandscapeSkinMeta - QVGAlandscapeSkin meta-info

=head1 DESCRIPTION

See L<applets.QVGAlandscapeSkin.QVGAlandscapeSkinApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local debug         = require('jive.utils.debug')


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {}
end

function registerApplet(self)
	jiveMain:registerSkin(self:string("QVGALANDSCAPE_SKIN"), "QVGAlandscapeSkin", "skin")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

