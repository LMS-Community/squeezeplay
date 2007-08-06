
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
	return 0.1, 0.1
end


function defaultSettings(self)
	return {
		poll = { ["255.255.255.255"] = "255.255.255.255" }
	}
end


function registerApplet(self)

	-- set the poll list for discovery of slimservers based on our settings
	appletManager:loadApplet("SlimDiscovery")
	SlimServers = appletManager:getApplet("SlimDiscovery"):getSlimServers()
	SlimServers:pollList(self:getSettings().poll)
	
	local remoteSettings = jiveMain:subMenu("Settings"):subMenu("Remote Settings")
	local advancedSettings = remoteSettings:subMenu("Advanced Settings")

	advancedSettings:addItem(appletManager:menuItem(self:string("SERVERS"), "SetupSlimServers", "menu"))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

