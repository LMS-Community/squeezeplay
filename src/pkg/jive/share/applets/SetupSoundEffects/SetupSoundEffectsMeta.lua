
--[[
=head1 NAME

applets.SetupSoundEffects.SetupSoundEffectsMeta - SetupSoundEffects meta-info

=head1 DESCRIPTION

See L<applets.SetupSoundEffects.SetupSoundEffectsApplet>.

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
	return 0.1, 0.1
end


function registerApplet(meta)
	
	-- add a menu to load us
	local remoteSettings = jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS"))

	remoteSettings:addItem(	appletManager:menuItem(meta:string("SOUND_EFFECTS"), "SetupSoundEffects", "open")
	)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

