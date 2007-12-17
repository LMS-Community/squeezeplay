
--[[
=head1 NAME

applets.SlimServers.SlimServersMeta - SlimServers meta-info

=head1 DESCRIPTION

See L<applets.SlimServers.SlimServersApplet>.

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


function defaultSettings(self)
	return {
		poll = { ["255.255.255.255"] = "255.255.255.255" }
	}
end


function registerApplet(self)

	-- set the poll list for discovery of slimservers based on our settings
	local sdApplet = appletManager:loadApplet("SlimDiscovery")
	
	if sdApplet then
		sdApplet:pollList(self:getSettings().poll)
		jiveMain:addItem(self:menuItem('appletSlimservers', 'settings', "SLIMSERVER_SERVERS", function(applet, ...) applet:settingsShow(...) end, 72))
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

