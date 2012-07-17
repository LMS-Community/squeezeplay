
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
	jiveMain:addItem(meta:menuItem('appletSetupFactoryReset', 'advancedSettings', "RESET_FACTORY_RESET", function(applet, ...) applet:factorySettingsShow(...) end, 125, { noCustom = 1 }, 'hm_settingsFactoryReset'))
	jiveMain:addItem(meta:menuItem('appletSetupRestoreDefaults', 'advancedSettings', "RESET_RESTORE_DEFAULTS", function(applet, ...) applet:restoreSettingsShow(...) end, 125, { noCustom = 1 }, 'hm_settingsRestoreDefaults'))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

