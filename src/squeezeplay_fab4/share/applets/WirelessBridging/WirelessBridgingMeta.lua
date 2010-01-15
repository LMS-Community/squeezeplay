
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)

--[[

Disable unfinished applet - known issues (see also bug 11150):

a) Dynamically added routes for clients are lost when Fab4 is power-cycled
b) If a client is removed, the route isn't removed automatically
c) A client cannot use a static IP address as the route is then missing
d) Network setup changes, i.e. using wired instead of wireless does not disable bridging
e) UDP packets are not bridged / forwarded

	jiveMain:addItem(meta:menuItem('appletWirelessBridging', 'networkSettings', "Wireless Bridging", function(applet, ...) applet:settingsShow(...) end))

--]]

end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

