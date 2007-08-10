
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


function jiveVersion(meta)
	return 0.1, 0.1
end


function defaultSettings(meta)
	return {
		poll = { ["255.255.255.255"] = "255.255.255.255" }
	}
end


function registerApplet(meta)

	-- set the poll list for discovery of slimservers based on our settings
	appletManager:loadApplet("SlimDiscovery")
	SlimServers = appletManager:getApplet("SlimDiscovery"):getSlimServers()
	SlimServers:pollList(meta:getSettings().poll)
	
	local remoteSettings = jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS"))
	local advancedSettings = remoteSettings:subMenu(meta:string("ADVANCED_SETTINGS"))

	advancedSettings:addItem(appletManager:menuItem(meta:string("SLIMSERVER_SERVERS"), "SetupSlimServers", "menu"))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

