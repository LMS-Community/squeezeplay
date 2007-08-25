
--[[
=head1 NAME

applets.SetupSoundEffects.SetupSoundEffectsMeta - SetupSoundEffects meta-info

=head1 DESCRIPTION

See L<applets.SetupSoundEffects.SetupSoundEffectsApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]

local pairs = pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local Framework     = require("jive.ui.Framework")
local Audio           = require("jive.ui.Audio")

local appletManager = appletManager
local jiveMain      = jiveMain

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 0.1, 0.1
end


function defaultSettings(meta)
	return {}
end

function registerApplet(meta)
	
	local settings = meta:getSettings()
	for k,v in pairs(settings) do
		if k == "_EFFECTS" then
			Audio:effectsEnable(v)
		else
			Framework:enableSound(k, v)
		end
	end

	-- add a menu to load us
	local remoteSettings = jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS"))

	remoteSettings:addItem(meta:menuItem("SOUND_EFFECTS", function(applet, ...) applet:settingsShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

