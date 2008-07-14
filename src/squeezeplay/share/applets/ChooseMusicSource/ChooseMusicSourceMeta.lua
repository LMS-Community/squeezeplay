
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
	return 1, 1
end


function defaultSettings(meta)
	return {
		poll = { ["255.255.255.255"] = "255.255.255.255" }
	}
end


function registerApplet(meta)
	-- we depend on the SlimDiscovery applet
	appletManager:loadApplet("SlimDiscovery")

	meta:registerService("selectMusicSource")

	-- set the poll list for discovery of slimservers based on our settings
	if appletManager:hasService("setPollList") then
		appletManager:callService("setPollList", meta:getSettings().poll)
		jiveMain:addItem(meta:menuItem('appletSlimservers', 'settings', "SLIMSERVER_SERVERS", function(applet, ...) applet:settingsShow(...) end, 60))
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

