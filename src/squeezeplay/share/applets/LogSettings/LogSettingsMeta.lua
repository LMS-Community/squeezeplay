
--[[
=head1 NAME

applets.LogSettings.LogSettingsMeta - LogSettings meta-info

=head1 DESCRIPTION

See L<applets.LogSettings.LogSettingsApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local lfs           = require("lfs")


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	-- only make this available if an SD card is slotted in and a /mnt/mmc/log directory is present
	local SDCARD_PATH = "/mnt/mmc/log"
	if lfs.attributes(SDCARD_PATH, "mode") == "directory" then
		jiveMain:addItem(meta:menuItem('appletLogSettings', 'advancedSettings', 'DEBUG_LOG', function(applet, ...) applet:logSettings(...) end))
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

