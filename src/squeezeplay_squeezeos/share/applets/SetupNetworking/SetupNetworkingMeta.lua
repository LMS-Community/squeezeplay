
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
		[ "region" ] = false
	}
end

function registerApplet(meta)
	meta:registerService("setupScan")
	meta:registerService("setupNetworking")
	meta:registerService("settingsNetworking")

	jiveMain:addItem(meta:menuItem('chooseNetwork', 'networkSettings', "NETWORK_WIRELESS_NETWORKS", function(applet, ...) applet:settingsNetworking(...) end, 2))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

