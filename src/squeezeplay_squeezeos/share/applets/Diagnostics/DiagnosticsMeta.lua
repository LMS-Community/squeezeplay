
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Framework     = require("jive.ui.Framework")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	meta:registerService("diagnosticsMenu")
	meta:registerService("supportMenu")
	meta:registerService("networkTroubleshootingMenu")

	Framework:addActionListener("help", nil, function()
		appletManager:callService("supportMenu")
		Framework:playSound("WINDOWSHOW")
	end, 1)

	jiveMain:addItem(meta:menuItem('diagnostics', 'advancedSettings', "DIAGNOSTICS", function(applet, ...) applet:diagnosticsMenu() end))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

