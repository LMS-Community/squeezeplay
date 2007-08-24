
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
local Timer         = require("jive.ui.Timer")

local appletManager = appletManager
local jiveMain      = jiveMain

local log             = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 0.1, 0.1
end


function defaultSettings(meta)
	return {}
end

function registerApplet(meta)
	
	Timer(1000, function()
			    local settings = meta:getSettings()
			    log:warn("FOO")
			    for k,v in pairs(Framework:getSounds()) do
				    log:warn("BAR")
				    if settings[k] ~= nil then
					    v:enable(settings[k])
				    end
			    end
		    end,
	      true):start()

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

