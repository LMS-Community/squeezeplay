
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
local Sample        = require("squeezeplay.sample")

local appletManager = appletManager
local jiveMain      = jiveMain

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		_VOLUME = Sample.MAXVOLUME / 3
	}
end

function registerApplet(meta)

	-- set volume
	local settings = meta:getSettings()
	Sample:setEffectVolume(settings["_VOLUME"])

	-- load sounds
	local obj = appletManager:loadApplet("SetupSoundEffects")

	-- The startup sound needs to be played with the minimum
	-- delay, load and play it first
	obj:_loadSounds("STARTUP")
	Framework:playSound("STARTUP")
	
	-- Load all other sounds
	obj:_loadSounds(nil) -- nil is default from settings
	appletManager:freeApplet("SetupSoundEffects")

	-- add a menu to load us
	jiveMain:addItem(meta:menuItem('appletSetupSoundEffects', 'advancedSettings', "SOUND_EFFECTS", function(applet, ...) applet:settingsShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

