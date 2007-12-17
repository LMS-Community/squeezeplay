
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
	return 1, 1
end


function defaultSettings(meta)
	return {
		_VOLUME = Audio.MAXVOLUME / 2
	}
end

function registerApplet(meta)
	
	local settings = meta:getSettings()
	for k,v in pairs(settings) do
		if k == "_VOLUME" then
			Audio:setEffectVolume(v)
		else
			Framework:enableSound(k, v)
		end
	end

	-- add a menu to load us
	jiveMain:addItem(meta:menuItem('appletSetupSoundEffects', 'advancedSettings', "SOUND_EFFECTS", function(applet, ...) applet:settingsShow(...) end, 80))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

