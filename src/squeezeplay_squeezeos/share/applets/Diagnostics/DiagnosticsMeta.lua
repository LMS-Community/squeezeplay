
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

	Framework:addActionListener("help", nil, function()
		appletManager:callService("supportMenu")
	end)

	jiveMain:addItem(meta:menuItem('diagnostics', 'advancedSettings', "DIAGNOSTICS", function(applet, ...) applet:diagnosticsMenu() end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

