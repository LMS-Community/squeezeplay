
--[[
=head1 NAME

applets.SlimDiscovery.SlimDiscoveryMeta - SlimDiscovery meta-info

=head1 DESCRIPTION

See L<applets.SlimDiscovery.SlimDiscoveryApplet>.

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
	return 0.1, 0.1
end


function defaultSettings(self)
	return {
		currentPlayer = false
	}
end


function registerApplet(self)
	
	-- SlimDiscovery is a resident Applet
	appletManager:loadApplet("SlimDiscovery")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

