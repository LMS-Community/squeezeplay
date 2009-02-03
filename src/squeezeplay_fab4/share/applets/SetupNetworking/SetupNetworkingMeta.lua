
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
	
	meta:registerService("setupRegionShow")
	meta:registerService("setupConnectionType")
	meta:registerService("setupScanShow")
	meta:registerService("setupNetworksShow")

	jiveMain:addItem(meta:menuItem('networkSettings', 'advancedSettings', "NETWORK_SETUP_NETWORKING", function(applet, ...) applet:settingsConnectionType(...) end))
	jiveMain:addItem(meta:menuItem('networkRegion', 'advancedSettings', "NETWORK_REGION", function(applet, ...) applet:settingsRegionShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

