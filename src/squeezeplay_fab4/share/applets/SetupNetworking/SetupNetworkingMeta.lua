
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


function defaultSettings(meta)
	return {
		[ "region" ] = false
	}
end

function registerApplet(meta)
	-- Wireless uses its own log category
	-- defined here so that it can be changed using LogSettingsApplet before the applet is run.		
	jul.addCategory("applet.networking", jul.DEBUG)
	
	meta:registerService("setupNetworking")

	jiveMain:addItem(meta:menuItem('networkSettings', 'advancedSettings', "NETWORK_SETUP_NETWORKING", function(applet, ...) applet:settingsNetworking(...) end))

	jiveMain:addItem(meta:menuItem('networkStatus0', 'advancedSettings', "NETWORK_STATUS_ETH0", function(applet, ...) applet:settingsNetworkStatus(true) end))
	jiveMain:addItem(meta:menuItem('networkStatus1', 'advancedSettings', "NETWORK_STATUS_WLAN0", function(applet, ...) applet:settingsNetworkStatus(false) end))

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

