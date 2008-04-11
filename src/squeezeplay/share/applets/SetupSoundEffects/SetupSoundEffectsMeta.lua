
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
		_VOLUME = Audio.MAXVOLUME / 3
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

	local sndpath = "applets/DefaultSkin/sounds/"

	-- The startup sound needs to be played with the minimum
	-- delay, load and play it first
	Framework:loadSound("STARTUP", "jive/splash.wav", 1)
	Framework:playSound("STARTUP")

	-- Load sounds
	Framework:loadSound("BUMP", sndpath .. "bump.wav", 1)
	Framework:loadSound("CLICK", sndpath .. "click.wav", 0)
	Framework:loadSound("JUMP", sndpath .. "jump.wav", 0)
	Framework:loadSound("WINDOWSHOW", sndpath .. "pushleft.wav", 1)
	Framework:loadSound("WINDOWHIDE", sndpath .. "pushright.wav", 1)
	Framework:loadSound("SELECT", sndpath .. "select.wav", 0)
	Framework:loadSound("PLAYBACK", sndpath .. "select.wav", 0)
	Framework:loadSound("DOCKING", sndpath .. "docking.wav", 1)
	Framework:loadSound("SHUTDOWN", sndpath .. "shutdown.wav", 1)

	-- add a menu to load us
	jiveMain:addItem(meta:menuItem('appletSetupSoundEffects', 'advancedSettings', "SOUND_EFFECTS", function(applet, ...) applet:settingsShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

