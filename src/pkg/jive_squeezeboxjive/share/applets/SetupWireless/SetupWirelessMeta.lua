
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	-- Wireless uses its own log category
	-- defined here so that it can be changed using LogSettingsApplet before the applet is run.		
	jul.addCategory("applet.wireless", jul.DEBUG)
	
	-- add a menu to load us
	local remoteSettings = jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS"))
	local advancedSettings = remoteSettings:subMenu(meta:string("ADVANCED_SETTINGS"), 1000)

	remoteSettings:addItem(meta:menuItem("NETWORK", function(applet, ...) applet:settingsNetworksShow(...) end))
	advancedSettings:addItem(meta:menuItem("NETWORK_REGION", function(applet, ...) applet:settingsRegionShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

