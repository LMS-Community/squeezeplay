
--[[
=head1 NAME

=head1 DESCRIPTION

=head1 FUNCTIONS

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


function registerApplet(meta)
	meta.menu = meta:menuItem('testScreenFlicker', 'advancedSettings', 'Test Screen Flicker', function(applet, ...) applet:openWindow(...) end, _)
	jiveMain:addItem(meta.menu)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

